import 'package:flutter/material.dart';

/// Top-to-bottom transparent-to-black gradient, used as a shadow/overlay on
/// top of card images so text stays readable.
class CardShadow extends StatelessWidget {
  const CardShadow({
    super.key,
    this.child,
    this.height,
    this.width,
    this.borderRadius,
    this.gradientBegin = Alignment.topCenter,
    this.gradientEnd = Alignment.bottomCenter,
    this.startOpacity = 0.0,
    this.endOpacity = 1.0,
  });

  final Widget? child;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final double startOpacity;
  final double endOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: gradientBegin,
          end: gradientEnd,
          colors: [
            Color.fromRGBO(0, 0, 0, startOpacity),
            Color.fromRGBO(0, 0, 0, endOpacity),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}
