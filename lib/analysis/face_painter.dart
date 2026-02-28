import 'package:flutter/material.dart';
import 'face_metrics.dart';

class FaceMeshPainter extends CustomPainter {
  final FaceMetrics? metrics;
  final Size imageSize;

  // Aesthetic colors for a subtle, glowing mesh
  static const Color nodeColor = Color(0xFF00FFCC);
  static const Color glowColor = Color(0x6600FFCC);

  FaceMeshPainter({required this.metrics, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics == null || metrics!.landmarks.isEmpty) return;

    // Scale factors to map normalized [0, 1] points to the CustomPaint canvas size
    final double scaleX = size.width;
    final double scaleY = size.height;

    // Outer subtle glowing effect
    final Paint glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Inner bright core of the node
    final Paint nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Set of key indices we calculate metrics from
    final Set<int> keyIndices = {
      5, 152, 10,   // midline
      33, 263, 133, 362, // eyes
      9, 2, // vertical sections
      234, 454 // face width
    };

    final Paint keyPointPaint = Paint()
      ..color = Colors.pinkAccent
      ..style = PaintingStyle.fill;

    // Draw all 468 landmarks as elegant glowing dots to form a mesh-like scatter
    for (int i = 0; i < metrics!.landmarks.length; i++) {
      final point = metrics!.landmarks[i];
      final Offset offset = Offset(point.x * scaleX, point.y * scaleY);

      if (keyIndices.contains(i)) {
        // Draw primary math points very large and pink
        canvas.drawCircle(offset, 4.0, keyPointPaint);
      } else {
        // Draw the rest of the points distinctly but slightly smaller
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
