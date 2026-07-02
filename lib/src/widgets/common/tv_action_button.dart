import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// High-contrast white button with explicit D-pad focus handling
/// (select/enter → activate), for error-state actions (retry, go back).
///
/// The default Material `ElevatedButton` was effectively invisible here:
/// with no `elevatedButtonTheme` set, M3 resolves its text to
/// `colorScheme.primary` (dark navy) on a dark surface — dark-on-dark. It
/// also had no explicit `FocusNode`, relying on Flutter's default focus
/// traversal to reach it, which this app doesn't trust elsewhere either.
class TvActionButton extends StatefulWidget {
  const TvActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.autofocus = true,
  });

  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<TvActionButton> createState() => _TvActionButtonState();
}

class _TvActionButtonState extends State<TvActionButton> {
  bool _hasFocus = false;
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (value) => setState(() => _hasFocus = value),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hasFocus
                    ? const Color(0xFFFBB03B)
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFF01274F),
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
