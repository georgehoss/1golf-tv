import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/items_list.dart';
import '../../utils/image_index.dart';
import '../../widgets/common/item_list_widget.dart';

/// League/tour detail screen. Structure ported from
/// `one_golf_app/lib/src/pages/leagues/league_detail_page.dart`.
class LeagueDetailPage extends StatefulWidget {
  const LeagueDetailPage({super.key});

  @override
  State<LeagueDetailPage> createState() => _LeagueDetailPageState();
}

class _LeagueDetailPageState extends State<LeagueDetailPage> {
  final controller = Get.find<MainController>();

  @override
  void dispose() {
    controller.hasLeagueDetail.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Get.back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(ImageIndex.backgroundHome),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: GetBuilder(
                init: controller,
                builder: (context) {
                  if (controller.isLoadingLeague.isTrue &&
                      !controller.hasLeagueDetail()) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return const LeagueDetailContent();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueDetailContent extends StatefulWidget {
  const LeagueDetailContent({super.key});

  @override
  State<LeagueDetailContent> createState() => _LeagueDetailContentState();
}

class _LeagueDetailContentState extends State<LeagueDetailContent> {
  final List<FocusNode> _focusNodes = [];
  bool _initialFocusRequested = false;

  FocusNode _nodeAt(int index) {
    while (_focusNodes.length <= index) {
      _focusNodes.add(FocusNode());
    }
    return _focusNodes[index];
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainController>();
    final league = controller.leagueDetails.value;

    if (league == null) {
      return const Center(
        child: Text(
          'No se encontró información de la liga',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    final videoItems = league.components?.items
            ?.map(
              (item) => ItemsListItem(
                objectId: item.objectId,
                title: item.title,
                image: item.image,
                media: item.media,
                private: item.private,
              ),
            )
            .toList() ??
        [];

    final lists = <ItemsList>[
      if (videoItems.isNotEmpty)
        ItemsList(title: 'Videos', type: 'videos', items: videoItems),
      if (league.components?.itemslist1?.items?.isNotEmpty ?? false)
        league.components!.itemslist1!,
      if (league.components?.itemslist2?.items?.isNotEmpty ?? false)
        league.components!.itemslist2!,
      if (league.components?.itemslist3?.items?.isNotEmpty ?? false)
        league.components!.itemslist3!,
    ];

    if (!_initialFocusRequested && lists.isNotEmpty) {
      _initialFocusRequested = true;
      final firstFocus = _nodeAt(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        firstFocus.requestFocus();
      });
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Row(
              children: [
                if (league.logo != null && league.logo!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: league.logo!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) =>
                        Image.asset(ImageIndex.logo, width: 48, height: 48),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    league.title ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0xFFFBB03B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < lists.length; i++)
          SliverToBoxAdapter(
            child: ItemListWidget(
              itemsList: lists[i],
              entryFocus: _nodeAt(i),
              nextFocus: i + 1 < lists.length ? _nodeAt(i + 1) : null,
              previousFocus: i > 0 ? _nodeAt(i - 1) : null,
              openDrawer: false,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}
