import 'package:flutter/material.dart';
import 'face_metrics.dart';

/// Author: Ian Wilkey and Barney Jin
final class FaceMeshPainter extends CustomPainter {

  static const Color nodeColor = Color(0xFF00FFCC);
  static const Color glowColor = Color(0x6600FFCC);

  final FaceMetrics? metrics;
  final Size imageSize;

  FaceMeshPainter({required this.metrics, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    if(metrics == null || metrics!.landmarks.isEmpty) return;
    final double scaleX = size.width;
    final double scaleY = size.height;
    final Paint glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final Paint nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Set<int> keyIndices = {
      5, 152, 10,
      33, 263, 133, 362,
      9, 2,
      234, 454
    };
    final Paint keyPointPaint = Paint()
      ..color = Colors.pinkAccent
      ..style = PaintingStyle.fill;
    for(int i = 0; i < metrics!.landmarks.length; i++) {
      final point = metrics!.landmarks[i];
      final Offset offset = Offset(point.x * scaleX, point.y * scaleY);
      if(keyIndices.contains(i)) {
        canvas.drawCircle(offset, 4.0, keyPointPaint);
      } else {
        canvas.drawCircle(offset, 2.5, glowPaint);
        canvas.drawCircle(offset, 1.0, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceMeshPainter oldDelegate) {
    return oldDelegate.metrics != metrics || oldDelegate.imageSize != imageSize;
  }

}
