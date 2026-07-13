import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/image_index.dart';
import 'bitmovin_config.dart';

/// Full-screen playback on Samsung Tizen.
///
/// Bitmovin ships no native Tizen SDK, so Tizen plays through the Bitmovin
/// **Web** SDK: `assets/index.html` hosts the player inside a WebView and this
/// widget drives it over a JS bridge (`applyConfig` / `hostCmd` down,
/// `PlayerBridge` messages up), drawing the same D-pad controls as the native
/// [BitmovinPlayer] on top of it. Ported from
/// `one_baseball_android_tv/lib/src/pages/player/tizen_bitmovin_player.dart`
/// with golf branding, and with Back popping the route instead of killing the
/// app (the base called `tizen.application.exit()`).
class TizenWebPlayer extends StatefulWidget {
  const TizenWebPlayer({
    super.key,
    required this.url,
    required this.isHLS,
    required this.title,
    this.url2,
  });

  final String title;
  final String url;
  final bool isHLS;
  final String? url2;

  @override
  State<TizenWebPlayer> createState() => _TizenWebPlayerState();
}

class _TizenWebPlayerState extends State<TizenWebPlayer> {
  late final WebViewController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'tizen_web_player_focus');

  bool _showControls = true;
  bool _isSeeking = true;
  bool _isPlaying = false;
  bool _isLive = false;
  bool _isLoading = true;
  double _currentTime = 0;
  double _duration = 0;

  Timer? _autoHideTimer;
  Timer? _seekingTimer;
  bool _firstAutoHideDone = false;

  double? _scrubValue;
  Timer? _scrubTimer;
  DateTime? _scrubStart;
  int _scrubDir = 0;

  /// Back can arrive twice — from Flutter's key handler and, if the WebView
  /// grabbed DOM focus, from the page's own `keydown`. Popping twice would take
  /// the Home down with the player.
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _isLive = widget.isHLS;
    WakelockPlus.enable();
    _controller = _buildController();
    _loadPlayerPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _seekingTimer?.cancel();
    _scrubTimer?.cancel();
    // Release the TV's video decoder before the WebView goes away.
    _hostCmd('destroy');
    WakelockPlus.disable();
    _focusNode.dispose();
    super.dispose();
  }

  WebViewController _buildController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (SMART-TV; Tizen) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/112.0.0.0 Safari/537.36',
      )
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('PlayerBridge', onMessageReceived: _onBridgeMessage)
      ..addJavaScriptChannel(
        'LogChannel',
        onMessageReceived: (message) => debugPrint('[player] ${message.message}'),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _applyConfig(),
          onWebResourceError: (error) =>
              debugPrint('[player] web error: ${error.description}'),
        ),
      );
  }

  /// The Tizen WebView cannot read Flutter assets directly, so the page is
  /// copied to a temp file and loaded from disk.
  Future<void> _loadPlayerPage() async {
    try {
      final html = await rootBundle.loadString('assets/index.html');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bitmovin_player.html');
      await file.writeAsString(html, flush: true);
      await _controller.loadFile(file.path);
    } catch (e) {
      debugPrint('[player] failed to load player page: $e');
    }
  }

  Future<void> _applyConfig() async {
    final config = {
      'licenseKey': bitmovinLicenseKey,
      'appId': bitmovinAppId,
      'title': widget.title,
      'description': '',
      'type': _sourceType(),
      'url': widget.url,
      if (widget.url2?.isNotEmpty ?? false) 'url2': widget.url2,
    };
    try {
      await _controller.runJavaScript('window.applyConfig(${jsonEncode(config)});');
    } catch (e) {
      debugPrint('[player] applyConfig failed: $e');
    }
  }

  /// Bitmovin Web needs the source kind up front. Live is always HLS; VOD is
  /// sniffed from the URL, matching `buildGolfSourceConfig`.
  String _sourceType() {
    if (widget.isHLS) return 'hls';
    final url = widget.url.toLowerCase();
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.mpd')) return 'dash';
    return 'progressive';
  }

  Future<void> _hostCmd(String cmd, [Map<String, dynamic>? args]) async {
    final payload = jsonEncode({'cmd': cmd, 'args': args ?? {}});
    try {
      await _controller.runJavaScript('window.hostCmd($payload);');
    } catch (e) {
      debugPrint('[player] hostCmd $cmd failed: $e');
    }
  }

  // ─── Bridge (JS → Flutter) ───────────────────────────────────────────────

  void _onBridgeMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'duration':
          _onDuration(data);
        case 'time':
          _onTime(data);
        case 'state':
          _onState(data);
        case 'event':
          _onEvent('${data['name']}');
      }
    } catch (e) {
      debugPrint('[player] bad bridge message: $e');
    }
  }

  void _onDuration(Map<String, dynamic> data) {
    final value = data['value'];
    setState(() {
      if (value is num && value.isFinite) _duration = value.toDouble();
      _isLive = data['isLive'] == true;
      _isLoading = false;
    });
  }

  void _onTime(Map<String, dynamic> data) {
    final time = data['time'];
    final duration = data['duration'];
    final playing = data['playing'] == true;

    setState(() {
      _duration = (duration is num && duration.isFinite)
          ? duration.toDouble()
          : _duration;
      // While scrubbing, the slider follows the user, not the stream.
      if (_scrubValue == null && time is num && time.isFinite) {
        final seconds = time.toDouble();
        _currentTime = _duration > 0 ? seconds.clamp(0.0, _duration) : seconds;
      }
      _isPlaying = playing;
      _isLive = data['isLive'] == true;
      _isLoading = false;
    });

    if (!_firstAutoHideDone && (_isPlaying || _currentTime > 0)) {
      _firstAutoHideDone = true;
      _isSeeking = false;
      _armAutoHide();
    }
  }

  void _onState(Map<String, dynamic> data) {
    final duration = data['duration'];
    setState(() {
      _isPlaying = data['playing'] == true;
      if (duration is num && duration.isFinite) _duration = duration.toDouble();
      if (data['isLive'] != null) _isLive = data['isLive'] == true;
    });
  }

  void _onEvent(String name) {
    switch (name) {
      case 'SourceLoaded':
        _hostCmd('getDuration');
      case 'Play':
      case 'Playing':
        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });
        if (!_firstAutoHideDone) {
          _firstAutoHideDone = true;
          _isSeeking = false;
          _armAutoHide();
        }
      case 'Paused':
        setState(() {
          _isPlaying = false;
          _showControls = true;
        });
        _cancelAutoHide();
      case 'Back':
        // Only reached if the WebView took key focus; Flutter's own Back
        // handler covers the normal path.
        _exit();
    }
  }

  void _exit() {
    if (_exiting) return;
    _exiting = true;
    Get.back();
  }

  // ─── Controls visibility ─────────────────────────────────────────────────

  void _cancelAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _armAutoHide([Duration delay = const Duration(seconds: 8)]) {
    _cancelAutoHide();
    _autoHideTimer = Timer(delay, () {
      if (!mounted || _isSeeking || _scrubValue != null) return;
      setState(() => _showControls = false);
    });
  }

  void _bumpControls([Duration delay = const Duration(seconds: 10)]) {
    setState(() => _showControls = true);
    _armAutoHide(delay);
  }

  void _beginSeekingFeedback() {
    _seekingTimer?.cancel();
    _cancelAutoHide();
    setState(() {
      _isSeeking = true;
      _showControls = true;
    });
    _seekingTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _isSeeking = false);
      if (_isPlaying && _scrubValue == null) _armAutoHide();
    });
  }

  // ─── Scrubbing (accelerates while the arrow is held) ─────────────────────

  bool get _canScrub => !_isLive && _duration > 0 && _duration.isFinite;

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.shift);
  }

  double _scrubVelocityPerSecond(Duration held) {
    if (_isShiftPressed()) return 60;
    final seconds = held.inMilliseconds / 1000.0;
    if (seconds < 1.0) return 5;
    if (seconds < 3.0) return 15;
    if (seconds < 6.0) return 60;
    if (seconds < 9.0) return 120;
    return 180;
  }

  void _scrubTick() {
    if (_scrubDir == 0 || !_canScrub) return;
    final held = DateTime.now().difference(_scrubStart ?? DateTime.now());
    const tickSeconds = 0.12;
    final delta = _scrubVelocityPerSecond(held) * tickSeconds * _scrubDir;
    final next = ((_scrubValue ?? _currentTime) + delta).clamp(0.0, _duration);
    setState(() {
      _isSeeking = true;
      _showControls = true;
      _scrubValue = next;
    });
  }

  void _startScrub(int dir) {
    if (!_canScrub) return;
    _scrubDir = dir;
    _scrubStart ??= DateTime.now();
    _scrubValue ??= _currentTime;
    _scrubTimer ??= Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _scrubTick(),
    );
    _beginSeekingFeedback();
  }

  void _stopScrub({required bool commit}) {
    _scrubTimer?.cancel();
    _scrubTimer = null;
    _scrubStart = null;
    _scrubDir = 0;

    final target = _scrubValue;
    if (commit && target != null) {
      final position = target.clamp(0.0, _duration);
      _hostCmd('seekAbs', {'time': position});
      setState(() {
        _currentTime = position;
        _scrubValue = null;
        _isSeeking = false;
      });
      if (_isPlaying) _armAutoHide();
    } else {
      setState(() {
        _scrubValue = null;
        _isSeeking = false;
      });
    }
  }

  // ─── D-pad ───────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        _stopScrub(commit: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      if (_scrubValue != null) return KeyEventResult.handled;
      if (_showControls) {
        _cancelAutoHide();
        setState(() {
          _showControls = false;
          _isSeeking = false;
        });
      } else {
        setState(() {
          _showControls = true;
          _isSeeking = true;
        });
        _armAutoHide(const Duration(seconds: 6));
      }
      return KeyEventResult.handled;
    }

    _bumpControls();

    if (key == LogicalKeyboardKey.arrowLeft) {
      _startScrub(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _startScrub(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (_scrubValue != null) {
        _stopScrub(commit: true);
      } else {
        _hostCmd('togglePlay', {'unmute': true});
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      _hostCmd('play', {'unmute': true});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _hostCmd('pause');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (_scrubValue != null) {
        _stopScrub(commit: false);
      } else {
        _exit();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKey,
            child: WebViewWidget(controller: _controller),
          ),
        ),
        if (_showControls) Positioned.fill(child: _controls()),
      ],
    );
  }

  Widget _controls() {
    final hasDuration = _duration > 0 && _duration.isFinite;
    final position = (_scrubValue ?? _currentTime).clamp(
      0.0,
      hasDuration ? _duration : 0.0,
    );

    return IgnorePointer(
      child: Padding(
        // Overscan-safe inset, same as the native player.
        padding: const EdgeInsets.all(5.0),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!_isPlaying) Image.asset(ImageIndex.logo, width: 50),
            const Spacer(),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.white)
            else if (_isLive)
              Align(alignment: Alignment.centerLeft, child: _liveTag())
            else
              _progressBar(position, hasDuration),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(double position, bool hasDuration) {
    return Row(
      children: [
        const SizedBox(width: 20),
        Text(
          '${_formatDuration(position)} / ${_formatDuration(_duration)}',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            inactiveColor: Colors.grey,
            thumbColor: (_isSeeking || _scrubValue != null)
                ? Colors.white
                : const Color(0xFFFBB03B),
            value: position,
            max: hasDuration ? _duration : 1,
            // Seeking is driven by the D-pad, and the overlay ignores pointers;
            // this only keeps the slider painted in its enabled colors (a null
            // `onChanged` would grey the active track out).
            onChanged: (_) {},
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _liveTag() => Container(
    padding: const EdgeInsets.all(4),
    margin: const EdgeInsets.only(left: 20, bottom: 10, top: 10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFFBB03B)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Text(
      'EN VIVO',
      style: TextStyle(
        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
    ),
  );

  String _formatDuration(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return '--:--';
    final duration = Duration(seconds: value.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
