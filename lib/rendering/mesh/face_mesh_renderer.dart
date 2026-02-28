import 'package:flutter/material.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/rendering/renderable.dart';

/// Author: Ian Wilkey and Barney Jin
final class FaceMeshRenderable implements Renderable {

  final FaceMesh?   mesh;
  final BoxFit           fit;
  final bool             mor;
  final bool             dp;
  final bool             dt;
  final double           pr;
  final double           sw;
  final List<List<int>>? ti;

  const FaceMeshRenderable(
    this.mesh, {
    this.fit = BoxFit.cover,
    this.mor = false,
    this.dp = true,
    this.dt = false,
    this.pr = 1.5,
    this.sw = 1.0,
    this.ti,
  });

  @override
  void render(final Canvas canvas, final Size size) {
    final FaceMesh? m = mesh;
    if(m == null || m.points.isEmpty) return;
    final Size iss = Size(m.imageWidth.toDouble(), m.imageHeight.toDouble());
    final Offset Function(Offset) mapper = _transform(
      iss: iss,
      ws: size,
      fit: fit,
    );
    final Paint pp = Paint()..style = PaintingStyle.fill;
    final Paint lp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    final List<Offset> map = List<Offset>.generate(
      m.points.length,
      (i) {
        final Offset p = mapper(m.points[i]);
        return mor ? Offset(size.width - p.dx, p.dy) : p;
      },
      growable: false,
    );
    if(dt && ti != null) {
      for(final List<int> tri in ti!) {
        if(tri.length != 3) continue;
        final int a = tri[0];
        final int b = tri[1];
        final int c = tri[2];
        if(a < 0 || b < 0 || c < 0) continue;
        if(a >= map.length || b >= map.length || c >= map.length) {
          continue;
        }
        final Path path = Path()
          ..moveTo(map[a].dx, map[a].dy)
          ..lineTo(map[b].dx, map[b].dy)
          ..lineTo(map[c].dx, map[c].dy)
          ..close();
        canvas.drawPath(path, lp);
      }
    }
    if(dp) {
      for(final Offset p in map) {
        canvas.drawCircle(
          p, 
          pr, 
          pp
        );
      }
    }
  }

  Offset Function(Offset) _transform({
    required Size iss,
    required Size ws,
    required BoxFit fit,
  }) {
    final FittedSizes f = applyBoxFit(fit, iss, ws);
    final Rect src = Alignment.center.inscribe(
      f.source, 
      Offset.zero & iss
    );
    final Rect dst = Alignment.center.inscribe(
      f.destination, 
      Offset.zero & ws
    );
    final double sx = dst.width / src.width;
    final double sy = dst.height / src.height;
    return (final Offset p) {
      final double dx = (p.dx - src.left) * sx + dst.left;
      final double dy = (p.dy - src.top) * sy + dst.top;
      return Offset(dx, dy);
    };
  }

}
