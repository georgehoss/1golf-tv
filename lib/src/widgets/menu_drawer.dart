import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/main_controller.dart';
import '../pages/home/home_page.dart';
import '../pages/sign_in/qr_login_page.dart';
import '../utils/image_index.dart';

class MenuDrawer extends StatefulWidget {
  const MenuDrawer({super.key});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  final controller = Get.find<MainController>();
  final authController = Get.find<AuthController>();
  final FocusNode _focusNode = FocusNode();
  final focusNodes = <FocusNode>[FocusNode(), FocusNode()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNodes[0].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (value) {
        if (_focusNode.hasFocus) {
          if (value.logicalKey == LogicalKeyboardKey.goBack ||
              value.logicalKey == LogicalKeyboardKey.escape ||
              value.logicalKey == LogicalKeyboardKey.arrowRight) {
            controller.closeDrawer();
          }
        }
      },
      child: GetBuilder(
        init: controller,
        builder: (_) {
          return FocusableActionDetector(
            descendantsAreFocusable: true,
            child: Drawer(
              backgroundColor: const Color(0xFF000354),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView(
                  children: [
                    const SizedBox(height: 20),
                    DrawerItemWidget(
                      nodes: focusNodes,
                      focusNode: focusNodes[0],
                      index: 0,
                      icon: const Icon(
                        Icons.account_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      title: authController.isAuthenticated.value
                          ? 'Cerrar sesión'
                          : 'Iniciar sesión',
                      onTap: () {
                        Get.back();
                        if (authController.isAuthenticated.value) {
                          controller.logout();
                        } else {
                          Get.to(() => const QRLoginPage());
                        }
                      },
                    ),
                    DrawerItemWidget(
                      nodes: focusNodes,
                      focusNode: focusNodes[1],
                      index: 1,
                      icon: SvgPicture.asset(
                        ImageIndex.homeIcon,
                        height: 20,
                        width: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      title: 'Inicio',
                      onTap: () {
                        Get.back();
                        controller.currentIndex.value = 1;
                        Get.offAll(() => const HomePage());
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DrawerItemWidget extends StatefulWidget {
  const DrawerItemWidget({
    super.key,
    required this.title,
    required this.index,
    required this.focusNode,
    required this.nodes,
    this.onTap,
    this.icon,
  });

  final String title;
  final int index;
  final VoidCallback? onTap;
  final Widget? icon;
  final FocusNode focusNode;
  final List<FocusNode> nodes;

  @override
  State<DrawerItemWidget> createState() => _DrawerItemWidgetState();
}

class _DrawerItemWidgetState extends State<DrawerItemWidget> {
  bool isSelected = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _DownIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _UpIntent(),
      },
      actions: {
        _DownIntent: CallbackAction(
          onInvoke: (intent) {
            final next = (widget.index + 1) % widget.nodes.length;
            widget.nodes[next].requestFocus();
            return null;
          },
        ),
        _UpIntent: CallbackAction(
          onInvoke: (intent) {
            final prev =
                (widget.index - 1 + widget.nodes.length) % widget.nodes.length;
            widget.nodes[prev].requestFocus();
            return null;
          },
        ),
        ActivateIntent: CallbackAction(
          onInvoke: (intent) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) => setState(() => isSelected = value),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            width: Get.width * 0.9,
            padding: EdgeInsets.only(bottom: isSelected ? 5 : 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 2,
                  color: isSelected ? const Color(0xFFFBB03B) : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.all(10),
                  child: widget.icon ??
                      Image.asset(ImageIndex.logo, height: 20, width: 20),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: isSelected ? 22 : 18,
                    ),
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

class _UpIntent extends Intent {
  const _UpIntent();
}

class _DownIntent extends Intent {
  const _DownIntent();
}
