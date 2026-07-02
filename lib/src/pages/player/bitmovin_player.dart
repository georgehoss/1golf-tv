import 'dart:async';

import 'package:bitmovin_player/bitmovin_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/image_index.dart';

/// Native Bitmovin playback for devices with Android SDK ≥ [AdaptivePlayer.cutoffSdk].
/// Ported from `one_baseball_android_tv` — key, analytics key and D-pad/media-key
/// handling (including accelerated scrubbing) preserved verbatim; only the DRM
/// `x-app-bundle`, font and accent color were adapted to golf branding.
class BitmovinPlayer extends StatefulWidget {
  const BitmovinPlayer({
    super.key,
    required this.url,
    required this.isHLS,
    this.url2,
    required this.title,
  });

  final String title;
  final String url;
  final bool isHLS;
  final String? url2;

  @override
  State<BitmovinPlayer> createState() => _BitmovinPlayerState();
}

class _BitmovinPlayerState extends State<BitmovinPlayer>
    with WidgetsBindingObserver {
  late Player _player;
  final _playerViewKey = GlobalKey<PlayerViewState>();
  int seekingOffsetSeconds = 10;
  final _logger = Logger();
  late final String _fallbackSource;
  bool isError = false;
  bool showControls = true;
  bool forceShowControls = true;
  double currentTime = 0;
  double duration = 0;
  bool isSeeking = true;
  bool _didScheduleFirstHide = false;
  Timer? _firstPlayHideTimer;
  Timer? _controlsHideTimer;
  // Scrubbing state
  double? _scrubValue; // provisional slider value when holding arrows
  Timer? _scrubTimer;
  DateTime? _scrubStart;
  int _scrubDir = 0; // -1 | 1
  final FocusNode _focusNode = FocusNode(debugLabel: 'bitmovin_player_focus');
  final drmConfig = const DrmConfig(
    fairplay: FairplayConfig(
      licenseRequestHeaders: {'x-app-bundle': 'tv.onegolf.tv'},
    ),
    widevine: WidevineConfig(httpHeaders: {'x-app-bundle': 'tv.onegolf.tv'}),
  );

  @override
  void initState() {
    _fallbackSource = widget.url2 ?? '';
    WakelockPlus.enable();
    super.initState();
    try {
      _initializePlayer();
    } on Exception catch (e) {
      debugPrint(e.toString());
    }

    WidgetsBinding.instance.addObserver(this);
    // Ensure media keys work even if the platform view has focus
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  void _startAutoHide({int seconds = 10}) {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          forceShowControls = false;
          showControls = false;
          isSeeking = false;
          seekingOffsetSeconds = 10;
        });
      }
    });
  }

  void _cancelAutoHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  bool _onGlobalKey(KeyEvent event) {
    // Handle both key down and key up so arrows still work when focus is lost
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _playPause();
        return true;
      } else if (key == LogicalKeyboardKey.mediaPlay) {
        _play();
        return true;
      } else if (key == LogicalKeyboardKey.mediaPause) {
        _pause();
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

  // Cargar la fuente secundaria (de respaldo) si falla la primaria
  void _loadFallbackSource() {
    if (_fallbackSource.isNotEmpty) {
      isError = false;
      _player.loadSourceConfig(
        SourceConfig(
          url: widget.url2!,
          type: SourceType.hls,
          title: widget.title,
          drmConfig: drmConfig,
        ),
      );
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _player.play();
        }
      });
    } else {
      if (isError) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          Get.snackbar(
            'Lo sentimos',
            'Este video no está disponible',
            colorText: Colors.white,
            backgroundColor: Colors.red,
          );
        });
        Get.back();
      }
    }
  }

  void _listen() {
    _player
      ..onError = (event) {
        _logger.e('Error: ${event.message}');
        isError = true;
        _loadFallbackSource(); // Intentar cargar la URL de respaldo si ocurre un error
      }
      ..onTimeChanged = (event) async {
        currentTime = event.time;
        if (duration <= 0) {
          duration = await _player.duration;
        }
        if (!isSeeking && mounted) {
          setState(() {
            forceShowControls = false;
            if (seekingOffsetSeconds > 30) {
              seekingOffsetSeconds = 10;
            }
          });
        }
        if (mounted) {
          setState(() {});
        }
      }
      ..onSourceError = (event) {
        _logger.e('Source error: ${event.toJson()}');
        if (event.code == 2201) {
          isError = true;
          _player.loadSourceConfig(
            SourceConfig(
              url: widget.url,
              type: SourceType.hls,
              title: widget.title,
              drmConfig: drmConfig,
            ),
          );
          Future.delayed(const Duration(milliseconds: 1000), () {
            _player.play();
          }); // Intentar cargar la URL de respaldo si ocurre un error
        } else {
          isError = true;
        }
      }
      ..onSourceUnloaded = (event) {
        _logger.i('Source unloaded: ${event.toJson()}');
        _loadFallbackSource(); // Intentar cargar la URL de respaldo si se descarga la fuente
      }
      ..onPaused = (event) async {
        _logger.i('Paused: ${event.toJson()}');
        if (mounted) {
          currentTime = await _player.currentTime;
          duration = await _player.duration;

          setState(() {
            showControls = true;
          });
        }
      }
      ..onSeek = (event) async {
        isSeeking = true;
        forceShowControls = true;
        if (mounted) {
          setState(() {});
        }
      }
      ..onSeeked = (event) async {
        if (isSeeking) {
          Future.delayed(const Duration(seconds: 5), () {
            isSeeking = false;
            if (mounted) {
              setState(() {});
            }
          });
        }
      }
      ..onPlay = (event) {
        _logger.i('Playing: ${event.toJson()}');
        if (mounted) {
          setState(() {
            showControls = false;
          });
        }
        // Auto-ocultar controles a los 5s tras la PRIMERA reproducción
        if (!_didScheduleFirstHide) {
          _didScheduleFirstHide = true;
          _firstPlayHideTimer?.cancel();
          _firstPlayHideTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                forceShowControls = false;
                seekingOffsetSeconds = 10;
                isSeeking = false;
              });
            }
          });
        }
      };
  }

  void _initializePlayer() async {
    _player = Player(
      config: const PlayerConfig(
        key: '3a21fd77-dd98-4146-8751-8d1858bfa033',
        analyticsConfig: AnalyticsConfig(
          licenseKey: 'f2ae6442-705f-4531-ada7-b68e129a4eed',
        ),
        styleConfig: StyleConfig(isUiEnabled: false),
        remoteControlConfig: RemoteControlConfig(
          isCastEnabled: false,
          isAirPlayEnabled: false,
          sendManifestRequestsWithCredentials: true,
        ),
      ),
    );

    final sourceConfig = widget.isHLS
        ? SourceConfig(
            url: widget.url,
            type: SourceType.hls,
            title: widget.title,
            drmConfig: drmConfig,
          )
        : SourceConfig(
            url: widget.url,
            drmConfig: drmConfig,
            type: widget.url.contains('m3u8')
                ? SourceType.hls
                : SourceType.progressive,
            title: '',
          );
    _listen();
    _player.loadSourceConfig(sourceConfig);
    _player.play();
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        if (!(await _player.isPlaying)) {
          _player.play();
        }
      }
    });
  }

  @override
  void dispose() async {
    _firstPlayHideTimer?.cancel();
    _controlsHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _player.pause();
    _player.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();
    _focusNode.dispose();

    super.dispose();
  }

  void _playPause() async {
    if (await _player.isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _play() {
    _player.play();
  }

  void _pause() {
    _player.pause();
  }

  void _stop() {
    _player.pause();
    _player.seek(0);
  }

  // --- Scrubbing helpers ---
  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.shift);
  }

  double _scrubVelocityPerSecond(Duration held) {
    // If not currently holding (dir == 0) or held is zero, always return base velocity
    if (_scrubDir == 0) return 5;
    if (held.inMilliseconds <= 0) return 5;
    if (_isShiftPressed()) return 60; // turbo while holding shift
    final s = held.inMilliseconds / 1000.0;
    if (s < 1.0) return 10;
    if (s < 3.0) return 20;
    if (s < 6.0) return 60;
    if (s < 9.0) return 120;
    return 180;
  }

  Future<void> _scrubTick() async {
    if (_scrubDir == 0 || duration <= 0 || !duration.isFinite) return;
    final now = DateTime.now();
    final start = _scrubStart ?? now;
    final held = now.difference(start);
    final velocity = _scrubVelocityPerSecond(held);
    const dt = 0.12;
    final delta = velocity * dt * _scrubDir;
    final base = _scrubValue ?? currentTime;
    var next = base + delta;
    if (next < 0) next = 0;
    if (duration > 0 && next > duration) next = duration;
    setState(() {
      isSeeking = true;
      _scrubValue = next;
      forceShowControls = true;
      showControls = true;
    });
  }

  void _startScrub(int dir) {
    if (widget.isHLS || duration <= 0 || !duration.isFinite) return;
    _scrubDir = dir;
    if (_scrubTimer == null) {
      _scrubStart = DateTime.now();
      _scrubValue = currentTime;
    }
    _scrubTimer ??= Timer.periodic(const Duration(milliseconds: 120), (_) {
      _scrubTick();
    });
    _cancelAutoHide();
    setState(() {
      isSeeking = true;
      forceShowControls = true;
      showControls = true;
    });
  }

  Future<void> _stopScrub({required bool commit}) async {
    _scrubTimer?.cancel();
    _scrubTimer = null;
    _scrubStart = null;
    _scrubDir = 0;

    if (commit && _scrubValue != null) {
      final v = _scrubValue!.clamp(0, duration).toDouble();
      _player.seek(v);
      setState(() {
        currentTime = v;
        isSeeking = false;
        _scrubValue = null;
      });
      _startAutoHide(seconds: 8);
    } else {
      setState(() {
        isSeeking = false;
        _scrubValue = null;
      });
    }
  }

  void _seekForward() async {
    if (_scrubTimer != null) return; // avoid conflict while scrubbing
    final currentPosition = await _player.currentTime;
    if (duration > 0 && duration != double.infinity) {
      _player.seek(currentPosition + seekingOffsetSeconds);
    }
    if (duration <= 0) {
      duration = await _player.duration;
    }
    if (duration > 0 && duration != double.infinity && mounted) {
      setState(() {
        forceShowControls = true;
        showControls = true;
        isSeeking = true;
        currentTime = currentPosition + seekingOffsetSeconds;
        if (currentTime > duration) {
          currentTime = duration;
        }
      });
      final limit = duration * 0.05;
      if (seekingOffsetSeconds < limit) {
        seekingOffsetSeconds += 10;
      }
    }
    _cancelAutoHide();
    _startAutoHide(seconds: 8);
  }

  Container liveTag() {
    return Container(
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
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  void _seekBackward() async {
    if (_scrubTimer != null) return; // avoid conflict while scrubbing
    final currentPosition = await _player.currentTime;
    if (duration > 0 && duration != double.infinity) {
      _player.seek(currentPosition - seekingOffsetSeconds);
    }
    if (duration <= 0) {
      duration = await _player.duration;
    }
    if (duration > 0 && duration != double.infinity && mounted) {
      setState(() {
        forceShowControls = true;
        showControls = true;
        isSeeking = true;
        currentTime = currentPosition - seekingOffsetSeconds;
        if (currentTime < 0) {
          currentTime = 0;
        }
        final limit = duration * 0.05;
        if (seekingOffsetSeconds < limit) {
          seekingOffsetSeconds += 10;
        }
      });
    }
    _cancelAutoHide();
    _startAutoHide(seconds: 8);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPlayPause):
            const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPlay): const PlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPause): const PauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaStop): const StopIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            if (!forceShowControls && mounted) {
              setState(() {
                forceShowControls = true;
                isSeeking = true;
              });
              Timer(const Duration(seconds: 10), () {
                if (mounted) {
                  setState(() {
                    forceShowControls = false;
                    seekingOffsetSeconds = 10;
                    isSeeking = false;
                  });
                }
              });
            } else {
              if (mounted) {
                setState(() {
                  forceShowControls = false;
                  seekingOffsetSeconds = 10;
                });
              }
            }
            return null;
          },
        ),
        PlayPauseIntent: CallbackAction<PlayPauseIntent>(
          onInvoke: (intent) => _playPause(),
        ),
        PlayIntent: CallbackAction<PlayIntent>(onInvoke: (intent) => _play()),
        PauseIntent: CallbackAction<PauseIntent>(
          onInvoke: (intent) => _pause(),
        ),
        StopIntent: CallbackAction<StopIntent>(onInvoke: (intent) => _stop()),
        SeekForwardIntent: CallbackAction<SeekForwardIntent>(
          onInvoke: (intent) => _seekForward(),
        ),
        SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
          onInvoke: (intent) => _seekBackward(),
        ),
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) async {
          if (event is KeyDownEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowLeft) {
              _startScrub(-1);
            } else if (k == LogicalKeyboardKey.arrowRight) {
              _startScrub(1);
            }
            _cancelAutoHide();
            forceShowControls = true;
            showControls = true;
            isSeeking = true;
            setState(() {});
          } else if (event is KeyUpEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowLeft ||
                k == LogicalKeyboardKey.arrowRight) {
              await _stopScrub(commit: true);
              _startAutoHide(seconds: 8);
            }
          }
        },
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PlayerView(
                player: _player,
                key: _playerViewKey,
                playerViewConfig: const PlayerViewConfig(
                  pictureInPictureConfig: PictureInPictureConfig(
                    isEnabled: false,
                  ),
                ),
              ),
            ),
            if (showControls || forceShowControls) playerControls(context),
          ],
        ),
      ),
    );
  }

  AspectRatio playerControls(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: SizedBox()),
          if (showControls)
            Center(child: Image.asset(ImageIndex.logo, width: 50)),
          const Expanded(child: SizedBox()),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.isHLS
                  ? liveTag()
                  : Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Text(
                        '${_formatDuration(_scrubValue ?? currentTime)} / ${_formatDuration(duration)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
              Expanded(
                child: Slider(
                  inactiveColor: Colors.grey,
                  thumbColor: (isSeeking || _scrubValue != null)
                      ? Colors.white
                      : const Color(0xFFFBB03B),
                  value: duration > 0
                      ? (_scrubValue ?? currentTime).clamp(0, duration)
                      : 0,
                  max: duration > 0 ? duration : 1,
                  onChangeStart: (_) {
                    isSeeking = true;
                    forceShowControls = true;
                    _scrubValue ??= currentTime;
                    setState(() {});
                  },
                  onChanged: (v) {
                    _scrubValue = v;
                    setState(() {});
                  },
                  onChangeEnd: (_) async {
                    if (_scrubValue != null) {
                      final v = _scrubValue!.clamp(0, duration).toDouble();
                      _player.seek(v);
                      _scrubValue = null;
                    }
                    isSeeking = false;
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
    );
  }

  String _formatDuration(double value) {
    try {
      final position = Duration(seconds: value.toInt());
      final minutes = position.inMinutes
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      final seconds = position.inSeconds
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      final hours = position.inHours.remainder(24).toString().padLeft(2, '0');
      return '${int.parse(hours) > 0 ? "$hours:" : ''}$minutes:$seconds';
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
    return '--:--';
  }
}

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class PlayIntent extends Intent {
  const PlayIntent();
}

class PauseIntent extends Intent {
  const PauseIntent();
}

class StopIntent extends Intent {
  const StopIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}
