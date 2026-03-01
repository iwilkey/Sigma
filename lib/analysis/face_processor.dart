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

/// Author: Barney Jin and Ian Wilkey
final class FaceProcessor {

  static FaceMetrics? processLandmarks(List<Offset> landmarks, {Size? imageSize}) {
    if(landmarks.isEmpty || landmarks.length < 468) {
      debugPrint('Expected at least 468 landmarks, got ${landmarks.length}.');
      return null;
    }
    if(imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
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
    final Offset midlinePoint = landmarks[5]; 
    final Offset chin = landmarks[152];
    final Offset hairline = landmarks[10];
    final Offset leftEyeOuter = landmarks[33];
    final Offset rightEyeOuter = landmarks[263];
    final Offset leftEyeInner = landmarks[133];
    final Offset rightEyeInner = landmarks[362];
    final Offset brow = landmarks[168];               // nasion (between eyebrows)
    final Offset noseBase = landmarks[164];           // subnasale (standard nose base)
    final Offset faceLeft = landmarks[234];
    final Offset faceRight = landmarks[454];
    final Offset upperLipTop = landmarks[0];
    final Offset upperLipBottom = landmarks[13];
    final Offset lowerLipTop = landmarks[14];
    final Offset lowerLipBottom = landmarks[17];
    double distance(Offset p1, Offset p2) {
      return (p1 - p2).distance;
    }
    final double midlineX = midlinePoint.dx;
    final double faceWidth = distance(faceLeft, faceRight);
    final double reflectedRightEyeOuterX = 2 * midlineX - rightEyeOuter.dx;
    final Offset reflectionPoint = Offset(reflectedRightEyeOuterX, rightEyeOuter.dy);
    final double symmetryDistance = (leftEyeOuter - reflectionPoint).distance;
    final double normalizedSymD = (faceWidth > 0) ? symmetryDistance / faceWidth : 0.0;
    final double overallSymmetryScore = clampDouble(100.0 * (1.0 - normalizedSymD * 4), 0, 100);
    final double faceHeight = distance(hairline, chin);
    final double eyeToEyeSpan = distance(leftEyeOuter, rightEyeOuter);
    final double horizontalGoldenRatio = (eyeToEyeSpan > 0) ? (faceWidth / eyeToEyeSpan) : 0.0;
    final double upperSection = (brow.dy - hairline.dy).abs();
    final double midSection = (noseBase.dy - brow.dy).abs();
    final double lowerSection = (chin.dy - noseBase.dy).abs();
    final double totalVerticalSections = upperSection + midSection + lowerSection;
    final double verticalUpperProportion = (totalVerticalSections > 0) ? upperSection / totalVerticalSections : 0.0;
    final double verticalMidProportion = (totalVerticalSections > 0) ? midSection / totalVerticalSections : 0.0;
    final double verticalLowerProportion = (totalVerticalSections > 0) ? lowerSection / totalVerticalSections : 0.0;
    final double innerEyeDistance = distance(leftEyeInner, rightEyeInner);
    final double leftEyeWidth  = distance(leftEyeOuter, leftEyeInner);
    final double rightEyeWidth = distance(rightEyeOuter, rightEyeInner);
    final double oneEyeWidth   = (leftEyeWidth + rightEyeWidth) / 2;
    final double fiveEyesRatio = (oneEyeWidth > 0) ? innerEyeDistance / oneEyeWidth : 0.0;
    double calculateTilt(Offset inner, Offset outer) {
      final double dy = inner.dy - outer.dy;
      final double dx = (outer.dx - inner.dx).abs(); 
      return dx > 0 ? atan2(dy, dx) * 180 / pi : 0.0;
    }
    final double leftCanthalTilt = calculateTilt(leftEyeInner, leftEyeOuter);
    final double rightCanthalTilt = calculateTilt(rightEyeInner, rightEyeOuter);
    final double averageCanthalTilt = (leftCanthalTilt + rightCanthalTilt) / 2;
    final double minSection = [upperSection, midSection, lowerSection].reduce(min);
    final double thirdsBase = minSection > 0 ? minSection : 1.0;
    final String facialThirdsRatio =
      "${(upperSection / thirdsBase).toStringAsFixed(1)}:"
      "${(midSection  / thirdsBase).toStringAsFixed(1)}:"
      "${(lowerSection/ thirdsBase).toStringAsFixed(1)}";
    final double upperLipHeight = distance(upperLipTop, upperLipBottom);
    final double lowerLipHeight = distance(lowerLipTop, lowerLipBottom);
    final double lipRatioValue = upperLipHeight > 0 ? lowerLipHeight / upperLipHeight : 0.0;
    final String lipVolumeRatio = "1:${lipRatioValue.toStringAsFixed(1)}";
    final double proportion = faceWidth == 0 ? 0.0 : faceHeight / faceWidth;
    final double boundingWidth = distance(faceLeft, faceRight) * 1.5; 
    final double boundingHeight = distance(hairline, chin) * 1.5;
    final List<NormalizedPoint> normalizedLandmarks = landmarks.map((offset) => NormalizedPoint(
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

  static Future<FaceMetrics?> processImage(String imagePath) async {
    if(Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      debugPrint('MediaPipe Face Mesh not supported on Desktop natively. Falling back to mock data...');
      return mockProcessImage();
    }
    try {
      final Completer<ui.Image> completer = Completer();
      final FileImage provider = FileImage(File(imagePath));
      provider.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          completer.complete(info.image);
        }),
      );
      final ui.Image image = await completer.future;
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        debugPrint('Failed to extract RGBA pixel buffer.');
        return null;
      }
      final Uint8List pixels = byteData.buffer.asUint8List();
      final FaceMeshProcessor processor = await FaceMeshProcessor.create();
      final FaceMeshImage mpImage = FaceMeshImage(
        pixels: pixels,
        width: image.width,
        height: image.height,
      );
      final FaceMeshResult result = processor.process(mpImage);
      processor.close();
      if(result.landmarks.isEmpty) {
        debugPrint('No faces detected in the image.');
        return null;
      }
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

  static Future<FaceMetrics?> mockProcessImage() async {
    final Random random = Random();
    List<Offset> simulatedOffsets = List.generate(478, (index) {
      return Offset(
        500.0 + (random.nextDouble() - 0.5) * 400.0,
        500.0 + (random.nextDouble() - 0.5) * 400.0,
      );
    });
    simulatedOffsets[5] = const Offset(500, 500);
    simulatedOffsets[10]= const Offset(500, 200);
    simulatedOffsets[152]=const Offset(500, 850);
    simulatedOffsets[33] = const Offset(350, 450);
    simulatedOffsets[133]= const Offset(430, 460);
    simulatedOffsets[263]= const Offset(650, 460);
    simulatedOffsets[362]= const Offset(570, 450);
    simulatedOffsets[9] = const Offset(500, 380);
    simulatedOffsets[2] = const Offset(500, 600);
    simulatedOffsets[234]= const Offset(250, 500);
    simulatedOffsets[454]= const Offset(750, 500);
    await Future.delayed(const Duration(milliseconds: 1500));
    return processLandmarks(simulatedOffsets);
  }
  
}
