import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/items_list.dart';
import '../../utils/image_index.dart';
import '../../widgets/common/item_list_widget.dart';

/// Show detail screen. Structure ported from
/// `one_golf_app/lib/src/pages/shows/show_detail_page.dart`.
class ShowDetailPage extends StatefulWidget {
  const ShowDetailPage({super.key});

  @override
  State<ShowDetailPage> createState() => _ShowDetailPageState();
}

class _ShowDetailPageState extends State<ShowDetailPage> {
  final controller = Get.find<MainController>();

  @override
  void dispose() {
    controller.hasShowDetail.value = false;
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
                  if (controller.isLoadingShow.isTrue &&
                      !controller.hasShowDetail()) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return const ShowDetailContent();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShowDetailContent extends StatefulWidget {
  const ShowDetailContent({super.key});

  @override
  State<ShowDetailContent> createState() => _ShowDetailContentState();
}

class _ShowDetailContentState extends State<ShowDetailContent> {
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
    final show = controller.showDetails.value;

    if (show == null) {
      return const Center(
        child: Text(
          'No se encontró información del programa',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    final videoItems =
        show.components?.items
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
      if (show.components?.itemslist1?.items?.isNotEmpty ?? false)
        show.components!.itemslist1!,
      if (show.components?.itemslist2?.items?.isNotEmpty ?? false)
        show.components!.itemslist2!,
      if (show.components?.itemslist3?.items?.isNotEmpty ?? false)
        show.components!.itemslist3!,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CachedNetworkImage(
                  imageUrl: show.thumb ?? '',
                  width: 200,
                  height: 100,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorWidget: (context, url, error) =>
                      Image.asset(ImageIndex.logo, width: 100, height: 60),
                ),
                const SizedBox(height: 20),
                Text(
                  show.title ?? '',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Color(0xFFFBB03B),
                  ),
                ),
                if (show.description != null && show.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      show.description!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white70,
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
