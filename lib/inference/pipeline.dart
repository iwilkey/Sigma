import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:mediapipe_face_mesh/face_mesh_stream_processor.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';
import 'package:sigma/inference/face_mesh.dart';

/// Author: Ian Wilkey and Barney Jin
final class FaceMeshPipeline {

  final FaceMeshDelegate delegate;
  final int              rotationDegrees;
  final bool             mirrorHorizontal;
  
  final StreamController<FaceMesh> _out = StreamController<FaceMesh>.broadcast();

  FaceMeshProcessor?                  _processor;
  FaceMeshStreamProcessor?            _streamProcessor;
  StreamController<FaceMeshImage>?    _bgraController;
  StreamSubscription<FaceMeshResult>? _sub;
  
  List<List<int>>? _cachedTriangleIndices;
  bool             _inflight = false;

  Uint8List? _pendingBgra;
  int?       _pendingBytesPerRow;
  int?       _pendingWidth;
  int?       _pendingHeight;

  bool             get isStarted => _processor != null;
  Stream<FaceMesh> get stream    => _out.stream;

  FaceMeshPipeline({
    this.delegate = FaceMeshDelegate.xnnpack,
    this.rotationDegrees = 0,
    this.mirrorHorizontal = true,
  });

  Future<void> start() async {
    if(isStarted) return;
    _processor = await FaceMeshProcessor.create(delegate: delegate);
    _streamProcessor = FaceMeshStreamProcessor(_processor!);
    _bgraController = StreamController<FaceMeshImage>();
    _sub = _streamProcessor!
      .process(
        _bgraController!.stream,
        rotationDegrees: rotationDegrees,
        mirrorHorizontal: mirrorHorizontal,
      )
      .listen(
        _hmesh, 
        onError: _handleError
      );
  }

  void onFrameBgra8888(final CameraImage image) {
    final StreamController<FaceMeshImage>? c = _bgraController;
    if(c == null || c.isClosed) return;
    if(!c.hasListener) return;
    if(_inflight) return;
    if(image.planes.isEmpty) return;
    final Plane p = image.planes.first;
    _pendingBgra = Uint8List.fromList(p.bytes);
    _pendingBytesPerRow = p.bytesPerRow;
    _pendingWidth = image.width;
    _pendingHeight = image.height;
    _inflight = true;
    final FaceMeshImage fm = FaceMeshImage(
      pixels: p.bytes,
      width: image.width,
      height: image.height,
      pixelFormat: FaceMeshPixelFormat.bgra,
      bytesPerRow: p.bytesPerRow,
    );
    c.add(fm);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await _bgraController?.close();
    _processor?.close();
    _sub = null;
    _bgraController = null;
    _streamProcessor = null;
    _processor = null;
    _inflight = false;
    _cachedTriangleIndices = null;
    _pendingBgra = null;
    _pendingBytesPerRow = null;
    _pendingWidth = null;
    _pendingHeight = null;
    await _out.close();
  }

  void _hmesh(final FaceMeshResult result) {
    _inflight = false;
    final Uint8List? bgra = _pendingBgra;
    final int? bpr = _pendingBytesPerRow;
    final int? w = _pendingWidth;
    final int? h = _pendingHeight;
    _pendingBgra = null;
    _pendingBytesPerRow = null;
    _pendingWidth = null;
    _pendingHeight = null;
    if(bgra == null || bpr == null || w == null || h == null) return;
    final double wf = w.toDouble();
    final double hf = h.toDouble();
    final List<Offset> pts = result.landmarks
      .map((lm) => Offset(lm.x * wf, lm.y * hf))
      .toList(growable: false);
    _cachedTriangleIndices ??= result.triangles
      .map((t) => List<int>.unmodifiable(t.indices))
      .toList(growable: false);
    _out.add(
      FaceMesh(
        imageWidth: w,
        imageHeight: h,
        bgraPixels: bgra,
        bytesPerRow: bpr,
        points: pts,
        triangleIndices: _cachedTriangleIndices!,
        score: result.score,
      ),
    );
  }

  void _handleError(final Object err, final StackTrace st) {
    _inflight = false;
    _pendingBgra = null;
    _pendingBytesPerRow = null;
    _pendingWidth = null;
    _pendingHeight = null;
  }

}
