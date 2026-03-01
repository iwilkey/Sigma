import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sigma/analysis/face_metrics.dart';

/// Author: Ian Wilkey and Barney Jin
///
/// Computes an S / A / B / C harmony tier from a [FaceMetrics] snapshot.
///
/// Each of the 5 metrics contributes 0–20 points (total max = 100).
/// ─────────────────────────────────────────────────────────────────
/// Metric          Formula
/// ─────────────────────────────────────────────────────────────────
/// Symmetry        linear  60% → 0 pts,  100% → 20 pts
/// Canthal Tilt    Gaussian peak at +4°, σ²=18  →  20 × e^(-(t-4)²/18)
/// Golden Ratio    20 − |φ - 1.618| × 80,  clamped [0,20]
/// Facial Thirds   20 − variance([up,mid,lo]) × 200,  clamped [0,20]
/// Lip Volume      20 − |ratio - 1.6| × 25,  clamped [0,20]
///                 ratio = lowerLipHeight / upperLipHeight
/// ─────────────────────────────────────────────────────────────────
/// Tier thresholds:  S ≥ 82   A ≥ 68   B ≥ 52   C < 52

enum FaceTier { s, a, b, c }

extension FaceTierLabel on FaceTier {
  String get letter => switch (this) {
    FaceTier.s => 'S',
    FaceTier.a => 'A',
    FaceTier.b => 'B',
    FaceTier.c => 'C',
  };

  String get headline => switch (this) {
    FaceTier.s => 'Sigma',
    FaceTier.a => 'Absolutely Gorgeous',
    FaceTier.b => 'Balanced Features',
    FaceTier.c => 'Distinctive Character',
  };

  String get subtitle => switch (this) {
    FaceTier.s => 'Top-tier across every proportion metric.',
    FaceTier.a => 'Above average on most harmony dimensions.',
    FaceTier.b => 'Well-balanced; most faces fall here.',
    FaceTier.c => 'Unique proportions with expressive character.',
  };

  Color get color => switch (this) {
        FaceTier.s => const Color(0xFFFFD700),
        FaceTier.a => const Color(0xFF00FFCC),
        FaceTier.b => const Color(0xFF6E9EFF),
        FaceTier.c => const Color(0xFFAAAAAA),
      };
}

final class FaceTierResult {
  final FaceTier tier;
  final double totalScore;          // 0–100
  final double symmetryScore;       // 0–20
  final double canthalScore;        // 0–20
  final double goldenScore;         // 0–20
  final double thirdsScore;         // 0–20
  final double lipScore;            // 0–20
  const FaceTierResult({
    required this.tier,
    required this.totalScore,
    required this.symmetryScore,
    required this.canthalScore,
    required this.goldenScore,
    required this.thirdsScore,
    required this.lipScore,
  });
}

abstract final class FaceTierCalculator {
  FaceTierCalculator._();
  static FaceTierResult compute(FaceMetrics m) {
    final double sym    = _symmetryScore(m.overallSymmetry);
    final double cant   = _canthalScore(m.averageCanthalTilt);
    final double golden = _goldenScore(m.horizontalGoldenRatio);
    final double thirds = _thirdsScore(m.verticalUpperProportion, m.verticalMidProportion, m.verticalLowerProportion);
    final double lip    = _lipScore(m.upperLipHeight, m.lowerLipHeight);
    final double total  = sym + cant + golden + thirds + lip;
    final FaceTier tier = total >= 82
        ? FaceTier.s
        : total >= 68
            ? FaceTier.a
            : total >= 52
                ? FaceTier.b
                : FaceTier.c;
    return FaceTierResult(
      tier: tier,
      totalScore: total,
      symmetryScore: sym,
      canthalScore: cant,
      goldenScore: golden,
      thirdsScore: thirds,
      lipScore: lip,
    );
  }

  static double _symmetryScore(double pct) => ((pct - 60.0) / 40.0 * 20.0).clamp(0.0, 20.0);

  static double _canthalScore(double tilt) {
    final double exponent = -(tilt - 4.0) * (tilt - 4.0) / 18.0;
    return (20.0 * math.exp(exponent)).clamp(0.0, 20.0);
  }

  static double _goldenScore(double ratio) => (20.0 - (ratio - 1.618).abs() * 70.0).clamp(0.0, 20.0);

  static double _thirdsScore(double upper, double mid, double lower) {
    final double mean = (upper + mid + lower) / 3.0;
    final double variance =
        ((upper - mean) * (upper - mean) +
         (mid - mean) * (mid - mean) +
         (lower - mean) * (lower - mean)) /
        3.0;
    return (20.0 - variance * 200.0).clamp(0.0, 20.0);
  }

  static double _lipScore(double upperH, double lowerH) {
    if(upperH <= 0) return 10.0; // guard
    final double ratio = lowerH / upperH;
    return (20.0 - (ratio - 1.6).abs() * 25.0).clamp(0.0, 20.0);
  }

}
