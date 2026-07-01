import 'package:flutter/material.dart';

import '../player/adaptative_player.dart';

/// Full-screen live channel playback. Adapted from
/// `one_baseball_android_tv/lib/src/pages/live/live_preview_page.dart`:
/// takes the resolved (url, url2, title) directly instead of a baseball
/// `Game` model, since golf resolves its own live URL via
/// [MainController.resolveChannelUrl] (Dailymotion or direct stream).
///
/// Unlike baseball, this does NOT refetch Home data on dispose: baseball
/// does that to refresh live game scores that may have changed while
/// watching, but golf's Home has no per-item live state that needs
/// refreshing after a viewing session, and doing a full network
/// refetch + GetX rebuild right as the player is mid-teardown risked
/// stalling the UI thread (observed as an ANR on-device).
class LivePreviewPage extends StatefulWidget {
  const LivePreviewPage({
    super.key,
    required this.url,
    this.url2,
    required this.title,
  });

  final String url;
  final String? url2;
  final String title;

  @override
  State<LivePreviewPage> createState() => _LivePreviewPageState();
}

class _LivePreviewPageState extends State<LivePreviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AdaptivePlayer(
                title: widget.title,
                url: widget.url,
                url2: widget.url2,
                isHLS: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
