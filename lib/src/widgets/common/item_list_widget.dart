import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/items_list.dart';
import '../../pages/player/player_page.dart' as player;
import '../../utils/image_index.dart';

/// Unified horizontal item list (shows, itemslist_N, league/show video
/// lists). UX ported from
/// `one_golf_app/lib/src/widgets/common/item_list_widget.dart`; D-pad focus
/// mechanics adapted from the baseball TV base's item list widget.
///
/// Cross-section Up/Down is wired explicitly via [nextFocus]/[previousFocus]
/// rather than relying on Flutter's default directional focus traversal,
/// which proved unreliable across horizontally-scrolling `ListView`s stacked
/// in a vertical scroll view (confirmed on-device: Down silently did nothing
/// once a widget below intercepted arrow keys without an escape path).
class ItemListWidget extends StatefulWidget {
  const ItemListWidget({
    super.key,
    required this.itemsList,
    required this.entryFocus,
    this.nextFocus,
    this.previousFocus,
    this.openDrawer = true,
  });

  final ItemsList itemsList;
  final FocusNode entryFocus;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;
  final bool openDrawer;

  @override
  State<ItemListWidget> createState() => _ItemListWidgetState();
}

class _ItemListWidgetState extends State<ItemListWidget> {
  final List<FocusNode> _focusNodes = [];
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final items = widget.itemsList.items ?? [];
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
    final items = widget.itemsList.items ?? [];
    if (items.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.itemsList.title != null &&
              widget.itemsList.title!.isNotEmpty)
            Text(
              widget.itemsList.title!,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Color(0xFFFBB03B),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: FocusTraversalGroup(
              descendantsAreFocusable: true,
              child: ListView.builder(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ItemCard(
                    item: items[index],
                    index: index,
                    focusNodes: _focusNodes,
                    hScrollController: _hScrollController,
                    openDrawer: widget.openDrawer,
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

class ItemCard extends StatefulWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.focusNodes,
    required this.hScrollController,
    this.openDrawer = true,
    this.nextFocus,
    this.previousFocus,
  });

  final ItemsListItem item;
  final int index;
  final List<FocusNode> focusNodes;
  final ScrollController hScrollController;
  final bool openDrawer;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final focusNode = widget.focusNodes[widget.index];

    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
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
            } else if (widget.openDrawer) {
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
            } else if (widget.openDrawer) {
              Get.find<MainController>().openDrawer();
            }
            return null;
          },
        ),
        _OpenDrawerIntent: CallbackAction(
          onInvoke: (intent) {
            if (!widget.openDrawer) {
              // On detail pages (not Home) the back key pops the page
              // instead of opening the drawer.
              Get.back();
              return null;
            }
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
            final url = widget.item.media ?? widget.item.fullPathEvent;
            if (url == null || url.isEmpty) {
              Get.snackbar(
                widget.item.title ?? 'Video',
                'Este video no está disponible',
                backgroundColor: Colors.grey[900],
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
              return null;
            }
            Get.to(() => player.VideoPlayer(item: widget.item));
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
          width: _hasFocus ? 220 : 200,
          padding: const EdgeInsets.all(5.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
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
                      imageUrl: widget.item.image ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Image.asset(ImageIndex.logo, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2),
                child: Text(
                  widget.item.title ?? '',
                  maxLines: _hasFocus ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: _hasFocus ? 13 : 11,
                    fontWeight: _hasFocus ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
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
