import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/home_components.dart';
import '../../models/items_list.dart';
import '../../pages/leagues/league_detail_page.dart';
import '../../utils/image_index.dart';

/// Horizontal carousel of tour/league logos. UX ported from
/// `one_golf_app/lib/src/widgets/home/leagues_home_widget.dart` — this
/// section doesn't exist at all in the baseball TV base.
///
/// Cross-section Up/Down is wired explicitly via [nextFocus]/[previousFocus]
/// (see `common/item_list_widget.dart` for why).
class LeaguesHomeWidget extends StatefulWidget {
  const LeaguesHomeWidget({
    super.key,
    required this.leagues,
    required this.entryFocus,
    this.nextFocus,
    this.previousFocus,
  });

  final ItemsList leagues;
  final FocusNode entryFocus;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<LeaguesHomeWidget> createState() => _LeaguesHomeWidgetState();
}

class _LeaguesHomeWidgetState extends State<LeaguesHomeWidget> {
  final List<FocusNode> _focusNodes = [];
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final items = widget.leagues.items ?? [];
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
    final items = widget.leagues.items ?? [];
    if (items.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.leagues.title != null && widget.leagues.title!.isNotEmpty)
            Text(
              widget.leagues.title!,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFFBB03B),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: FocusTraversalGroup(
              descendantsAreFocusable: true,
              child: ListView.builder(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return LeagueCard(
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

class LeagueCard extends StatefulWidget {
  const LeagueCard({
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
  State<LeagueCard> createState() => _LeagueCardState();
}

class _LeagueCardState extends State<LeagueCard> {
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
            controller.setSelectedLeague(
              VideoItem(
                objectId: widget.item.objectId,
                title: widget.item.title,
                image: widget.item.image,
                logo: widget.item.logo,
                private: widget.item.private,
              ),
            );
            Get.to(() => const LeagueDetailPage());
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
        child: AnimatedScale(
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1B33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasFocus ? const Color(0xFFFBB03B) : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.item.image ?? widget.item.logo ?? '',
                fit: BoxFit.contain,
                errorWidget: (context, url, error) =>
                    Image.asset(ImageIndex.logo, fit: BoxFit.contain),
              ),
            ),
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
