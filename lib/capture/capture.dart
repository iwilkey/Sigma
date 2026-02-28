import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';
import 'package:sigma/capture/ui/capture_button.dart';
import 'package:sigma/capture/ui/turn_head_hint.dart';
import 'package:sigma/inference/pipeline.dart';
import 'package:sigma/rendering/gfx.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/rendering/renderables/face_mesh_renderer.dart';

/// Author: Ian Wilkey and Barney Jin
final class FaceCaptureState extends StatefulWidget {
  final Function(FaceMesh mesh) onCapturePressed;
  const FaceCaptureState({
    super.key,
    required this.onCapturePressed
  });
  @override
  State<FaceCaptureState> createState() => _FaceCaptureStateState();
}

/// Author: Ian Wilkey and Barney Jin
final class _FaceCaptureStateState extends State<FaceCaptureState> {

  static const bool S_STREAM_FRAME = true;

  late final Completer<void>    _initialized = Completer<void>();
  late final FaceMeshPipeline   _pipeline;
  late final FaceMeshRenderable _meshRenderable;

  FaceMesh?         _latestMesh;
  CameraController? _controller;
  bool              _canTakeImage = false;
  bool              _streaming = false;
  Timer? _hintTimer;
  bool _showTurnHint = false;

  int t = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _scheduleHintIfNeeded();
    _meshRenderable = FaceMeshRenderable(
      null,
      drawTriangles: true,
      drawPoints: true,
      constructionTrianglesPerFrame: 20,
      destructionTrianglesPerFrame: 120,
      partialTriangle: true,
      onFullyConstructed: () {
        _canTakeImage = true;
        _hideHint();
        SchedulerBinding.instance.addPostFrameCallback((_) => setState((){}));
        HapticFeedback.heavyImpact();
      },
      onFullyDestructed: () {
        _canTakeImage = false;
        _scheduleHintIfNeeded();
        SchedulerBinding.instance.addPostFrameCallback((_) => setState((){}));
      },
      onAnimating: ({required constructing, required destructing, required progress}) {
        _canTakeImage = false;
        if(constructing) {
          HapticFeedback.lightImpact();
        }
      },
    );
    _pipeline = FaceMeshPipeline(
      delegate: FaceMeshDelegate.gpuV2,
      rotationDegrees: 0,
      mirrorHorizontal: false
    );
    _pipeline.start();
    _pipeline.stream.listen((final FaceMesh mesh) {
      _latestMesh = mesh;
      if(mesh.bgraPixels != null) {
        final FaceMesh? mesh = _latestMesh;
        if(mesh == null) return;
        widget.onCapturePressed(mesh);
      } else {
        _meshRenderable.tick(mesh);
        setState((){});
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if(cameras.isEmpty) {
        throw Exception('No cameras detected');
      }
      final CameraDescription camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _controller = controller;
      if(!_initialized.isCompleted) {
        _initialized.complete();
      }
      if(S_STREAM_FRAME && !_streaming) {
        _streaming = true;
        await controller.startImageStream(_onFrame);
      }
      setState(() {});
    } catch (e, st) {
      debugPrint('Camera init error: $e');
      debugPrintStack(stackTrace: st);
      if(!_initialized.isCompleted) {
        _initialized.completeError(e, st);
      }
      setState(() {});
    }
  }

  void _onFrame(final CameraImage imageData) {
    _pipeline.onFrameBgra8888(imageData);
  }

  @override
  void dispose() {
    _pipeline.stop();
    _hintTimer?.cancel();
    final CameraController? c = _controller;
    if(c != null) {
      if(_streaming && c.value.isStreamingImages) {
        c.stopImageStream();
      }
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initialized.future,
        builder: (context, snap) {
          if(snap.hasError) {
            return Center(
              child: Text(
                'Camera init failed:\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          final bool ready = snap.connectionState == ConnectionState.done &&
            _controller != null &&
            _controller!.value.isInitialized;
          return Stack(
            fit: StackFit.expand,
            children: [
              if(!ready) ...[
                const ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else ...[
                if(_controller != null && _controller!.value.isInitialized)
                  _renderImageFeed(_controller!),
                if(_latestMesh != null) ...[
                  Gfx.render(_meshRenderable),
                ],
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36,
                  child: Center(
                    child: CaptureButton(
                      onPressed: _canTakeImage ? () {
                        _pipeline.requestPixelCapture();
                      } : null,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: MediaQuery.of(context).padding.top,
                  child: TurnHeadHint(visible: _showTurnHint),
                ),
              ]
            ],
          );
        },
      ),
    );
  }
  
  Widget _renderImageFeed(final CameraController controller) {
    final double asp = 1.0 / controller.value.aspectRatio;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 1000,
          height: 1000 / asp,
          child: AspectRatio(
            aspectRatio: asp,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  void _scheduleHintIfNeeded() {
    _hintTimer?.cancel();
    if(_canTakeImage) {
      if(_showTurnHint) SchedulerBinding.instance.addPostFrameCallback((_) => setState((){_showTurnHint = false;}));
      return;
    }
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if(!mounted) return;
      if(!_canTakeImage) SchedulerBinding.instance.addPostFrameCallback((_) => setState((){_showTurnHint = true;}));
    });
  }

  void _hideHint() {
    _hintTimer?.cancel();
    if(_showTurnHint) SchedulerBinding.instance.addPostFrameCallback((_) => setState((){_showTurnHint = false;}));
  }

}
