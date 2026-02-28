import 'dart:typed_data';
import 'dart:ui';

/// Author: Ian Wilkey and Barney Jin
final class FaceMesh {
  final int             imageWidth;
  final int             imageHeight;
  final Uint8List       bgraPixels;
  final int             bytesPerRow;
  final List<Offset>    points;
  final List<List<int>> triangleIndices;
  final double          score;
  const FaceMesh({
    required this.imageWidth,
    required this.imageHeight,
    required this.bgraPixels,
    required this.bytesPerRow,
    required this.points,
    required this.triangleIndices,
    required this.score,
  });
}
