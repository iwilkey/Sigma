import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/rendering/renderable.dart';

typedef MeshProgressTick = void Function({
  required bool constructing,
  required bool destructing,
  required double progress, // 0..1
});

/// Author: Ian Wilkey and Barney Jin
final class FaceMeshRenderable implements Renderable {

  final BoxFit fit;
  final bool   mirror;
  final bool   drawPoints;
  final bool   drawTriangles;
  final double pointRadius;
  final double strokeWidth;
  final double threshold;
  final double constructionTrianglesPerFrame;
  final double destructionTrianglesPerFrame;
  final bool   partialTriangle;
  final VoidCallback? onFullyConstructed;
  final VoidCallback? onFullyDestructed;
  final MeshProgressTick? onAnimating;

  double _triProgress       = 0.0;
  int    _lastTriangleCount = -1;

  bool _wasFullyConstructed = false;
  bool _wasFullyDestructed = true;

  late List<List<int>> _orderedTriangles = const [];

  FaceMesh? _mesh;

  FaceMeshRenderable(
    FaceMesh? initial, {
    this.fit = BoxFit.cover,
    this.mirror = false,
    this.drawPoints = true,
    this.drawTriangles = true,
    this.pointRadius = 1.5,
    this.strokeWidth = 1.0,
    this.threshold = 0.5,
    this.constructionTrianglesPerFrame = 80.0,
    this.destructionTrianglesPerFrame = 120.0,
    this.partialTriangle = true,
    required this.onFullyConstructed,
    required this.onFullyDestructed,
    required this.onAnimating
  }) : _mesh = initial;

  void tick(final FaceMesh? mesh) {
    _mesh = mesh;
  }

  @override
  void render(final Canvas canvas, final Size size) {
    final FaceMesh? m = _mesh;
    if(m == null || m.points.isEmpty) return;
    final double conf = 1.0 / (1.0 + math.exp(-m.score));
    final bool build = conf >= threshold;
    _sort(m);
    if(_orderedTriangles.isEmpty) return;
    final double maxT = _orderedTriangles.length.toDouble();
    final double step = build ? constructionTrianglesPerFrame : destructionTrianglesPerFrame;
    final double before = _triProgress;
    _triProgress += build ? step : -step;
    _triProgress = _triProgress.clamp(0.0, maxT);
    final bool changed = _triProgress != before;
    final bool constructing = build && changed;
    final bool destructing = !build && changed;
    final double progress01 = maxT <= 0 ? 0.0 : (_triProgress / maxT).clamp(0.0, 1.0);
    if(onAnimating != null && (constructing || destructing)) {
      onAnimating!(
        constructing: constructing,
        destructing: destructing,
        progress: progress01,
      );
    }
    final bool fullyConstructed = _triProgress >= maxT - 1e-9;
    final bool fullyDestructed = _triProgress <= 1e-9;
    if(fullyConstructed && !_wasFullyConstructed) {
      onFullyConstructed?.call();
    }
    if(!fullyConstructed) {
      _wasFullyConstructed = false;
    } else {
      _wasFullyConstructed = true;
    }
    if(fullyDestructed && !_wasFullyDestructed) {
      onFullyDestructed?.call();
    }
    if(!fullyDestructed) {
      _wasFullyDestructed = false;
    } else {
      _wasFullyDestructed = true;
    }
    final Size iss = Size(m.imageWidth.toDouble(), m.imageHeight.toDouble());
    final mapper = _transform(iss: iss, ws: size, fit: fit);
    final List<Offset> mapped = List<Offset>.generate(
      m.points.length,
      (i) {
        final Offset p = mapper(m.points[i]);
        return mirror ? Offset(size.width - p.dx, p.dy) : p;
      },
      growable: false,
    );
    final Paint lpBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final Paint pp = Paint()..style = PaintingStyle.fill..color=Colors.white;
    final int fullCount = _triProgress.floor();
    final double frac = _triProgress - fullCount;
    if(drawPoints && fullCount > 0) {
      final used = Uint8List(mapped.length);
      for(int i = 0; i < fullCount; i++) {
        final List<int> tri = _orderedTriangles[i];
        used[tri[0]] = 1;
        used[tri[1]] = 1;
        used[tri[2]] = 1;
      }
      if(partialTriangle && frac > 0 && fullCount < _orderedTriangles.length) {
        final List<int> tri = _orderedTriangles[fullCount];
        used[tri[0]] = 1;
        used[tri[1]] = 1;
        used[tri[2]] = 1;
      }
      for(int i = 0; i < mapped.length; i++) {
        if(used[i] == 1) {
          canvas.drawCircle(mapped[i], pointRadius, pp);
        }
      }
    }
    if(!drawTriangles) return;
    for(int i = 0; i < fullCount; i++) {
      final List<int> tri = _orderedTriangles[i];
      final Color c = Colors.white;
      final Paint linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        // ignore: deprecated_member_use
        ..color = c.withOpacity(0.30);
      _tri(canvas, mapped, tri, linePaint);
    }
    if(partialTriangle && fullCount < _orderedTriangles.length && frac > 0.0) {
      final List<int> tri = _orderedTriangles[fullCount];
      final int a = (frac * 255).clamp(0, 255).toInt();
      final Paint lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = lpBase.color.withAlpha(a);
      _tri(canvas, mapped, tri, lp);
    }
  }

