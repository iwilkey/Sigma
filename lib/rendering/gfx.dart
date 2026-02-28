import 'package:flutter/material.dart';
import 'package:sigma/rendering/renderable.dart';
import 'package:sigma/rendering/renderer.dart';

/// Author: Ian Wilkey and Barney Jin
final class Gfx {

  Gfx._();

  static Widget render(final Renderable renderable) {
    return CustomPaint(
      painter: Renderer(renderable),
      child: const SizedBox.expand(),
    );
  }

}
