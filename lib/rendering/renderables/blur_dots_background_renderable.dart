import 'dart:math' as math;
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sigma/rendering/renderable.dart';

/// Author: Ian Wilkey and Barney Jin
final class BouncyBlurDotsRenderable implements Renderable {

  final int dotCount;
  final double blurSigma;
  final double speed;
  final double minRadius;
  final double maxRadius;
  final bool breathe;
  final math.Random _rng;
  final List<_Dot> _dots;

  Size _lastSize = Size.zero;
  bool _initialized = false;

  BouncyBlurDotsRenderable({
    int seed = 3,
    this.dotCount = 18,
    this.blurSigma = 30,
    this.speed = 0.75,
    this.minRadius = 80,
    this.maxRadius = 160,
    this.breathe = true,
  })  : _rng = math.Random(seed),
        _dots = List.generate(dotCount, (i) => _Dot.random(seed ^ (i * 0x9E3779B9)));

  void tick(double dtSeconds) {
    if(_lastSize.isEmpty) return;
    final double dt = dtSeconds.clamp(0.0, 1 / 20);
    if(!_initialized) {
      _initialized = true;
      final double cx = _lastSize.width * 0.5;
      final double cy = _lastSize.height * 0.5;
      final double jitter = math.min(_lastSize.width, _lastSize.height) * 0.01;
      for(final _Dot d in _dots) {
        d.x = cx + (_rng.nextDouble() - 0.5) * jitter;
        d.y = cy + (_rng.nextDouble() - 0.5) * jitter;
        final double angle = _rng.nextDouble() * math.pi * 2;
        final double base = 18 + _rng.nextDouble() * 22;
        final double s = base * (0.65 + _rng.nextDouble() * 0.7);
        d.vx = math.cos(angle) * s;
        d.vy = math.sin(angle) * s;
        d.baseR = minRadius + _rng.nextDouble() * (maxRadius - minRadius);
        d.phase = _rng.nextDouble() * math.pi * 2;
      }
    }
    for(final _Dot d in _dots) {
      d.step(
        size: _lastSize,
        dt: dt,
        speed: speed,
        breathe: breathe,
      );
    }
  }

  @override
  void render(final Canvas canvas, final Size size) {
    _lastSize = size;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final Paint layerPaint = Paint()
      ..imageFilter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
    canvas.saveLayer(Offset.zero & size, layerPaint);
    for(final _Dot d in _dots) {
      final Paint p = Paint()
        // ignore: deprecated_member_use
        ..color = d.color.withOpacity(0.92)
        ..blendMode = BlendMode.screen;
      canvas.drawCircle(Offset(d.x, d.y), d.r, p);
    }
    canvas.restore();
    final Rect r = Offset.zero & size;
    final Paint veil = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x22000000),
          Color(0xAA000000),
        ],
      ).createShader(r);
    canvas.drawRect(r, veil);
  }
}

final class _Dot {

  final Color color;

  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double baseR = 120;
  double r = 120;
  double phase = 0;

  _Dot(this.color);

  static const List<Color> _palette = <Color>[
    Color(0xFF0A84FF),
    Color(0xFF64D2FF),
    Color(0xFF5E5CE6),
    Color(0xFFBF5AF2),
    Color(0xFFFF2D55),
    Color(0xFFFF453A),
    Color(0xFFFF9F0A),
    Color(0xFFFFD60A),
    Color(0xFF30D158),
    Color(0xFF00C7BE),
    Color(0xFFAC8E68),
    Color(0xFF7D7AFF),
  ];

  static _Dot random(int seed) {
    final Random rng = math.Random(seed);
    final Color c = _palette[rng.nextInt(_palette.length)];
    return _Dot(c);
  }

  void step({
    required Size size,
    required double dt,
    required double speed,
    required bool breathe,
  }) {
    if(breathe) {
      phase += dt * 0.55; // slow
      final double s = 0.92 + 0.08 * math.sin(phase);
      r = baseR * s;
    } else {
      r = baseR;
    }
    x += vx * dt * speed;
    y += vy * dt * speed;
    final double margin = r * 0.35;
    final double left = -margin;
    final double right = size.width + margin;
    final double top = -margin;
    final double bottom = size.height + margin;
    if(x <= left) {
      x = left + (left - x);
      vx = vx.abs();
    } else if (x >= right) {
      x = right - (x - right);
      vx = -vx.abs();
    }
    if(y <= top) {
      y = top + (top - y);
      vy = vy.abs();
    } else if (y >= bottom) {
      y = bottom - (y - bottom);
      vy = -vy.abs();
    }
    const double dragPerSecond = 0.0025;
    final double drag = math.pow(1.0 - dragPerSecond, dt).toDouble();
    vx *= drag;
    vy *= drag;
    const double minSpeed = 10.0;
    final double sp = math.sqrt(vx * vx + vy * vy);
    if (sp < minSpeed) {
      final double ang = math.atan2(vy, vx);
      vx = math.cos(ang) * minSpeed;
      vy = math.sin(ang) * minSpeed;
    }
  }
}
