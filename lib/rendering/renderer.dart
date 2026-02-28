import 'package:flutter/material.dart';
import 'package:sigma/rendering/renderable.dart';

/// Author: Ian Wilkey and Barney Jin
final class Renderer extends CustomPainter {
  final Renderable renderable;
  const Renderer(this.renderable);
  @override
  void paint(Canvas canvas, Size size) => renderable.render(canvas, size);
  @override
  bool shouldRepaint(covariant Renderer oldDelegate) => true;
}
