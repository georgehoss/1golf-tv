import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/image_index.dart';

/// `video_player`-based fallback used when the device SDK is below the
/// Bitmovin cutoff — critical for older Fire TV Sticks (Fire OS 5/6,
/// SDK 22/25). Ported from `one_baseball_android_tv`; same D-pad/media-key
/// handling as [BitmovinPlayer] so both players feel identical to the user.
class FallbackVideoPlayer extends StatefulWidget {
  const FallbackVideoPlayer({
    super.key,
    required this.url,
    required this.title,
    required this.isHLS,
    this.url2,
    this.externalController,
    this.onExternalRelease,
  });

  final String title;
  final String url;
  final bool isHLS;
  final String? url2;

  /// Shared, already-initialized controller to attach to (home inline→
  /// full-screen handoff) instead of creating one. When set, this widget does
  /// NOT initialize or dispose it — a single `VideoPlayerController` can back
  /// several `VideoPlayer` widgets at once.
  final VideoPlayerController? externalController;

  /// Called from [dispose] when [externalController] is set, so the owner can
  /// reclaim the controller (restore mute, hand playback back to the tile).
  final VoidCallback? onExternalRelease;

  @override
  State<FallbackVideoPlayer> createState() => _FallbackVideoPlayerState();
}

class _FallbackVideoPlayerState extends State<FallbackVideoPlayer> {
  late VideoPlayerController _controller;
  VideoPlayerController? _backupController;

  bool get _isExternal => widget.externalController != null;
  bool _initialized = false;
  bool _showControls = true;
  bool _forceShowControls = true;
  bool _isSeeking = false;
  bool _showSpinner = true; // spinner independiente de controles
  double _duration = 0;
  double _position = 0;
  int _seekStep = 5;

  Timer? _controlsHideTimer;
  DateTime _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _uiTickMs = 500; // refresco UI cada 500ms máximo
  final FocusNode _focusNode = FocusNode(debugLabel: 'fallback_player_focus');

