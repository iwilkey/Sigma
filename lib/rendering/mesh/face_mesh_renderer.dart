import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/rendering/renderable.dart';

/// Author: Ian Wilkey and Barney Jin
final class FaceMeshRenderable implements Renderable {

  final BoxFit fit;
  final bool   mor;
  final bool   dp;
  final bool   dt;
  final double pr;
  final double sw;
  final double threshold;
  final double constructionTrianglesPerFrame;
  final double destructionTrianglesPerFrame;
  final bool   partialTriangle;

  double _triProgress       = 0.0;
  int    _lastTriangleCount = -1;

  late List<List<int>> _orderedTriangles = const [];

  FaceMesh? _mesh;

  FaceMeshRenderable(
    FaceMesh? initial, {
    this.fit = BoxFit.cover,
    this.mor = false,
    this.dp = true,
    this.dt = true,
    this.pr = 1.5,
    this.sw = 1.0,
    this.threshold = 0.5,
    this.constructionTrianglesPerFrame = 80.0,
    this.destructionTrianglesPerFrame = 120.0,
    this.partialTriangle = true,
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
    _triProgress += build ? step : -step;
    _triProgress = _triProgress.clamp(0.0, maxT);
    final Size iss = Size(m.imageWidth.toDouble(), m.imageHeight.toDouble());
    final mapper = _transform(iss: iss, ws: size, fit: fit);
    final List<Offset> mapped = List<Offset>.generate(
      m.points.length,
      (i) {
        final Offset p = mapper(m.points[i]);
        return mor ? Offset(size.width - p.dx, p.dy) : p;
      },
      growable: false,
    );
    final int triCount = _orderedTriangles.length;
    double triT(int i) => triCount <= 1 ? 0.0 : (i / (triCount - 1));
    final Paint lpBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    final Paint pp = Paint()..style = PaintingStyle.fill;
    final int fullCount = _triProgress.floor();
    final double frac = _triProgress - fullCount;
    if(dp && fullCount > 0) {
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
          canvas.drawCircle(mapped[i], pr, pp);
        }
      }
    }
    if(!dt) return;
    for(int i = 0; i < fullCount; i++) {
      final tri = _orderedTriangles[i];
      final Color c = _palette(triT(i));
      final Paint linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        // ignore: deprecated_member_use
        ..color = c.withOpacity(0.40);
      _tri(canvas, mapped, tri, linePaint);
    }
    if(partialTriangle && fullCount < _orderedTriangles.length && frac > 0.0) {
      final List<int> tri = _orderedTriangles[fullCount];
      final int a = (frac * 255).clamp(0, 255).toInt();
      final Paint lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
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
      final c1 = _tcent(m.points, t1);
      final c2 = _tcent(m.points, t2);
      final d1 = (c1 - center).distanceSquared;
      final d2 = (c2 - center).distanceSquared;
      return d1.compareTo(d2);
    });
    _orderedTriangles = copy;
    final double maxT = _orderedTriangles.length.toDouble();
    _triProgress = _triProgress.clamp(0.0, maxT);
  }

  Offset _tcent(List<Offset> pts, List<int> tri) {
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

  Color _palette(final double t) {
    final double h = (89.0 + 120.0 * t) % 360.0;
    final double s = 0.95;
    final double v = 0.95;
    return HSVColor.fromAHSV(1.0, h, s, v).toColor();
  }

}
