import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomIcons {
  static Widget search({double size = 20, Color color = Colors.black}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: SearchIconPainter(color: color)),
    );
  }

  static Widget bag({double size = 20, Color color = Colors.black}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: BagIconPainter(color: color)),
    );
  }

  static Widget heart({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: HeartIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget home({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: HomeIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget explore({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ExploreIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget hanger({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: HangerIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget profile({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ProfileIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget settings({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SettingsIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget shirt({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ShirtIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget pants({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PantsIconPainter(color: color, filled: filled),
      ),
    );
  }

  static Widget skincare({
    double size = 20,
    Color color = Colors.black,
    bool filled = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SkincareIconPainter(color: color, filled: filled),
      ),
    );
  }
}

class SearchIconPainter extends CustomPainter {
  final Color color;

  SearchIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.4, size.height * 0.4);
    final radius = size.width * 0.3;

    canvas.drawCircle(center, radius, paint);

    final lineStart = Offset(size.width * 0.62, size.height * 0.62);
    final lineEnd = Offset(size.width * 0.85, size.height * 0.85);
    canvas.drawLine(lineStart, lineEnd, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BagIconPainter extends CustomPainter {
  final Color color;

  BagIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.3);
    path.lineTo(size.width * 0.15, size.height * 0.9);
    path.lineTo(size.width * 0.85, size.height * 0.9);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.close();

    canvas.drawPath(path, paint);

    final handlePath = Path();
    handlePath.moveTo(size.width * 0.35, size.height * 0.3);
    handlePath.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.15,
      size.width * 0.5,
      size.height * 0.15,
    );
    handlePath.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.15,
      size.width * 0.65,
      size.height * 0.3,
    );

    canvas.drawPath(handlePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HeartIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  HeartIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.85);

    path.cubicTo(
      size.width * 0.2,
      size.height * 0.6,
      size.width * 0.1,
      size.height * 0.3,
      size.width * 0.3,
      size.height * 0.2,
    );

    path.cubicTo(
      size.width * 0.4,
      size.height * 0.15,
      size.width * 0.5,
      size.height * 0.25,
      size.width * 0.5,
      size.height * 0.35,
    );

    path.cubicTo(
      size.width * 0.5,
      size.height * 0.25,
      size.width * 0.6,
      size.height * 0.15,
      size.width * 0.7,
      size.height * 0.2,
    );

    path.cubicTo(
      size.width * 0.9,
      size.height * 0.3,
      size.width * 0.8,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.85,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  HomeIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.88, size.height * 0.48);
    path.lineTo(size.width * 0.88, size.height * 0.88);
    path.lineTo(size.width * 0.12, size.height * 0.88);
    path.lineTo(size.width * 0.12, size.height * 0.48);
    path.close();

    canvas.drawPath(path, paint);

    if (!filled) {
      final doorPath = Path();
      doorPath.moveTo(size.width * 0.4, size.height * 0.88);
      doorPath.lineTo(size.width * 0.4, size.height * 0.6);
      doorPath.lineTo(size.width * 0.6, size.height * 0.6);
      doorPath.lineTo(size.width * 0.6, size.height * 0.88);
      canvas.drawPath(doorPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ExploreIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  ExploreIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.35;

    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);

    final compassPath = Path();
    compassPath.moveTo(size.width * 0.5, size.height * 0.3);
    compassPath.lineTo(size.width * 0.6, size.height * 0.5);
    compassPath.lineTo(size.width * 0.5, size.height * 0.7);
    compassPath.lineTo(size.width * 0.4, size.height * 0.5);
    compassPath.close();

    if (filled) {
      final compassPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(compassPath, compassPaint);
    } else {
      canvas.drawPath(compassPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HangerIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  HangerIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (filled) {
      paint.style = PaintingStyle.fill;

      // Create elegant curved hook
      final hookPath = Path();
      hookPath.moveTo(size.width * 0.5, size.height * 0.12);
      hookPath.cubicTo(
        size.width * 0.40,
        size.height * 0.12,
        size.width * 0.35,
        size.height * 0.17,
        size.width * 0.35,
        size.height * 0.25,
      );
      hookPath.cubicTo(
        size.width * 0.35,
        size.height * 0.33,
        size.width * 0.40,
        size.height * 0.38,
        size.width * 0.5,
        size.height * 0.38,
      );
      canvas.drawPath(hookPath, paint);

      // Create filled hanger body with smooth curves
      final hangerPath = Path();
      // Start from hook bottom
      hangerPath.moveTo(size.width * 0.5, size.height * 0.38);
      // Left diagonal to shoulder
      hangerPath.lineTo(size.width * 0.12, size.height * 0.62);
      // Left bar bottom
      hangerPath.lineTo(size.width * 0.12, size.height * 0.72);
      // Bottom bar to right
      hangerPath.lineTo(size.width * 0.88, size.height * 0.72);
      // Right bar top
      hangerPath.lineTo(size.width * 0.88, size.height * 0.62);
      // Right diagonal back to hook
      hangerPath.close();

      canvas.drawPath(hangerPath, paint);
    } else {
      paint.style = PaintingStyle.stroke;

      // Elegant hook outline
      final hookPath = Path();
      hookPath.moveTo(size.width * 0.5, size.height * 0.12);
      hookPath.cubicTo(
        size.width * 0.40,
        size.height * 0.12,
        size.width * 0.35,
        size.height * 0.17,
        size.width * 0.35,
        size.height * 0.25,
      );
      hookPath.cubicTo(
        size.width * 0.35,
        size.height * 0.33,
        size.width * 0.40,
        size.height * 0.38,
        size.width * 0.5,
        size.height * 0.38,
      );

      canvas.drawPath(hookPath, paint);

      // Clean triangular hanger outline
      // Left diagonal
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.38),
        Offset(size.width * 0.12, size.height * 0.67),
        paint,
      );

      // Right diagonal
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.38),
        Offset(size.width * 0.88, size.height * 0.67),
        paint,
      );

      // Bottom bar
      canvas.drawLine(
        Offset(size.width * 0.12, size.height * 0.67),
        Offset(size.width * 0.88, size.height * 0.67),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfileIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  ProfileIconPainter({required this.color, this.filled = false});

  Path _buildBodyPath(Size size) {
    // Unified torso/shoulder silhouette
    final leftX = size.width * 0.22;
    final rightX = size.width * 0.78;
    final topY = size.height * 0.58; // shoulder line
    final bottomY = size.height * 0.88; // base line

    final path = Path();
    // Start bottom-left, go up to shoulder
    path.moveTo(leftX, bottomY);
    path.lineTo(leftX, topY);

    // Smooth shoulder arc across to the right
    path.quadraticBezierTo(
      size.width * 0.50,
      topY - size.height * 0.08, // arch apex
      rightX,
      topY,
    );

    // Down right side and close bottom
    path.lineTo(rightX, bottomY);
    path.lineTo(leftX, bottomY);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Head
    final headCenter = Offset(size.width * 0.5, size.height * 0.33);
    final headRadius = size.width * 0.17;

    // Body silhouette (shared between modes)
    final bodyPath = _buildBodyPath(size);

    if (filled) {
      // Fill head and body with same color
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(headCenter, headRadius, paint);
      canvas.drawPath(bodyPath, paint);
    } else {
      // Stroke head and the same body silhouette
      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(headCenter, headRadius, paint);
      canvas.drawPath(bodyPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SettingsIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  SettingsIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final outerR = size.width * 0.38;
    final baseR = size.width * 0.30;
    final innerR = size.width * 0.15;
    const teeth = 6;
    final step = 2 * math.pi / teeth;

    // Build gear outline with 6 teeth
    final gearPath = Path();
    for (int i = 0; i < teeth; i++) {
      final a = i * step;

      final p1 = Offset(
        center.dx + baseR * math.cos(a - step * 0.28),
        center.dy + baseR * math.sin(a - step * 0.28),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(a - step * 0.12),
        center.dy + outerR * math.sin(a - step * 0.12),
      );
      final p3 = Offset(
        center.dx + outerR * math.cos(a + step * 0.12),
        center.dy + outerR * math.sin(a + step * 0.12),
      );
      final p4 = Offset(
        center.dx + baseR * math.cos(a + step * 0.28),
        center.dy + baseR * math.sin(a + step * 0.28),
      );
      final nextP1 = Offset(
        center.dx + baseR * math.cos((i + 1) * step - step * 0.28),
        center.dy + baseR * math.sin((i + 1) * step - step * 0.28),
      );

      if (i == 0) gearPath.moveTo(p1.dx, p1.dy);
      gearPath
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..arcToPoint(nextP1, radius: Radius.circular(baseR), clockwise: true);
    }
    gearPath.close();

    if (filled) {
      paint.style = PaintingStyle.fill;
      canvas.drawPath(gearPath, paint);

      // Center hole
      final holePaint = Paint()..color = Colors.white;
      canvas.drawCircle(center, innerR, holePaint);

      // Outline the hole for clarity
      final ringPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawCircle(center, innerR, ringPaint);
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(gearPath, paint);
      canvas.drawCircle(center, innerR, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShirtIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  ShirtIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Left shoulder/sleeve
    path.moveTo(size.width * 0.15, size.height * 0.35);
    path.lineTo(size.width * 0.05, size.height * 0.50);
    path.lineTo(size.width * 0.15, size.height * 0.55);

    // Left body side
    path.lineTo(size.width * 0.25, size.height * 0.50);
    path.lineTo(size.width * 0.25, size.height * 0.85);

    // Bottom
    path.lineTo(size.width * 0.75, size.height * 0.85);

    // Right body side
    path.lineTo(size.width * 0.75, size.height * 0.50);
    path.lineTo(size.width * 0.85, size.height * 0.55);

    // Right shoulder/sleeve
    path.lineTo(size.width * 0.95, size.height * 0.50);
    path.lineTo(size.width * 0.85, size.height * 0.35);

    // Collar
    path.lineTo(size.width * 0.60, size.height * 0.25);
    path.lineTo(size.width * 0.60, size.height * 0.15);
    path.lineTo(size.width * 0.40, size.height * 0.15);
    path.lineTo(size.width * 0.40, size.height * 0.25);
    path.close();

    if (filled) {
      paint.style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PantsIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  PantsIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Waistband left
    path.moveTo(size.width * 0.20, size.height * 0.15);

    // Left leg outer
    path.lineTo(size.width * 0.15, size.height * 0.85);
    path.lineTo(size.width * 0.35, size.height * 0.85);

    // Left leg inner (crotch)
    path.lineTo(size.width * 0.42, size.height * 0.50);
    path.lineTo(size.width * 0.50, size.height * 0.35);

    // Right leg inner (crotch)
    path.lineTo(size.width * 0.58, size.height * 0.50);
    path.lineTo(size.width * 0.65, size.height * 0.85);

    // Right leg outer
    path.lineTo(size.width * 0.85, size.height * 0.85);
    path.lineTo(size.width * 0.80, size.height * 0.15);

    // Waistband
    path.close();

    if (filled) {
      paint.style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SkincareIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  SkincareIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bottle body
    final bodyPath = Path();

    // Main bottle body (rectangular with slight taper)
    bodyPath.moveTo(size.width * 0.35, size.height * 0.35);
    bodyPath.lineTo(size.width * 0.30, size.height * 0.85);
    bodyPath.lineTo(size.width * 0.70, size.height * 0.85);
    bodyPath.lineTo(size.width * 0.65, size.height * 0.35);
    bodyPath.close();

    // Neck/cap area
    final capPath = Path();
    capPath.moveTo(size.width * 0.40, size.height * 0.20);
    capPath.lineTo(size.width * 0.40, size.height * 0.35);
    capPath.lineTo(size.width * 0.60, size.height * 0.35);
    capPath.lineTo(size.width * 0.60, size.height * 0.20);

    // Top cap/pump
    capPath.moveTo(size.width * 0.42, size.height * 0.15);
    capPath.lineTo(size.width * 0.42, size.height * 0.20);
    capPath.lineTo(size.width * 0.58, size.height * 0.20);
    capPath.lineTo(size.width * 0.58, size.height * 0.15);
    capPath.close();

    if (filled) {
      paint.style = PaintingStyle.fill;
      canvas.drawPath(bodyPath, paint);
      canvas.drawPath(capPath, paint);
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(bodyPath, paint);
      canvas.drawPath(capPath, paint);

      // Add decorative detail line on bottle
      final detailPath = Path();
      detailPath.moveTo(size.width * 0.32, size.height * 0.55);
      detailPath.lineTo(size.width * 0.68, size.height * 0.55);
      canvas.drawPath(detailPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
