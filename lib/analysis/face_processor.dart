import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show applyBoxFit, FittedSizes, BoxFit;
import 'package:flutter/material.dart' show ImageStreamListener, ImageInfo, ImageConfiguration, FileImage, Alignment;
import 'dart:ui' as ui show Image, ImageByteFormat;
import 'dart:ui' show Offset, Size, Rect;
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';
import 'face_metrics.dart';

class FaceProcessor {
  /// Processes a list of 468 landmarks and calculates advanced facial metrics.
  /// Accepts native `Offset` objects directly mapped from an offline dataset or UI geometry.
  ///
  /// [imageSize] — when provided, all points are normalized to a fixed 1000×1000
  /// canonical space using the same BoxFit.contain mapping as [FaceMeshRenderable],
  /// eliminating variance from different camera resolutions or face distances.
  static FaceMetrics? processLandmarks(List<Offset> landmarks, {Size? imageSize}) {
    if (landmarks.isEmpty || landmarks.length < 468) {
      debugPrint('Expected at least 468 landmarks, got ${landmarks.length}.');
      return null;
    }

    // Normalize to a fixed canonical coordinate space so metrics are
    // consistent regardless of camera resolution or face distance.
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      const Size canonical = Size(1000, 1000);
      final FittedSizes f = applyBoxFit(BoxFit.contain, imageSize, canonical);
      final Rect src = Alignment.center.inscribe(f.source, Offset.zero & imageSize);
      final Rect dst = Alignment.center.inscribe(f.destination, Offset.zero & canonical);
      final double sx = dst.width / src.width;
      final double sy = dst.height / src.height;
      landmarks = landmarks.map((Offset p) => Offset(
        (p.dx - src.left) * sx + dst.left,
        (p.dy - src.top) * sy + dst.top,
      )).toList(growable: false);
    }

    // Helper to print exact pixel locations
    void printPoint(String name, Offset p) {
      debugPrint('$name: (${p.dx.toStringAsFixed(1)}, ${p.dy.toStringAsFixed(1)})');
    }

    // --- Key MediaPipe Face Mesh Indices ---
    // Midline: Nose Bridge (5), Chin (152), Hairline (10)
    final midlinePoint = landmarks[5]; 
    final chin = landmarks[152];
    final hairline = landmarks[10];

    // Eyes
    final leftEyeOuter = landmarks[33];
    final rightEyeOuter = landmarks[263];
    final leftEyeInner = landmarks[133];
    final rightEyeInner = landmarks[362];

    // Vertical sections: Brow (9), Nose Base (2)
    final brow = landmarks[9];
    final noseBase = landmarks[2];

    // Face Outlines for width
    final faceLeft = landmarks[234];
    final faceRight = landmarks[454];

    // Lips
    final upperLipTop = landmarks[0];
    final upperLipBottom = landmarks[13];
    final lowerLipTop = landmarks[14];
    final lowerLipBottom = landmarks[17];

    printPoint('Midline/Nose Bridge (5)', midlinePoint);
    printPoint('Left Eye Outer (33)', leftEyeOuter);
    printPoint('Right Eye Outer (263)', rightEyeOuter);
    printPoint('Chin (152)', chin);
    printPoint('Left Face Outline (234)', faceLeft);
    printPoint('Right Face Outline (454)', faceRight);
    debugPrint('--------------------------------------');

    // --- Distance Helper ---
    double distance(Offset p1, Offset p2) {
      return (p1 - p2).distance;
    }

    // ==========================================
    // A. Facial Symmetry (Reflection Euclidean)
    // d = sqrt((x_L - ~x_R)² + (y_L - y_R)²)
    // ==========================================
    // Assume vertical midline roughly passes through nose bridge (5)
    final midlineX = midlinePoint.dx;
    // faceWidth needed early for symmetry normalization
    final faceWidth = distance(faceLeft, faceRight);

    // Reflect right point across the midline
    final reflectedRightEyeOuterX = 2 * midlineX - rightEyeOuter.dx;

    // We can use Offset(x,y) to calculate the distance to the reflection point
    final reflectionPoint = Offset(reflectedRightEyeOuterX, rightEyeOuter.dy);
    final symmetryDistance = (leftEyeOuter - reflectionPoint).distance;

    // Score from 0-100: normalize distance by face width so the result is
    // scale-invariant regardless of canonical space resolution.
    // d/faceWidth ≈ 0 for perfect symmetry; ×2 gives a sensitivity factor
    // so that 50% misalignment relative to face width = 0 score.
    final normalizedSymD = (faceWidth > 0) ? symmetryDistance / faceWidth : 0.0;
    final overallSymmetryScore = clampDouble(100.0 * (1.0 - normalizedSymD * 4), 0, 100);

