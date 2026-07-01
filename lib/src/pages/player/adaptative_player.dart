import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import 'bitmovin_player.dart';
import 'fallback_player.dart';

/// Picks the right player for the device. Ported from
/// `one_baseball_android_tv` without the Tizen branch (Fase 2, deferred).
///
/// [cutoffSdk] defaults to 26 (Android 8.0): devices below that — notably
/// older Fire TV Sticks on Fire OS 5/6 (SDK 22/25) — fall back to
/// [FallbackVideoPlayer] (`video_player`) instead of the native Bitmovin SDK.
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

  @override
  State<AdaptivePlayer> createState() => _AdaptivePlayerState();
}

class _AdaptivePlayerState extends State<AdaptivePlayer> {
  int? _sdkInt;

  @override
  void initState() {
    super.initState();
    _detectPlatform();
  }

  Future<void> _detectPlatform() async {
    if (!Platform.isAndroid) {
      setState(() => _sdkInt = 33);
      return;
    }
    final info = await DeviceInfoPlugin().androidInfo;
    setState(() => _sdkInt = info.version.sdkInt);
  }

  @override
  Widget build(BuildContext context) {
    if (_sdkInt == null) {
      return const ColoredBox(color: Colors.black);
    }

    if (_sdkInt! < widget.cutoffSdk) {
      return FallbackVideoPlayer(
        url: widget.url,
        url2: widget.url2,
        title: widget.title,
        isHLS: widget.isHLS,
      );
    } else {
      return BitmovinPlayer(
        url: widget.url,
        url2: widget.url2,
        title: widget.title,
        isHLS: widget.isHLS,
      );
    }
  }
}
