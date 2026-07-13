import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import '../../utils/platform_info.dart';
import 'bitmovin_player.dart';
import 'fallback_player.dart';
import 'tizen_web_player.dart';

/// Playback engine for the current device.
enum PlayerEngine {
  /// Native Bitmovin SDK — Android TV / Fire TV on SDK ≥ [AdaptivePlayer.cutoffSdk].
  bitmovin,

  /// `video_player` — older Fire TV Sticks (Fire OS 5/6, SDK 22/25), where the
  /// native Bitmovin SDK is unsupported.
  fallback,

  /// Bitmovin **Web** SDK inside a WebView — Samsung Tizen, which has no native
  /// Bitmovin SDK. See [TizenWebPlayer].
  tizenWeb,
}

/// Picks the right player for the device.
///
/// [cutoffSdk] defaults to 26 (Android 8.0), the minimum for the native
/// Bitmovin SDK.
class AdaptivePlayer extends StatefulWidget {
  const AdaptivePlayer({
    super.key,
    required this.url,
    required this.isHLS,
    this.url2,
    required this.title,
    this.cutoffSdk = 26,
  });

  final String title;
  final String url;
  final bool isHLS;
  final String? url2;
  final int cutoffSdk;

  /// Engine this device will use. Shared with `LivePlaybackController` so the
  /// home inline preview and the full-screen player agree.
  static Future<PlayerEngine> resolveEngine({int cutoffSdk = 26}) async {
    if (isTizen) return PlayerEngine.tizenWeb;
    if (!Platform.isAndroid) return PlayerEngine.bitmovin;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= cutoffSdk
        ? PlayerEngine.bitmovin
        : PlayerEngine.fallback;
  }

  @override
  State<AdaptivePlayer> createState() => _AdaptivePlayerState();
}

class _AdaptivePlayerState extends State<AdaptivePlayer> {
  PlayerEngine? _engine;

  @override
  void initState() {
    super.initState();
    AdaptivePlayer.resolveEngine(cutoffSdk: widget.cutoffSdk).then((engine) {
      if (mounted) setState(() => _engine = engine);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_engine) {
      null => const ColoredBox(color: Colors.black),
      PlayerEngine.tizenWeb => TizenWebPlayer(
        url: widget.url,
        url2: widget.url2,
        title: widget.title,
        isHLS: widget.isHLS,
      ),
      PlayerEngine.fallback => FallbackVideoPlayer(
        url: widget.url,
        url2: widget.url2,
        title: widget.title,
        isHLS: widget.isHLS,
      ),
      PlayerEngine.bitmovin => BitmovinPlayer(
        url: widget.url,
        url2: widget.url2,
        title: widget.title,
        isHLS: widget.isHLS,
      ),
    };
  }
}