    // ==========================================
    // B. The Golden Ratio 
    // ==========================================
    final faceHeight = distance(hairline, chin);
    
    // Horizontal: Face Width : Total Eye span + spacing
    final eyeToEyeSpan = distance(leftEyeOuter, rightEyeOuter);
    final horizontalGoldenRatio = (eyeToEyeSpan > 0) ? (faceWidth / eyeToEyeSpan) : 0.0;
    
    // Vertical: 1:1:1 rule 
    final upperSection = distance(hairline, brow);
    final midSection = distance(brow, noseBase);
    final lowerSection = distance(noseBase, chin);

    final totalVerticalSections = upperSection + midSection + lowerSection;
    final verticalUpperProportion = (totalVerticalSections > 0) ? upperSection / totalVerticalSections : 0.0;
    final verticalMidProportion = (totalVerticalSections > 0) ? midSection / totalVerticalSections : 0.0;
    final verticalLowerProportion = (totalVerticalSections > 0) ? lowerSection / totalVerticalSections : 0.0;

    // ==========================================
    // C. The "Five Eyes" Rule
    // ==========================================
    // Average both eye widths to avoid asymmetry bias from using one eye alone.
    final innerEyeDistance = distance(leftEyeInner, rightEyeInner);
    final leftEyeWidth  = distance(leftEyeOuter, leftEyeInner);
    final rightEyeWidth = distance(rightEyeOuter, rightEyeInner);
    final oneEyeWidth   = (leftEyeWidth + rightEyeWidth) / 2;
    final fiveEyesRatio = (oneEyeWidth > 0) ? innerEyeDistance / oneEyeWidth : 0.0;

    // ==========================================
    // D. Canthal Tilt
    // ==========================================
    double calculateTilt(Offset inner, Offset outer) {
      final dy = inner.dy - outer.dy; // Positive if outer corner is higher
      final dx = (outer.dx - inner.dx).abs(); 
      return dx > 0 ? atan2(dy, dx) * 180 / pi : 0.0;
    }
    final leftCanthalTilt = calculateTilt(leftEyeInner, leftEyeOuter);
    final rightCanthalTilt = calculateTilt(rightEyeInner, rightEyeOuter);
    final averageCanthalTilt = (leftCanthalTilt + rightCanthalTilt) / 2;

    // ==========================================
    // E. Facial Thirds String Format
    // ==========================================
    // Normalize each section to the total face height (true thirds representation).
    // Ideal: each section is 1/3 of total, so each proportion ≈ 0.333.
    // Display as N:N:N where each N = section/min(sections) for easy comparison.
    final minSection = [upperSection, midSection, lowerSection].reduce(min);
    final thirdsBase = minSection > 0 ? minSection : 1.0;
    final String facialThirdsRatio =
      "${(upperSection / thirdsBase).toStringAsFixed(1)}:"
      "${(midSection  / thirdsBase).toStringAsFixed(1)}:"
      "${(lowerSection/ thirdsBase).toStringAsFixed(1)}";

    // ==========================================
    // F. Lip Volume
    // ==========================================
    final upperLipHeight = distance(upperLipTop, upperLipBottom);
    final lowerLipHeight = distance(lowerLipTop, lowerLipBottom);
    final lipRatioValue = upperLipHeight > 0 ? lowerLipHeight / upperLipHeight : 0.0;
    final lipVolumeRatio = "1:${lipRatioValue.toStringAsFixed(1)}";

    // Previous standard proportion
    final proportion = faceWidth == 0 ? 0.0 : faceHeight / faceWidth;

    // Since we are decoupling the math engine from the raw Image upload size constraint,
    // we use a generic bounding boundary width for `imageSize` properties
    final double boundingWidth = distance(faceLeft, faceRight) * 1.5; 
    final double boundingHeight = distance(hairline, chin) * 1.5;
    
    // Create NormalizedPoint variants exactly mapping what FaceMetrics needs format-wise
    final normalizedLandmarks = landmarks.map((offset) => NormalizedPoint(
      x: offset.dx / boundingWidth, 
      y: offset.dy / boundingHeight, 
      z: 0.0
    )).toList();

