import 'package:flutter/material.dart';

import '../../models/items_list.dart';
import '../../widgets/common/tv_action_button.dart';
import 'adaptative_player.dart';

/// VOD playback for a show/league/itemslist video item. Ported from
/// `one_baseball_android_tv/lib/src/pages/player/player_page.dart`, adapted
/// to golf's [ItemsListItem] model (`media` / `fullPathEvent` fields).
class VideoPlayer extends StatefulWidget {
  const VideoPlayer({super.key, required this.item});
  final ItemsListItem item;

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  final _backFocusNode = FocusNode();

  @override
  void dispose() {
    _backFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = widget.item.media ?? widget.item.fullPathEvent;

    if (videoUrl == null || videoUrl.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No hay video disponible',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TvActionButton(
                focusNode: _backFocusNode,
                label: 'Volver',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AdaptivePlayer(
                url: videoUrl,
                isHLS: false,
                title: widget.item.title ?? '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