  void _tri(final Canvas canvas, final List<Offset> pts, final List<int> tri, final Paint paint) {
    if(tri.length != 3) return;
    final int a = tri[0], b = tri[1], c = tri[2];
    if(a < 0 || b < 0 || c < 0) return;
    if(a >= pts.length || b >= pts.length || c >= pts.length) return;
    final Path path = Path()
      ..moveTo(pts[a].dx, pts[a].dy)
      ..lineTo(pts[b].dx, pts[b].dy)
      ..lineTo(pts[c].dx, pts[c].dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _sort(final FaceMesh m) {
    final List<List<int>> tris = m.triangleIndices;
    if(tris.isEmpty) {
      _orderedTriangles = const [];
      _lastTriangleCount = 0;
      _triProgress = 0;
      return;
    }
    if(_lastTriangleCount == tris.length && _orderedTriangles.isNotEmpty) return;
    _lastTriangleCount = tris.length;
    final Offset center = _cent(m.points);
    final List<List<int>> copy = List<List<int>>.from(tris);
    copy.sort((t1, t2) {
      final Offset c1 = _tcent(m.points, t1);
      final Offset c2 = _tcent(m.points, t2);
      final double d1 = (c1 - center).distanceSquared;
      final double d2 = (c2 - center).distanceSquared;
      return d1.compareTo(d2);
    });
    _orderedTriangles = copy;
    final double maxT = _orderedTriangles.length.toDouble();
    _triProgress = _triProgress.clamp(0.0, maxT);
  }

  Offset _tcent(final List<Offset> pts, final List<int> tri) {
    final Offset a = pts[tri[0]];
    final Offset b = pts[tri[1]];
    final Offset c = pts[tri[2]];
    return Offset(
      (a.dx + b.dx + c.dx) / 3.0, 
      (a.dy + b.dy + c.dy) / 3.0
    );
  }

  Offset _cent(final List<Offset> pts) {
    double sx = 0, sy = 0;
    for(final Offset p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(
      sx / pts.length, 
      sy / pts.length
    );
  }

  Offset Function(Offset) _transform({
    required Size iss,
    required Size ws,
    required BoxFit fit,
  }) {
    final FittedSizes f = applyBoxFit(fit, iss, ws);
    final Rect src = Alignment.center.inscribe(f.source, Offset.zero & iss);
    final Rect dst = Alignment.center.inscribe(f.destination, Offset.zero & ws);
    final double sx = dst.width / src.width;
    final double sy = dst.height / src.height;
    return (final Offset p) {
      final double dx = (p.dx - src.left) * sx + dst.left;
      final double dy = (p.dy - src.top) * sy + dst.top;
      return Offset(dx, dy);
    };
  }

}
