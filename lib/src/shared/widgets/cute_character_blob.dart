import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum SpendLevel {
  saver,
  happy,
  neutral,
  shocked,
}

class CuteCharacterBlob extends StatelessWidget {
  final double amount;
  final double limit;
  final double size;
  final bool animate;
  final bool useMiniBlob;

  const CuteCharacterBlob({
    super.key,
    required this.amount,
    required this.limit,
    this.size = 40.0,
    this.animate = true,
    this.useMiniBlob = false,
  });

  SpendLevel get spendLevel {
    if (amount <= 0) {
      return SpendLevel.saver;
    } else if (amount <= limit * 0.4) {
      return SpendLevel.happy;
    } else if (amount <= limit * 0.9) {
      return SpendLevel.neutral;
    } else {
      return SpendLevel.shocked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = spendLevel;
    
    // Select body colors based on level
    Color startColor;
    Color endColor;
    switch (level) {
      case SpendLevel.saver:
        startColor = const Color(0xFF34D399); // Teal
        endColor = const Color(0xFF059669);   // Deep Emerald
      case SpendLevel.happy:
        startColor = const Color(0xFF10B981); // Emerald
        endColor = const Color(0xFF06B6D4);   // Cyan
      case SpendLevel.neutral:
        startColor = const Color(0xFFFBBF24); // Amber
        endColor = const Color(0xFFD97706);   // Dark Amber/Orange
      case SpendLevel.shocked:
        startColor = const Color(0xFFF87171); // Light Red/Coral
        endColor = const Color(0xFFEF4444);   // Rose/Red
    }

    Widget blobWidget = useMiniBlob
        ? CustomPaint(
            size: Size(size, size),
            painter: _CuteBlobPainter(
              level: level,
              bodyColorStart: startColor,
              bodyColorEnd: endColor,
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: endColor,
                width: math.max(1.5, size * 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: startColor.withOpacity(0.35),
                  blurRadius: size * 0.12,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/chibi_character.png',
                fit: BoxFit.cover,
              ),
            ),
          );

    // Apply specific animations to each character type if enabled
    if (animate) {
      switch (level) {
        case SpendLevel.saver:
          // Saver gently floats up/down and has a tiny slow rotation
          blobWidget = blobWidget
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(begin: Offset(0, size * 0.08), end: Offset(0, -size * 0.08), duration: 2500.ms, curve: Curves.easeInOut)
              .rotate(begin: -0.03, end: 0.03, duration: 3500.ms, curve: Curves.easeInOut);
        case SpendLevel.happy:
          // Happy blob pulses/bounces slightly
          blobWidget = blobWidget
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.05, 0.95),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              )
              .move(begin: Offset(0, size * 0.05), end: Offset(0, -size * 0.05), duration: 600.ms, curve: Curves.easeOutQuad);
        case SpendLevel.neutral:
          // Neutral wiggles side-to-side very subtly
          blobWidget = blobWidget
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(begin: Offset(-size * 0.04, 0), end: Offset(size * 0.04, 0), duration: 1800.ms, curve: Curves.easeInOut);
        case SpendLevel.shocked:
          // Shocked blob shivers rapidly
          blobWidget = blobWidget
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shake(hz: 8, curve: Curves.easeInOut, rotation: 0.02);
      }
    }

    // Add extra details on top/around using stack
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: blobWidget),
          // Accessories/Particles
          if (level == SpendLevel.saver)
            Positioned(
              top: -size * 0.15,
              right: -size * 0.1,
              child: Text(
                'zZ',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981).withOpacity(0.8),
                  fontFamily: 'monospace',
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 1200.ms)
                  .move(begin: Offset.zero, end: Offset(size * 0.08, -size * 0.08), duration: 1200.ms)
                  .fadeOut(delay: 800.ms, duration: 400.ms),
            ),
          if (level == SpendLevel.happy)
            Positioned(
              top: -size * 0.18,
              left: size * 0.35,
              child: _SproutAccessory(size: size * 0.3)
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .rotate(begin: -0.15, end: 0.15, duration: 1000.ms, curve: Curves.easeInOut),
            ),
          if (level == SpendLevel.shocked)
            Positioned(
              top: size * 0.15,
              right: -size * 0.12,
              child: _SweatDropAccessory(size: size * 0.22)
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .move(begin: Offset.zero, end: Offset(0, size * 0.12), duration: 1500.ms, curve: Curves.easeIn),
            ),
        ],
      ),
    );
  }
}

