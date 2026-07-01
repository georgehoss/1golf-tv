import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../utils/image_index.dart';

/// Slim always-visible rail on the left edge of the Home screen; focusing
/// any of its icons opens the full drawer (mirrors the base TV's pattern).
class SideBarWidget extends StatefulWidget {
  const SideBarWidget({
    super.key,
    required this.currentIndex,
    required this.onFocusChange,
  });

  final int currentIndex;
  final VoidCallback onFocusChange;

  @override
  State<SideBarWidget> createState() => _SideBarWidgetState();
}

class _SideBarWidgetState extends State<SideBarWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _sideBarMenuItem(const Icon(Icons.account_circle, color: Colors.white, size: 20), 0),
          _sideBarMenuItem(
            SvgPicture.asset(
              ImageIndex.homeIcon,
              height: 20,
              width: 20,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            1,
          ),
        ],
      ),
    );
  }

  Widget _sideBarMenuItem(Widget icon, int index) {
    final focusNode = FocusNode();
    return Focus(
      focusNode: focusNode,
      onFocusChange: (value) {
        if (value) {
          focusNode.unfocus();
          widget.onFocusChange();
        }
      },
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Column(
          children: [
            icon,
            if (widget.currentIndex == index)
              Container(
                padding: const EdgeInsets.only(top: 5),
                width: 20,
                child: const Divider(color: Color(0xFFFBB03B), thickness: 2),
              ),
          ],
        ),
      ),
    );
  }
}
