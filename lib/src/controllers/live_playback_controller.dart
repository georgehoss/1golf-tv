import 'package:bitmovin_player/bitmovin_player.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../models/home_components.dart';
import '../pages/player/adaptative_player.dart';
import '../pages/player/bitmovin_config.dart';
import 'main_controller.dart';

enum LivePlaybackStatus { idle, starting, playing, failed }

enum LiveViewOwner { inline, fullscreen }

/// Owns the long-lived player behind the home live preview tile so the same
/// stream can be handed off to the full-screen player and back with no reload.
///
/// Uses native Bitmovin on Android SDK ≥ 26 and `video_player` everywhere else
/// — including Tizen, whose full-screen player is a WebView the inline tile
/// cannot hand off to (see [suspendForFullscreen]).
/// The player is created once per channel
/// and kept alive across the full-screen route (which attaches to it via
/// `externalPlayer`/`externalController` rather than spinning up its own), so
/// there is no rebuffer crossing between inline and full-screen. It is disposed
/// only when this controller closes (home route removed / logout).
class LivePlaybackController extends GetxController
    with WidgetsBindingObserver {
  final status = LivePlaybackStatus.idle.obs;
  final viewOwner = LiveViewOwner.inline.obs;

  Player? bitmovinPlayer;
  VideoPlayerController? videoController;

  /// Cached device engine choice — resolved once.
  PlayerEngine? _engine;
  bool get usesBitmovin => _engine == PlayerEngine.bitmovin;

  String url = '';
  String? url2;
  String title = '';

  OBChannel? _channel;
  int? _channelId;
  bool _inlineFocused = false;
  bool _triedFallback = false;
  bool _reResolvedDm = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardown();
    super.onClose();
  }

  /// Starts (or keeps) playback for [channel]. No-op if the same channel is
  /// already starting/playing. A different channel rebuilds the player, but
  /// only while the inline tile owns the view (never mid full-screen).
  Future<void> ensureStarted(OBChannel channel) async {
    final alreadyActive =
        _channelId == channel.objectId &&
        (status.value == LivePlaybackStatus.starting ||
            status.value == LivePlaybackStatus.playing);
    if (alreadyActive) return;
    if (viewOwner.value != LiveViewOwner.inline) return;

    await _teardown();

    _channel = channel;
    _channelId = channel.objectId;
    _triedFallback = false;
    _reResolvedDm = false;
    status.value = LivePlaybackStatus.starting;

    final (resolvedUrl, resolvedUrl2) = await Get.find<MainController>()
        .resolveChannelUrl(channel);
    if (resolvedUrl.isEmpty || _channelId != channel.objectId) {
      if (_channelId == channel.objectId) {
        status.value = LivePlaybackStatus.failed;
      }
      return;
    }
    url = resolvedUrl;
    url2 = resolvedUrl2;
    title = channel.title ?? '';

    _engine ??= await AdaptivePlayer.resolveEngine();
    if (_channelId != channel.objectId) return;

    if (usesBitmovin) {
      await _startBitmovin();
    } else {
      await _startVideoPlayer();
    }
  }

  // ─── Bitmovin engine ─────────────────────────────────────────────────────

  Future<void> _startBitmovin() async {
    final player = Player(config: buildGolfPlayerConfig());
    bitmovinPlayer = player;
    _bindBitmovinListeners();
    await player.loadSourceConfig(
      buildGolfSourceConfig(url: url, title: title, isHLS: true),
    );
    await player.play();
    _applyInlineMute();
  }

  void _bindBitmovinListeners() {
    final player = bitmovinPlayer;
    if (player == null) return;
    player.onPlay = (_) {
      _triedFallback = false;
      _reResolvedDm = false;
      status.value = LivePlaybackStatus.playing;
    };
    player.onError = (_) {
      _recoverBitmovin();
    };
    player.onSourceError = (_) {
      _recoverBitmovin();
    };
  }

  /// On playback error, try [url2] once, then re-resolve the (tokenized,
  /// expiring) Dailymotion URL once; if both fail, mark failed. Flags reset on
  /// the next successful play so a long session can recover again.
  Future<void> _recoverBitmovin() async {
    final player = bitmovinPlayer;
    if (player == null || status.value == LivePlaybackStatus.failed) return;

    if (!_triedFallback && (url2?.isNotEmpty ?? false)) {
      _triedFallback = true;
      await _reloadBitmovin(url2!);
      return;
    }
    if (!_reResolvedDm && _channel != null) {
      _reResolvedDm = true;
      final (freshUrl, _) = await Get.find<MainController>().resolveChannelUrl(
        _channel!,
      );
      if (freshUrl.isNotEmpty) {
        url = freshUrl;
        await _reloadBitmovin(freshUrl);
        return;
      }
    }
    status.value = LivePlaybackStatus.failed;
  }

  Future<void> _reloadBitmovin(String source) async {
    final player = bitmovinPlayer;
    if (player == null) return;
    await player.loadSourceConfig(
      buildGolfSourceConfig(url: source, title: title, isHLS: true),
    );
    await player.play();
  }

  // ─── video_player engine ─────────────────────────────────────────────────

  Future<void> _startVideoPlayer() async {
    var controller = VideoPlayerController.networkUrl(Uri.parse(url));
    var ok = await _tryInit(controller);

    if (!ok && (url2?.isNotEmpty ?? false)) {
      await controller.dispose();
      controller = VideoPlayerController.networkUrl(Uri.parse(url2!));
      ok = await _tryInit(controller);
    }
    if (!ok) {
      await controller.dispose();
      status.value = LivePlaybackStatus.failed;
      return;
    }
    if (_channelId != _channel?.objectId) {
      await controller.dispose();
      return;
    }

    videoController = controller;
    controller.addListener(_onVideoTick);
    _applyInlineMute();
    await _play();
    status.value = LivePlaybackStatus.playing;
  }

  Future<bool> _tryInit(VideoPlayerController c) async {
    try {
      await c.initialize();
      await c.setLooping(false);
      return c.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  void _onVideoTick() {
    final value = videoController?.value;
    if (value == null) return;
    if (value.hasError && status.value != LivePlaybackStatus.failed) {
      status.value = LivePlaybackStatus.failed;
    }
  }

  // ─── Mute (focus-driven while inline) ────────────────────────────────────

  void setInlineFocused(bool focused) {
    _inlineFocused = focused;
    if (viewOwner.value == LiveViewOwner.inline) _applyInlineMute();
  }

  void _applyInlineMute() {
    if (usesBitmovin) {
      _inlineFocused ? bitmovinPlayer?.unmute() : bitmovinPlayer?.mute();
    } else {
      videoController?.setVolume(_inlineFocused ? 1.0 : 0.0);
    }
  }

  // ─── Inline ↔ full-screen handoff ────────────────────────────────────────

  /// Detaches the inline view and unmutes before the full-screen route mounts.
  /// The tile swaps [PlayerView]→thumbnail on the [viewOwner] change; awaiting
  /// the frame guarantees the inline platform view is gone before the
  /// full-screen one attaches (only one view per player is allowed).
  Future<void> enterFullscreen() async {
    viewOwner.value = LiveViewOwner.fullscreen;
    if (usesBitmovin) {
      await bitmovinPlayer?.unmute();
    } else {
      await videoController?.setVolume(1.0);
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Tizen's full-screen player is a WebView running the Bitmovin Web SDK — a
  /// separate engine the inline player cannot be handed off to. So instead of
  /// [enterFullscreen]'s hand-over, the inline player releases the TV's decoder
  /// entirely before the full-screen route mounts, and [resumeInline] starts it
  /// again on return.
  Future<void> suspendForFullscreen() async {
    viewOwner.value = LiveViewOwner.fullscreen;
    await _teardown();
    status.value = LivePlaybackStatus.idle;
    // Let the tile swap its video view for the thumbnail before the full-screen
    // player claims the decoder.
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Restarts the inline preview after the Tizen full-screen player is closed.
  Future<void> resumeInline(OBChannel channel) async {
    viewOwner.value = LiveViewOwner.inline;
    await ensureStarted(channel);
  }

  /// Called from the full-screen player's `dispose` (after its view is torn
  /// down), so the inline view can safely re-attach. Re-binds Bitmovin
  /// listeners first — the full-screen player overwrote the single-slot
  /// handlers — then restores inline ownership and focus-based mute.
  void onFullscreenReleased() {
    if (usesBitmovin) _bindBitmovinListeners();
    // This runs from the full-screen player's `dispose`, i.e. during
    // `finalizeTree` while the widget tree is locked. Writing the `viewOwner`
    // observable now would rebuild the inline `Obx` mid-unmount and throw, so
    // defer the ownership swap (and mute) until the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewOwner.value = LiveViewOwner.inline;
      _applyInlineMute();
    });
  }

  // ─── App lifecycle ───────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pause();
    } else if (state == AppLifecycleState.resumed) {
      if (viewOwner.value == LiveViewOwner.inline &&
          status.value == LivePlaybackStatus.playing) {
        _play();
      }
    }
  }

  void _pause() {
    if (usesBitmovin) {
      bitmovinPlayer?.pause();
    } else {
      videoController?.pause();
    }
  }

  /// Starts playback, tolerating Tizen's missing playback-rate support.
  ///
  /// `VideoPlayerController.play()` starts the stream and *then* pushes the
  /// playback speed, which `video_player_tizen` rejects on a live stream with
  /// `PlatformException(player_set_playback_rate failed, Function not
  /// implemented)` — note the code, not the message, carries the operation. The
  /// video is already playing by the time it throws, so the failure is
  /// swallowed: letting it escape would abort `_startVideoPlayer` and leave the
  /// inline tile black.
  Future<void> _play() async {
    if (usesBitmovin) {
      await bitmovinPlayer?.play();
      return;
    }
    try {
      await videoController?.play();
    } on PlatformException catch (e) {
      if (e.code.contains('player_set_playback_rate')) return;
      rethrow;
    }
  }

  // ─── Teardown ────────────────────────────────────────────────────────────

  Future<void> _teardown() async {
    final player = bitmovinPlayer;
    if (player != null) {
      bitmovinPlayer = null;
      // Neutralize handlers (setters are non-nullable) so late events from the
      // player being torn down can't touch the state machine.
      player.onPlay = (_) {};
      player.onError = (_) {};
      player.onSourceError = (_) {};
      await player.pause();
      await player.dispose();
    }
    final vc = videoController;
    if (vc != null) {
      videoController = null;
      vc.removeListener(_onVideoTick);
      await vc.dispose();
    }
  }
}