class _SproutAccessory extends StatelessWidget {
  final double size;

  const _SproutAccessory({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SproutPainter(),
    );
  }
}

class _SproutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF34D399)
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round;

    // Stem
    final stemPath = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.4, size.width * 0.6, size.height * 0.1);
    canvas.drawPath(stemPath, stemPaint);

    // Left Leaf
    final leftLeaf = Path()
      ..moveTo(size.width * 0.5, size.height * 0.4)
      ..cubicTo(
        size.width * 0.1, size.height * 0.1, 
        size.width * 0.1, size.height * 0.6, 
        size.width * 0.5, size.height * 0.4
      );
    canvas.drawPath(leftLeaf, paint);

    // Right Leaf
    final rightLeaf = Path()
      ..moveTo(size.width * 0.5, size.height * 0.4)
      ..cubicTo(
        size.width * 0.9, size.height * 0.1, 
        size.width * 0.9, size.height * 0.6, 
        size.width * 0.5, size.height * 0.4
      );
    canvas.drawPath(rightLeaf, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SweatDropAccessory extends StatelessWidget {
  final double size;

  const _SweatDropAccessory({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SweatDropPainter(),
    );
  }
}

class _SweatDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..cubicTo(0, size.height * 0.6, 0, size.height, size.width * 0.5, size.height)
      ..cubicTo(size.width, size.height, size.width, size.height * 0.6, size.width * 0.5, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CuteBlobPainter extends CustomPainter {
  final SpendLevel level;
  final Color bodyColorStart;
  final Color bodyColorEnd;

  _CuteBlobPainter({
    required this.level,
    required this.bodyColorStart,
    required this.bodyColorEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [bodyColorStart, bodyColorEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Draw main blob body shape
    final path = Path();
    if (level == SpendLevel.shocked) {
      // Slightly jittery/irregular shape for shocked
      path.moveTo(size.width * 0.15, size.height * 0.25);
      path.cubicTo(
        size.width * 0.1, size.height * 0.05,
        size.width * 0.9, size.height * 0.02,
        size.width * 0.85, size.height * 0.25,
      );
      path.cubicTo(
        size.width * 0.98, size.height * 0.45,
        size.width * 0.95, size.height * 0.95,
        size.width * 0.5, size.height * 0.98,
      );
      path.cubicTo(
        size.width * 0.05, size.height * 0.95,
        size.width * 0.02, size.height * 0.45,
        size.width * 0.15, size.height * 0.25,
      );
    } else if (level == SpendLevel.saver) {
      // Sleeping saver is wide, flat, and cozy
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.15, size.width, size.height * 0.85),
        Radius.circular(size.width * 0.45),
      ));
    } else if (level == SpendLevel.happy) {
      // Happy blob is a round egg-shape
      path.moveTo(size.width * 0.2, size.height * 0.2);
      path.cubicTo(
        size.width * 0.2, size.height * 0.05,
        size.width * 0.8, size.height * 0.05,
        size.width * 0.8, size.height * 0.2,
      );
      path.cubicTo(
        size.width * 0.95, size.height * 0.45,
        size.width * 0.9, size.height * 0.95,
        size.width * 0.5, size.height * 0.95,
      );
      path.cubicTo(
        size.width * 0.1, size.height * 0.95,
        size.width * 0.05, size.height * 0.45,
        size.width * 0.2, size.height * 0.2,
      );
    } else {
      // Neutral is a squishy cube/blob
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.35),
      ));
    }
    canvas.drawPath(path, paint);

    // Common Paint styles for face details
    // Using a dark slate color for high-contrast cute facial features
    const faceColor = Color(0xFF1E293B);

    final faceStrokePaint = Paint()
      ..color = faceColor
      ..strokeWidth = math.max(1.5, size.width * 0.045)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final faceFillPaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;

    // Cheeks Blush
    final blushColor = (level == SpendLevel.shocked) 
        ? const Color(0xFFEF4444).withOpacity(0.65) // Dark red blush
        : const Color(0xFFFF8B8B).withOpacity(0.55); // Standard soft pink

    final blushPaint = Paint()
      ..color = blushColor
      ..style = PaintingStyle.fill;

    double cheekY = size.height * (level == SpendLevel.saver ? 0.65 : 0.56);
    canvas.drawCircle(Offset(size.width * 0.18, cheekY), size.width * 0.08, blushPaint);
    canvas.drawCircle(Offset(size.width * 0.82, cheekY), size.width * 0.08, blushPaint);

    // EYES
    if (level == SpendLevel.saver) {
      // Sleeping eyes (downwards arcs: ~ ~)
      final leftEye = Path()
        ..moveTo(size.width * 0.25, size.height * 0.52)
        ..quadraticBezierTo(size.width * 0.325, size.height * 0.58, size.width * 0.4, size.height * 0.52);
      final rightEye = Path()
        ..moveTo(size.width * 0.60, size.height * 0.52)
        ..quadraticBezierTo(size.width * 0.675, size.height * 0.58, size.width * 0.75, size.height * 0.52);
      canvas.drawPath(leftEye, faceStrokePaint);
      canvas.drawPath(rightEye, faceStrokePaint);
    } 
    else if (level == SpendLevel.happy) {
      // Happy eyes (upwards arches: ^ ^)
      final leftEye = Path()
        ..moveTo(size.width * 0.25, size.height * 0.48)
        ..quadraticBezierTo(size.width * 0.325, size.height * 0.39, size.width * 0.4, size.height * 0.48);
      final rightEye = Path()
        ..moveTo(size.width * 0.60, size.height * 0.48)
        ..quadraticBezierTo(size.width * 0.675, size.height * 0.39, size.width * 0.75, size.height * 0.48);
      canvas.drawPath(leftEye, faceStrokePaint);
      canvas.drawPath(rightEye, faceStrokePaint);
    } 
    else if (level == SpendLevel.neutral) {
      // Simple circular dots
      canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.46), size.width * 0.05, faceFillPaint);
      canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.46), size.width * 0.05, faceFillPaint);
    } 
    else if (level == SpendLevel.shocked) {
      // Large white circles with small black pupils
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final eyeOutlinePaint = Paint()
        ..color = faceColor
        ..strokeWidth = math.max(1.0, size.width * 0.03)
        ..style = PaintingStyle.stroke;

      double eyeRad = size.width * 0.12;
      double pupilRad = size.width * 0.04;

      canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.44), eyeRad, whitePaint);
      canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.44), eyeRad, eyeOutlinePaint);
      canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.44), pupilRad, faceFillPaint);

      canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.44), eyeRad, whitePaint);
      canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.44), eyeRad, eyeOutlinePaint);
      canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.44), pupilRad, faceFillPaint);
    }

    // MOUTH
    if (level == SpendLevel.saver) {
      // Little soft 'o' snore/pout
      final mouthPaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, size.width * 0.04);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.66), size.width * 0.045, mouthPaint);
    } 
    else if (level == SpendLevel.happy) {
      // Big open cute smile
      final mouthPath = Path()
        ..moveTo(size.width * 0.42, size.height * 0.53)
        ..quadraticBezierTo(size.width * 0.5, size.height * 0.67, size.width * 0.58, size.height * 0.53)
        ..close();
      canvas.drawPath(mouthPath, faceFillPaint);

      // Cute pink tongue
      final tonguePaint = Paint()
        ..color = const Color(0xFFFF6B8B)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.clipPath(mouthPath);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.62), size.width * 0.065, tonguePaint);
      canvas.restore();
    } 
    else if (level == SpendLevel.neutral) {
      // Neutral straight line
      canvas.drawLine(
        Offset(size.width * 0.43, size.height * 0.58),
        Offset(size.width * 0.57, size.height * 0.58),
        faceStrokePaint,
      );
    } 
    else if (level == SpendLevel.shocked) {
      // Downward wobbly/shocked curve
      final mouthPath = Path()
        ..moveTo(size.width * 0.40, size.height * 0.68)
        ..quadraticBezierTo(size.width * 0.5, size.height * 0.59, size.width * 0.60, size.height * 0.68);
      canvas.drawPath(mouthPath, faceStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
