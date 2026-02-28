import 'dart:ui';

/// Author: Ian Wilkey and Barney Jin
abstract interface class Renderable {
  /// knows how to render on to a canvas.
  void render(final Canvas canvas, final Size size);
}