  // ----- Scrubbing con flechas -----
  double? _scrubValue; // valor provisional mostrado en el slider
  Timer? _scrubTimer; // timer mientras se mantiene izq/der
  DateTime? _scrubStart; // inicio del hold
  int _scrubDir = 0; // -1 (izq) | 1 (der)

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initControllers();
    // Ensure media keys work even if focus is on platform view
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  bool _onGlobalKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _playPause();
        return true;
      } else if (key == LogicalKeyboardKey.mediaPlay) {
        _controller.play();
        return true;
      } else if (key == LogicalKeyboardKey.mediaPause) {
        _controller.pause();
        return true;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _focusNode.requestFocus();
        _startScrub(-1);
        return true;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _focusNode.requestFocus();
        _startScrub(1);
        return true;
      }
    } else if (event is KeyUpEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        _stopScrub(commit: true);
        _startAutoHide(seconds: 8);
        return true;
      }
    }
    return false;
  }

  void _startAutoHide({int seconds = 10}) {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          _forceShowControls = false;
          _showControls = false;
          _isSeeking = false;
          _seekStep = 5;
        });
      }
    });
  }

  void _cancelAutoHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  Future<void> _initControllers() async {
    // Handoff mode: attach to the shared, already-playing controller. Restore
    // full volume (the inline tile may have muted it) and take over the tick
    // listener for our controls; don't re-initialize or restart the stream.
    if (_isExternal) {
      _controller = widget.externalController!;
      _initialized = _controller.value.isInitialized;
      _duration = _controller.value.duration.inMilliseconds.toDouble() / 1000.0;
      await _controller.setVolume(1.0);
      _controller.addListener(_onTick);
      if (!_controller.value.isPlaying) _controller.play();
      setState(() => _showControls = false);
      _startAutoHide(seconds: 5);
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await _tryInitialize(_controller);

    if (!_initialized && widget.url2 != null && widget.url2!.isNotEmpty) {
      _backupController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url2!),
      );
      await _tryInitialize(_backupController!);
      if (_initialized) {
        _controller = _backupController!;
      }
    }

    if (!_initialized) {
      // no se pudo inicializar ninguna fuente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este video no está disponible')),
        );
        Navigator.of(context).maybePop();
      }
      return;
    }

    _controller.addListener(_onTick);
    _controller.play();
    // Ocultar controles a los 5s luego de iniciar reproducción por primera vez
    setState(() => _showControls = false);
    _startAutoHide(seconds: 5);
  }

  Future<void> _tryInitialize(VideoPlayerController c) async {
    try {
      await c.initialize();
      await c.setLooping(false);
      _initialized = c.value.isInitialized;
      if (_initialized) {
        _duration = c.value.duration.inMilliseconds.toDouble() / 1000.0;
      }
    } catch (_) {
      // ignora, intentaremos fallback
    }
  }

  void _onTick() {
    if (!mounted) return;
    final v = _controller.value;
    if (!v.isInitialized) return;

    // throttle UI updates
    final now = DateTime.now();
    if (now.difference(_lastUiTick).inMilliseconds < _uiTickMs) return;
    _lastUiTick = now;

    setState(() {
      _position = v.position.inMilliseconds.toDouble() / 1000.0;
      _duration = v.duration.inMilliseconds.toDouble() / 1000.0;
      // Spinner solo cuando está inicializando o bufferizando, no cuando está en pausa
      _showSpinner = !_initialized || v.isBuffering;
      if (_position > 0 && v.isInitialized && !v.isBuffering) {
        _showSpinner = false;
      }
    });
  }

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.shift);
  }

  double _scrubVelocityPerSecond(Duration held) {
    // If not currently holding (dir == 0) or held is zero, return base velocity
    if (_scrubDir == 0) return 5;
    if (held.inMilliseconds <= 0) return 5;
    if (_isShiftPressed()) return 60; // turbo con Shift
    final s = held.inMilliseconds / 1000.0;
    if (s < 1.0) return 10;
    if (s < 3.0) return 20;
    if (s < 6.0) return 60;
    if (s < 9.0) return 120;
    return 180;
  }

  void _scrubTick() {
    if (_scrubDir == 0 || _duration <= 0 || !_duration.isFinite) return;
    final now = DateTime.now();
    final start = _scrubStart ?? now;
    final held = now.difference(start);
    final velocity = _scrubVelocityPerSecond(held); // s/seg
    const dt = 0.12; // 120ms por tick
    final delta = velocity * dt * _scrubDir; // segundos a sumar
    final base = _scrubValue ?? _position;
    var next = base + delta;
    if (next < 0) next = 0;
    if (_duration > 0 && next > _duration) next = _duration;

    setState(() {
      _isSeeking = true;
      _scrubValue = next;
      _forceShowControls = true;
      _showControls = true;
    });
  }

  void _startScrub(int dir) {
    if (widget.isHLS || _duration <= 0 || !_duration.isFinite) return;
    _scrubDir = dir;
    if (_scrubTimer == null) {
      _scrubStart = DateTime.now();
      _scrubValue = _position;
    }
    _scrubTimer ??= Timer.periodic(const Duration(milliseconds: 120), (_) {
      _scrubTick();
    });
    _cancelAutoHide();
    setState(() {
      _isSeeking = true;
      _forceShowControls = true;
      _showControls = true;
    });
  }

  Future<void> _stopScrub({required bool commit}) async {
    _scrubTimer?.cancel();
    _scrubTimer = null;
    _scrubStart = null;
    _scrubDir = 0;

    if (commit && _scrubValue != null) {
      final v = _scrubValue!.clamp(0, _duration).toDouble();
      await _seek(v);
      if (mounted) {
        setState(() {
          _position = v.toDouble();
          _isSeeking = false;
          _scrubValue = null;
        });
      }
      _startAutoHide(seconds: 8);
    } else {
      if (mounted) {
        setState(() {
          _isSeeking = false;
          _scrubValue = null;
        });
      }
    }
    // reset ramp for next hold
    _scrubStart = null;
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _controller.removeListener(_onTick);
    if (_isExternal) {
      // Shared controller: don't dispose it — hand it back so the inline tile
      // keeps playing.
      widget.onExternalRelease?.call();
    } else {
      _controller.dispose();
      _backupController?.dispose();
    }
    WakelockPlus.disable();
    _focusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    super.dispose();
  }

  Future<void> _playPause() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
      setState(() => _showControls = true);
    } else {
      await _controller.play();
      setState(() => _showControls = false);
    }
  }

  Future<void> _seek(double seconds) async {
    if (!_controller.value.isInitialized) return;
    final target = Duration(milliseconds: (seconds * 1000).toInt());
    await _controller.seekTo(target);
  }

  Future<void> _seekForward() async {
    if (_scrubTimer != null) return; // evitar conflicto con scrubbing
    final current = _position;
    if (_duration > 0 && _duration != double.infinity) {
      await _seek(current + _seekStep);
    }
    if (_duration > 0 && _duration != double.infinity && mounted) {
      setState(() {
        _forceShowControls = true;
        _showControls = true;
        _isSeeking = true;
        _position = current + _seekStep;
        if (_position > _duration) _position = _duration;
      });
      final limit = _duration * 0.05;
      if (_seekStep < limit) _seekStep += 10;
    }
    _cancelAutoHide();
    _startAutoHide(seconds: 8);
  }

  Future<void> _seekBackward() async {
    if (_scrubTimer != null) return; // evitar conflicto con scrubbing
    final current = _position;
    if (_duration > 0 && _duration != double.infinity) {
      await _seek(current - _seekStep);
    }
    if (_duration > 0 && _duration != double.infinity && mounted) {
      setState(() {
        _forceShowControls = true;
        _showControls = true;
        _isSeeking = true;
        _position = current - _seekStep;
        if (_position < 0) _position = 0;
        final limit = _duration * 0.05;
        if (_seekStep < limit) _seekStep += 10;
      });
    }
    _cancelAutoHide();
    _startAutoHide(seconds: 8);
  }

  String _fmt(double secs) {
    final d = Duration(milliseconds: (secs * 1000).toInt());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const _PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPlay): const _PlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPause): const _PauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaStop): const _StopIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        _ActivateIntent: CallbackAction<_ActivateIntent>(
          onInvoke: (intent) {
            if (!_forceShowControls && mounted) {
              setState(() {
                _forceShowControls = true;
                _isSeeking = true;
              });
              _startAutoHide();
            } else {
              if (mounted) {
                setState(() {
                  _forceShowControls = false;
                  _seekStep = 5;
                });
                _startAutoHide();
              }
            }
            return null;
          },
        ),
        _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
          onInvoke: (intent) async => _playPause(),
        ),
        _PlayIntent: CallbackAction<_PlayIntent>(
          onInvoke: (intent) async {
            if (!_controller.value.isPlaying) await _controller.play();
            setState(() => _showControls = false);
            return null;
          },
        ),
        _PauseIntent: CallbackAction<_PauseIntent>(
          onInvoke: (intent) async {
            if (_controller.value.isPlaying) await _controller.pause();
            setState(() => _showControls = true);
            return null;
          },
        ),
        _StopIntent: CallbackAction<_StopIntent>(
          onInvoke: (intent) async {
            await _controller.pause();
            await _controller.seekTo(Duration.zero);
            setState(() {
              _position = 0;
              _showControls = true;
            });
            return null;
          },
        ),
        _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
          onInvoke: (intent) async {
            await _seekForward();
            return null;
          },
        ),
        _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
          onInvoke: (intent) async {
            await _seekBackward();
            return null;
          },
        ),
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowLeft) {
              _startScrub(-1);
            } else if (k == LogicalKeyboardKey.arrowRight) {
              _startScrub(1);
            }
            // Mantener visibles y reiniciar conteo mientras hay interacción
            _cancelAutoHide();
            _forceShowControls = true;
            _showControls = true;
            _isSeeking = true;
            setState(() {});
          } else if (event is KeyUpEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowLeft ||
                k == LogicalKeyboardKey.arrowRight) {
              _stopScrub(commit: true);
              // Iniciar ocultamiento luego de terminar el hold
              _startAutoHide(seconds: 8);
            }
          }
        },
        child: Stack(
          children: [
            // Vídeo a pantalla completa
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: _initialized
                    ? FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (_showControls || _forceShowControls) _buildControls(context),
            if (_showSpinner) _buildSpinner(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return const Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Positioned.fill(
      // Firestick overscan crops screen edges; inset the controls overlay so
      // the title/time/slider don't sit flush against the border. The video
      // itself stays full-bleed (no black frame).
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          children: [
            SafeArea(
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
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
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox()),
            if (_showControls && !_controller.value.isPlaying)
              Center(child: Image.asset(ImageIndex.logo, width: 50)),
            const Expanded(child: SizedBox()),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 30),
                if (widget.isHLS)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFBB03B)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'EN VIVO',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Text(
                      '${_fmt(_scrubValue ?? _position)} / ${_fmt(_duration)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                Expanded(
                  child: Slider(
                    inactiveColor: Colors.grey,
                    thumbColor: _isSeeking || _scrubValue != null
                        ? Colors.white
                        : const Color(0xFFFBB03B),
                    value: _duration > 0
                        ? (_scrubValue ?? _position).clamp(0, _duration)
                        : 0,
                    max: _duration > 0 ? _duration : 1,
                    onChangeStart: (_) {
                      _isSeeking = true;
                      _forceShowControls = true;
                      _scrubValue ??= _position;
                      setState(() {});
                      _cancelAutoHide();
                    },
                    onChanged: (v) {
                      _scrubValue = v;
                      setState(() {});
                    },
                    onChangeEnd: (_) async {
                      if (_scrubValue != null) {
                        final v = _scrubValue!.clamp(0, _duration).toDouble();
                        await _seek(v);
                        _scrubValue = null;
                      }
                      _isSeeking = false;
                      setState(() {});
                      _startAutoHide(seconds: 8);
                    },
                  ),
                ),
                // TV-safe trailing margin: the slider would otherwise touch
                // the right screen edge, at risk of overscan cropping.
                const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Intents (mismo patrón que en el Bitmovin player)
class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _PlayIntent extends Intent {
  const _PlayIntent();
}

class _PauseIntent extends Intent {
  const _PauseIntent();
}

class _StopIntent extends Intent {
  const _StopIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}
