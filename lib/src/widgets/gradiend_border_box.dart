import 'package:flutter/material.dart';

import '../utils/image_index.dart';

class GradientBorderBox extends StatelessWidget {
  const GradientBorderBox(
      {super.key, this.width = 100, this.height = 100, required this.child});

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: CustomPaint(
            painter: RadialGradientPainter(),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  ImageIndex.backgroundGlass,
                  fit: BoxFit.cover,
                ),
                // child: ShaderMask(
                //   shaderCallback: (bounds) {
                //     return RadialGradient(
                //       colors: [
                //         const Color(0xFFA5EFFF).withOpacity(1.0),
                //         const Color(0xFF6EBFF4).withOpacity(0.44),
                //         const Color(0xFF4690D4).withOpacity(0.5),
                //       ],
                //       stops: const [0.0, 0.77, 1.0],
                //       center: Alignment.center,
                //       radius: 1.0,
                //     ).createShader(bounds);
                //   },
                //   blendMode: BlendMode.dstIn,
                //   child: Opacity(
                //     opacity: 1,
                //     child: Image.asset(
                //       'assets/glass2.png', // Usa tu imagen de ruido aquí
                //       fit: BoxFit.cover,
                //       width: double.infinity,
                //       height: double.infinity,
                //     ),
                //   ),
                // ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: width,
          height: height,
          child: Center(
            child: child,
          ),
        ),
      ],
    );
  }
}

class RadialGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Gradiente radial invertido para la esquina superior izquierda
    final gradient1 = RadialGradient(
      colors: [
        const Color(0xFF739AFF).withAlpha((0.3 * 255).toInt()),
        const Color(0xFF06238D).withAlpha(0),
      ],
      stops: const [0.0, 1.0],
      radius: 3.0,
      center: Alignment.topLeft, // Invertido
    ).createShader(rect);

    // Gradiente radial invertido para la esquina inferior derecha
    final gradient2 = RadialGradient(
      colors: [
        const Color(0xFF69C0FF).withAlpha(255),
        const Color(0xFFFFFFFF).withAlpha(0),
      ],
      stops: const [0.0, 1.0],
      radius: 1.2,
      center: Alignment.topLeft, // Invertido
    ).createShader(rect);

    final paint = Paint()
      ..shader = gradient1
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final borderRadius = BorderRadius.circular(5).toRRect(rect);
    canvas.drawRRect(borderRadius, paint);

    // Segundo gradiente radial
    paint.shader = gradient2;
    canvas.drawRRect(borderRadius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
