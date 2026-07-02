import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/calendar_components.dart';
import '../../utils/image_index.dart';

/// Font used for the calendar cards. The 1Golf design calls for "GC Frank"
/// (Golf Channel's proprietary typeface); until that licensed font file is
/// dropped into `fonts/` and registered in `pubspec.yaml`, this falls back
/// to Montserrat. Swap this single constant to `'GCFrank'` once the font is added.
const String _calendarFont = 'Montserrat';

/// Horizontal list of upcoming tournaments. UX ported from
/// `one_golf_app/lib/src/widgets/home/home_calendar_widget.dart` (tournament
/// card: logo + name + course + location + date) — NOT from the baseball TV
/// base, whose calendar shows a completely different thing (game cards with
/// home/away team logos). D-pad focus mechanics are adapted from the base.
///
/// Cross-section Up/Down is wired explicitly via [nextFocus]/[previousFocus]
/// (see `common/item_list_widget.dart` for why).
class HomeCalendar extends StatefulWidget {
  const HomeCalendar({
    super.key,
    required this.calendar,
    required this.entryFocus,
    this.nextFocus,
    this.previousFocus,
  });

  final List<GolfTournament> calendar;
  final FocusNode entryFocus;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  final List<FocusNode> _focusNodes = [];
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.calendar.length; i++) {
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
    if (widget.calendar.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sin título de sección (por diseño).
          SizedBox(
            height: 94,
            child: FocusTraversalGroup(
              descendantsAreFocusable: true,
              child: ListView.separated(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.calendar.length,
                separatorBuilder: (_, _) => const VerticalDivider(
                  color: Colors.white,
                  thickness: 0.5,
                ),
                itemBuilder: (context, index) {
                  return CalendarCard(
                    tournament: widget.calendar[index],
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

class CalendarCard extends StatefulWidget {
  const CalendarCard({
    super.key,
    required this.tournament,
    required this.index,
    required this.focusNodes,
    this.nextFocus,
    this.previousFocus,
  });

  final GolfTournament tournament;
  final int index;
  final List<FocusNode> focusNodes;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final focusNode = widget.focusNodes[widget.index];

    return FocusableActionDetector(
      shortcuts: {
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
        child: SizedBox(
          width: Get.width * 0.28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              // Logo aligns to the TOP of the text block (top of the title),
              // matching the 1Golf mockup — not vertically centered.
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CachedNetworkImage(
                  width: 50,
                  height: 50,
                  imageUrl: widget.tournament.logo ?? '',
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) =>
                      Image.asset(ImageIndex.logo, width: 36, height: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title: bold.
                      Text(
                        widget.tournament.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _hasFocus
                              ? const Color(0xFFFBB03B)
                              : Colors.white,
                          fontSize: 13,
                          fontFamily: _calendarFont,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Subtitle (course): light.
                      Text(
                        widget.tournament.course ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: _calendarFont,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Date: white, light.
                      Text(
                        widget.tournament.date ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: _calendarFont,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
