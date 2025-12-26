import 'package:flutter/material.dart';

/// Custom Camera AI Icon painter - accurately traces the SVG design
/// Features: Camera body with viewfinder bump, lens circle, and AI sparkle
class CameraAIIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  CameraAIIconPainter({
    this.color = Colors.white,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Scale factor to normalize the icon to the given size
    final scale = size.width / 24;

    canvas.save();
    canvas.scale(scale, scale);

    // ========================================
    // CAMERA BODY - Main outline
    // ========================================
    final cameraPath = Path();
    
    // Start from the left side top, going around the body
    // Left side
    cameraPath.moveTo(2.75, 11.5);
    cameraPath.lineTo(2.75, 13.5);
    
    // Bottom left corner (rounded)
    cameraPath.quadraticBezierTo(2.75, 17.5, 5.5, 19.5);
    cameraPath.quadraticBezierTo(7, 20.25, 9.5, 20.25);
    
    // Bottom edge
    cameraPath.lineTo(14.5, 20.25);
    
    // Bottom right corner (rounded)
    cameraPath.quadraticBezierTo(17, 20.25, 18.5, 19.5);
    cameraPath.quadraticBezierTo(21.25, 17.5, 21.25, 13.5);
    
    // Right side
    cameraPath.lineTo(21.25, 11.5);
    
    // Top right corner (rounded)
    cameraPath.quadraticBezierTo(21.25, 9, 19.5, 7.5);
    cameraPath.quadraticBezierTo(18, 6.25, 16.5, 6.25);
    
    // Top edge to viewfinder bump
    cameraPath.lineTo(16, 6.25);
    
    // Viewfinder bump (trapezoid shape on top)
    cameraPath.lineTo(15, 4.5);
    cameraPath.quadraticBezierTo(14.5, 3.75, 13.5, 3.75);
    cameraPath.lineTo(10.5, 3.75);
    cameraPath.quadraticBezierTo(9.5, 3.75, 9, 4.5);
    cameraPath.lineTo(8, 6.25);
    
    // Continue top edge
    cameraPath.lineTo(7.5, 6.25);
    
    // Top left corner (rounded)
    cameraPath.quadraticBezierTo(6, 6.25, 4.5, 7.5);
    cameraPath.quadraticBezierTo(2.75, 9, 2.75, 11.5);

    canvas.drawPath(cameraPath, paint);

    // ========================================
    // CAMERA LENS - Circle in center
    // ========================================
    canvas.drawCircle(const Offset(12, 13), 4, paint);

    // ========================================
    // AI SPARKLE - 4-pointed star (top right)
    // ========================================
    _drawSparkle(canvas, paint, 18.0, 6.0, 3.0);

    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Paint paint, double x, double y, double size) {
    final sparklePath = Path();
    
    // Create a smooth 4-pointed star shape
    // Top point
    sparklePath.moveTo(x, y - size);
    
    // Curve to right point
    sparklePath.cubicTo(
      x + size * 0.15, y - size * 0.15,
      x + size * 0.85, y - size * 0.15,
      x + size, y,
    );
    
    // Curve to bottom point
    sparklePath.cubicTo(
      x + size * 0.15, y + size * 0.15,
      x + size * 0.15, y + size * 0.85,
      x, y + size,
    );
    
    // Curve to left point
    sparklePath.cubicTo(
      x - size * 0.15, y + size * 0.15,
      x - size * 0.85, y + size * 0.15,
      x - size, y,
    );
    
    // Curve back to top point
    sparklePath.cubicTo(
      x - size * 0.15, y - size * 0.15,
      x - size * 0.15, y - size * 0.85,
      x, y - size,
    );

    canvas.drawPath(sparklePath, paint);
  }

  @override
  bool shouldRepaint(covariant CameraAIIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Camera AI Icon Widget - Outline style
class CameraAIIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CameraAIIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: CameraAIIconPainter(
        color: color,
        strokeWidth: size / 16,
      ),
    );
  }
}

/// Filled Camera AI Icon for active/pressed states
class CameraAIIconFilled extends StatelessWidget {
  final double size;
  final Color color;

  const CameraAIIconFilled({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CameraAIFilledPainter(
        color: color,
        strokeWidth: size / 16,
      ),
    );
  }
}

class _CameraAIFilledPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CameraAIFilledPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scale = size.width / 24;

    canvas.save();
    canvas.scale(scale, scale);

    // ========================================
    // CAMERA BODY - Filled
    // ========================================
    final cameraPath = Path();
    
    // Create closed camera body shape
    cameraPath.moveTo(2.75, 11.5);
    cameraPath.lineTo(2.75, 13.5);
    cameraPath.quadraticBezierTo(2.75, 17.5, 5.5, 19.5);
    cameraPath.quadraticBezierTo(7, 20.25, 9.5, 20.25);
    cameraPath.lineTo(14.5, 20.25);
    cameraPath.quadraticBezierTo(17, 20.25, 18.5, 19.5);
    cameraPath.quadraticBezierTo(21.25, 17.5, 21.25, 13.5);
    cameraPath.lineTo(21.25, 11.5);
    cameraPath.quadraticBezierTo(21.25, 9, 19.5, 7.5);
    cameraPath.quadraticBezierTo(18, 6.25, 16.5, 6.25);
    cameraPath.lineTo(16, 6.25);
    cameraPath.lineTo(15, 4.5);
    cameraPath.quadraticBezierTo(14.5, 3.75, 13.5, 3.75);
    cameraPath.lineTo(10.5, 3.75);
    cameraPath.quadraticBezierTo(9.5, 3.75, 9, 4.5);
    cameraPath.lineTo(8, 6.25);
    cameraPath.lineTo(7.5, 6.25);
    cameraPath.quadraticBezierTo(6, 6.25, 4.5, 7.5);
    cameraPath.quadraticBezierTo(2.75, 9, 2.75, 11.5);
    cameraPath.close();

    canvas.drawPath(cameraPath, fillPaint);

    // ========================================
    // LENS - Cutout effect
    // ========================================
    final lensPaint = Paint()
      ..color = color == Colors.white ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(12, 13), 4, lensPaint);

    // Inner lens (colored)
    final innerLensPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(12, 13), 2.5, innerLensPaint);

    // ========================================
    // AI SPARKLE - Filled
    // ========================================
    _drawFilledSparkle(
      canvas, 
      color == Colors.white ? Colors.black : Colors.white,
      18.0, 
      6.0, 
      2.5,
    );

    canvas.restore();
  }

  void _drawFilledSparkle(Canvas canvas, Color sparkleColor, double x, double y, double size) {
    final sparklePath = Path();
    final sparklePaint = Paint()
      ..color = sparkleColor
      ..style = PaintingStyle.fill;
    
    // Create smooth 4-pointed star
    sparklePath.moveTo(x, y - size);
    sparklePath.cubicTo(
      x + size * 0.1, y - size * 0.1,
      x + size * 0.9, y - size * 0.1,
      x + size, y,
    );
    sparklePath.cubicTo(
      x + size * 0.1, y + size * 0.1,
      x + size * 0.1, y + size * 0.9,
      x, y + size,
    );
    sparklePath.cubicTo(
      x - size * 0.1, y + size * 0.1,
      x - size * 0.9, y + size * 0.1,
      x - size, y,
    );
    sparklePath.cubicTo(
      x - size * 0.1, y - size * 0.1,
      x - size * 0.1, y - size * 0.9,
      x, y - size,
    );
    sparklePath.close();

    canvas.drawPath(sparklePath, sparklePaint);
  }

  @override
  bool shouldRepaint(covariant _CameraAIFilledPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