    return FaceMetrics(
      leftSymmetryDistance: distance(leftEyeOuter, midlinePoint),
      rightSymmetryDistance: distance(rightEyeOuter, midlinePoint),
      overallSymmetry: overallSymmetryScore,
      horizontalGoldenRatio: horizontalGoldenRatio,
      verticalUpperProportion: verticalUpperProportion,
      verticalMidProportion: verticalMidProportion,
      verticalLowerProportion: verticalLowerProportion,
      fiveEyesRatio: fiveEyesRatio,
      leftCanthalTilt: leftCanthalTilt,
      rightCanthalTilt: rightCanthalTilt,
      averageCanthalTilt: averageCanthalTilt,
      facialThirdsRatio: facialThirdsRatio,
      upperLipHeight: upperLipHeight,
      lowerLipHeight: lowerLipHeight,
      lipVolumeRatio: lipVolumeRatio,
      faceProportion: proportion,
      landmarks: normalizedLandmarks,
      imageSize: Size(boundingWidth, boundingHeight),
    );
  }

  /// Processes a real image file using MediaPipe Face Mesh FFI.
  static Future<FaceMetrics?> processImage(String imagePath) async {
    // If we're on macOS desktop, fall back to our mock visualization so the UI doesn't crash.
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      debugPrint('MediaPipe Face Mesh not supported on Desktop natively. Falling back to mock data...');
      return mockProcessImage();
    }

    try {
      // 1. Decode the File into a native UI Image
      final Completer<ui.Image> completer = Completer();
      final FileImage provider = FileImage(File(imagePath));
      provider.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          completer.complete(info.image);
        }),
      );
      final ui.Image image = await completer.future;

      // 2. Extract RAW RGBA Pixels for the C++ bindings
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        debugPrint('Failed to extract RGBA pixel buffer.');
        return null;
      }
      final Uint8List pixels = byteData.buffer.asUint8List();

      // 3. Mount native MediaPipe SDK
      final FaceMeshProcessor processor = await FaceMeshProcessor.create();
      
      final FaceMeshImage mpImage = FaceMeshImage(
        pixels: pixels,
        width: image.width,
        height: image.height,
      );

      // 4. Run C++ inference engine
      final FaceMeshResult result = processor.process(mpImage);
      processor.close(); // Clean up native memory
      
      if (result.landmarks.isEmpty) {
        debugPrint('No faces detected in the image.');
        return null;
      }

      // Convert MediaPipe standardized [0, 1] points back into physical absolute Image pixel Offset objects
      // so we can feed it mathematically clean coordinates that perfectly replicate an offline dataset format.
      List<Offset> physicalOffsets = result.landmarks.map((lm) {
        return Offset(
          lm.x * image.width, 
          lm.y * image.height
        );
      }).toList();

      return processLandmarks(
        physicalOffsets,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      );
    } catch (e) {
      debugPrint('Error detecting face meshes: $e');
      return null;
    }
  }

  /// Processes an image frame to return FaceMetrics. (Simulated for UI mocking on Desktop)
  static Future<FaceMetrics?> mockProcessImage() async {
    // Generate 478 simulated points in a balanced arrangement 
    // We mock these directly into Offset representations mapping to a faux 1000x1000 px screen
    final random = Random();
    List<Offset> simulatedOffsets = List.generate(478, (index) {
      return Offset(
        500.0 + (random.nextDouble() - 0.5) * 400.0,
        500.0 + (random.nextDouble() - 0.5) * 400.0,
      );
    });

    // Manually force the key landmark indices into a generic "face" shape
    // Midline
    simulatedOffsets[5] = const Offset(500, 500); // Nose bridge
    simulatedOffsets[10]= const Offset(500, 200); // Hairline
    simulatedOffsets[152]=const Offset(500, 850); // Chin
    
    // Eyes (Add imperfect symmetry on Right Eye y-axis)
    simulatedOffsets[33] = const Offset(350, 450); // Left outer
    simulatedOffsets[133]= const Offset(430, 460); // Left inner
    simulatedOffsets[263]= const Offset(650, 460); // Right outer
    simulatedOffsets[362]= const Offset(570, 450); // Right inner
    
    // Middle segments
    simulatedOffsets[9] = const Offset(500, 380); // Brow
    simulatedOffsets[2] = const Offset(500, 600); // Nose base

    // Sidelines
    simulatedOffsets[234]= const Offset(250, 500); // Left face outline
    simulatedOffsets[454]= const Offset(750, 500); // Right face outline

    // Introduce a short artificial delay to simulate ML processing
    await Future.delayed(const Duration(milliseconds: 1500));
    return processLandmarks(simulatedOffsets);
  }
}
