import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/main_controller.dart';
import '../../models/home_components.dart';
import '../../models/items_list.dart';
import '../../pages/leagues/league_detail_page.dart';
import '../../utils/image_index.dart';
import 'card_shadow.dart';

/// Single horizontal row combining live channels + leagues/tours — same
/// scroll and same card sizing as the baseball TV base's
/// `channel_list_widget.dart` (portrait card, aspect ratio 275/431, width
/// 205↔220 on focus, channels first then leagues in one `ListView`).
///
/// Earlier this was two separate sections (a 2-column channels grid ported
/// from `one_golf_app`, and a standalone leagues carousel) — the user asked
/// for it to match 1BN: one combined scroll, same sizes.
class ChannelsLiveWidget extends StatefulWidget {
  const ChannelsLiveWidget({
    super.key,
    required this.channels,
    this.leagues,
    required this.entryFocus,
    this.nextFocus,
    this.previousFocus,
  });

  final OBChannels channels;
  final ItemsList? leagues;
  final FocusNode entryFocus;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<ChannelsLiveWidget> createState() => _ChannelsLiveWidgetState();
}

class _ChannelsLiveWidgetState extends State<ChannelsLiveWidget> {
  final List<FocusNode> _focusNodes = [];
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final channelCount = widget.channels.items?.length ?? 0;
    final leagueCount = widget.leagues?.items?.length ?? 0;
    for (var i = 0; i < channelCount + leagueCount; i++) {
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
    final channelItems = widget.channels.items ?? [];
    final leagueItems = widget.leagues?.items ?? [];
    if (channelItems.isEmpty && leagueItems.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.channels.title != null &&
              widget.channels.title!.isNotEmpty)
            Text(
              widget.channels.title!,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFFBB03B),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 325,
            child: FocusTraversalGroup(
              descendantsAreFocusable: true,
              child: ListView.builder(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: channelItems.length + leagueItems.length,
                itemBuilder: (context, index) {
                  if (index < channelItems.length) {
                    return ChannelLiveCard(
                      channel: channelItems[index],
                      index: index,
                      focusNodes: _focusNodes,
                      nextFocus: widget.nextFocus,
                      previousFocus: widget.previousFocus,
                    );
                  }
                  final league = leagueItems[index - channelItems.length];
                  return LeagueCard(
                    item: league,
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

/// Shared portrait card shell (aspect ratio 275/431, width 205↔220 on
/// focus) used by both [ChannelLiveCard] and [LeagueCard] so the whole row
/// looks uniform, matching 1BN.
class _RowCardShell extends StatelessWidget {
  const _RowCardShell({required this.hasFocus, required this.child});

  final bool hasFocus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(hasFocus ? 5.0 : 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: hasFocus ? 220 : 205,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: AspectRatio(aspectRatio: 275 / 431, child: child),
        ),
      ),
    );
  }
}

class ChannelLiveCard extends StatefulWidget {
  const ChannelLiveCard({
    super.key,
    required this.channel,
    required this.index,
    required this.focusNodes,
    this.nextFocus,
    this.previousFocus,
  });

  final OBChannel channel;
  final int index;
  final List<FocusNode> focusNodes;
  final FocusNode? nextFocus;
  final FocusNode? previousFocus;

  @override
  State<ChannelLiveCard> createState() => _ChannelLiveCardState();
}

class _ChannelLiveCardState extends State<ChannelLiveCard> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainController>();
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
            } else {
              controller.openDrawer();
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
              controller.openDrawer();
            }
            return null;
          },
        ),
        _OpenDrawerIntent: CallbackAction(
          onInvoke: (intent) {
            widget.focusNodes[0].requestFocus();
            Future.delayed(
              const Duration(milliseconds: 100),
              () => controller.openDrawer(),
            );
            return null;
          },
        ),
        ActivateIntent: CallbackAction(
          onInvoke: (intent) {
            controller.selectChannel(widget.channel);
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
        child: _RowCardShell(
          hasFocus: _hasFocus,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CachedNetworkImage(
                  imageUrl: widget.channel.thummb ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) =>
                      Image.asset(ImageIndex.logo, fit: BoxFit.cover),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CardShadow(
                    width: double.infinity,
                    height: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: _hasFocus ? 14 : 12,
                              fontWeight: _hasFocus
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.white,
                            ),
                            child: Text(
                              widget.channel.title ?? '',
                              textAlign: TextAlign.center,
                              maxLines: _hasFocus ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBB03B),
                  borderRadius: BorderRadius.circular(3),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 4.0,
                ),
                child: const Text(
                  'EN VIVO',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    color: Colors.black,
                  ),
                ),
              ),
              if (_hasFocus)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFFBB03B),
                        width: 3,
                      ),
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
    final controller = Get.find<MainController>();
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
            } else {
              controller.openDrawer();
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
              controller.openDrawer();
            }
            return null;
          },
        ),
        _OpenDrawerIntent: CallbackAction(
          onInvoke: (intent) {
            widget.focusNodes[0].requestFocus();
            Future.delayed(
              const Duration(milliseconds: 100),
              () => controller.openDrawer(),
            );
            return null;
          },
        ),
        ActivateIntent: CallbackAction(
          onInvoke: (intent) {
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
        child: _RowCardShell(
          hasFocus: _hasFocus,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C213F),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: CachedNetworkImage(
                      imageUrl: widget.item.image ?? widget.item.logo ?? '',
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) =>
                          Image.asset(ImageIndex.logo, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              if (_hasFocus)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFFBB03B),
                        width: 3,
                      ),
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
