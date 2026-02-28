import 'package:flutter/cupertino.dart';

/// Author: Barney Jin and Ian Wilkey
final class NormalizedPoint {
  final double x;
  final double y;
  final double z;
  const NormalizedPoint({
    required this.x,
    required this.y,
    required this.z,
  });
}

/// Author: Barney Jin and Ian Wilkey
final class FaceMetrics {
  final double leftSymmetryDistance;
  final double rightSymmetryDistance;
  final double overallSymmetry;
  final double horizontalGoldenRatio;
  final double verticalUpperProportion;
  final double verticalMidProportion;
  final double verticalLowerProportion;
  final double fiveEyesRatio;
  final double leftCanthalTilt;
  final double rightCanthalTilt;
  final double averageCanthalTilt;
  final String facialThirdsRatio;
  final double upperLipHeight;
  final double lowerLipHeight;
  final String lipVolumeRatio;
  final double faceProportion;
  final List<NormalizedPoint> landmarks;
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
