import 'package:flutter/cupertino.dart';

class NormalizedPoint {
  final double x;
  final double y;
  final double z;

  const NormalizedPoint({
    required this.x,
    required this.y,
    required this.z,
  });
}

class FaceMetrics {
  // A. Symmetry Distance (Euclidean reflection)
  final double leftSymmetryDistance;
  final double rightSymmetryDistance;
  final double overallSymmetry; // A normalized symmetry score (0-100)
  
  // B. Golden Ratio Proportions
  final double horizontalGoldenRatio; // Total width to eye width ratio
  final double verticalUpperProportion; // Hairline to brow
  final double verticalMidProportion; // Brow to nose base
  final double verticalLowerProportion; // Nose base to chin
  
  // C. Five Eyes Rule
  final double fiveEyesRatio; // Inner corners distance to one eye width

  // D. Canthal Tilt
  final double leftCanthalTilt; // Degrees (positive = upward tilt)
  final double rightCanthalTilt;
  final double averageCanthalTilt;

  // E. Facial Thirds String Format
  final String facialThirdsRatio; // e.g., "1:1.1:0.9"

  // F. Lip Volume
  final double upperLipHeight;
  final double lowerLipHeight;
  final String lipVolumeRatio; // e.g., "1:1.6"

  // Previous general metrics
  final double faceProportion; // Face height to width ratio
  final List<NormalizedPoint> landmarks; // Topography points
  final Size imageSize;

  const FaceMetrics({
    required this.leftSymmetryDistance,
    required this.rightSymmetryDistance,
    required this.overallSymmetry,
    required this.horizontalGoldenRatio,
    required this.verticalUpperProportion,
    required this.verticalMidProportion,
    required this.verticalLowerProportion,
    required this.fiveEyesRatio,
    required this.leftCanthalTilt,
    required this.rightCanthalTilt,
    required this.averageCanthalTilt,
    required this.facialThirdsRatio,
    required this.upperLipHeight,
    required this.lowerLipHeight,
    required this.lipVolumeRatio,
    required this.faceProportion,
    required this.landmarks,
    required this.imageSize,
  });
}
