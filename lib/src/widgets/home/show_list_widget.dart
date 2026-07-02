import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/home_components.dart';
import '../../models/items_list.dart';
import '../../pages/shows/show_detail_page.dart';
import '../../utils/image_index.dart';

/// Horizontal list of shows that opens `ShowDetailPage` on select. UX
/// ported from `one_golf_app/lib/src/widgets/home/show_list_widget.dart` —
/// distinct from the generic `common/item_list_widget.dart` (used for
/// `itemslist_N`, which plays a video instead of opening a detail page).
class ShowListWidget extends StatefulWidget {
  const ShowListWidget({
    super.key,
    required this.shows,
    required this.entryFocus,
    this.nextFocus,
    this.previousFocus,
  });

  final ItemsList shows;
  final FocusNode entryFocus;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<ShowListWidget> createState() => _ShowListWidgetState();
}

class _ShowListWidgetState extends State<ShowListWidget> {
  final List<FocusNode> _focusNodes = [];
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final items = widget.shows.items ?? [];
    for (var i = 0; i < items.length; i++) {
      _focusNodes.add(i == 0 ? widget.entryFocus : FocusNode());
    }
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.shows.items ?? [];
    if (items.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.shows.title != null && widget.shows.title!.isNotEmpty)
            Text(
              widget.shows.title!,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Color(0xFFFBB03B),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: FocusTraversalGroup(
              descendantsAreFocusable: true,
              child: ListView.builder(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ShowCard(
                    item: items[index],
                    index: index,
                    focusNodes: _focusNodes,
                    nextFocus: widget.nextFocus,
                    previousFocus: widget.previousFocus,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShowCard extends StatefulWidget {
  const ShowCard({
    super.key,
    required this.item,
    required this.index,
    required this.focusNodes,
    this.nextFocus,
    this.previousFocus,
  });

  final ItemsListItem item;
  final int index;
  final List<FocusNode> focusNodes;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<ShowCard> createState() => _ShowCardState();
}

class _ShowCardState extends State<ShowCard> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final focusNode = widget.focusNodes[widget.index];

    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _MoveLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _MoveRightIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _MoveDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _MoveUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.goBack): const _OpenDrawerIntent(),
      },
      actions: {
        _MoveLeftIntent: CallbackAction(
          onInvoke: (intent) {
            if (widget.index > 0) {
              widget.focusNodes[widget.index - 1].requestFocus();
            } else {
              Get.find<MainController>().openDrawer();
            }
            return null;
          },
        ),
        _MoveRightIntent: CallbackAction(
          onInvoke: (intent) {
            if (widget.index < widget.focusNodes.length - 1) {
              widget.focusNodes[widget.index + 1].requestFocus();
            }
            return null;
          },
        ),
        _MoveDownIntent: CallbackAction(
          onInvoke: (intent) {
            widget.nextFocus?.requestFocus();
            return null;
          },
        ),
        _MoveUpIntent: CallbackAction(
          onInvoke: (intent) {
            if (widget.previousFocus != null) {
              widget.previousFocus!.requestFocus();
            } else {
              Get.find<MainController>().openDrawer();
            }
            return null;
          },
        ),
        _OpenDrawerIntent: CallbackAction(
          onInvoke: (intent) {
            widget.focusNodes[0].requestFocus();
            Future.delayed(
              const Duration(milliseconds: 100),
              () => Get.find<MainController>().openDrawer(),
            );
            return null;
          },
        ),
        ActivateIntent: CallbackAction(
          onInvoke: (intent) {
            final controller = Get.find<MainController>();
            controller.setSelectedShow(
              VideoItem(
                objectId: widget.item.objectId,
                title: widget.item.title,
                image: widget.item.image,
                logo: widget.item.thumb,
                private: widget.item.private,
              ),
            );
            Get.to(() => const ShowDetailPage());
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: focusNode,
        onFocusChange: (value) {
          setState(() => _hasFocus = value);
          if (value) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.3,
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _hasFocus
                            ? const Color(0xFFFBB03B)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.item.thumb ?? widget.item.image ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Image.asset(ImageIndex.logo, fit: BoxFit.fitHeight),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.item.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: _hasFocus ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveLeftIntent extends Intent {
  const _MoveLeftIntent();
}

class _MoveRightIntent extends Intent {
  const _MoveRightIntent();
}

class _MoveDownIntent extends Intent {
  const _MoveDownIntent();
}

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

class _OpenDrawerIntent extends Intent {
  const _OpenDrawerIntent();
}
