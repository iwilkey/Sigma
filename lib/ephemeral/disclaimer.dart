import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sigma/rendering/gfx.dart';
import 'package:sigma/rendering/renderables/blur_dots_background_renderable.dart';
import 'package:sigma/router.dart';

/// Author: Ian Wilkey and Barney Jin
final class WelcomeScreen extends StatefulWidget {
  final String nextRouteName;
  final List<String> lines;
  const WelcomeScreen({
    super.key,
    required this.nextRouteName,
    this.lines = const [
      "Welcome to Sigma",
      "Scan your face to discover your strengths and unique features.",
      "Beauty is more than math.",
      "Insights are based on measured facial geometry and common beauty signals.",
      "However, these results do not define you, and are likely to reflect bias.",
      "An image may be sent briefly for analysis and isn’t stored.",
      "Ready? Let’s begin."
    ],
  });
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// Author: Ian Wilkey and Barney Jin
final class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {

  late final BouncyBlurDotsRenderable _bg;

  late final Ticker _ticker;

  int _index = 0;

  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bg = BouncyBlurDotsRenderable(
      seed: 3,
      dotCount: 14,
      blurSigma: 26,
      speed: 1.0,
    );
    _ticker = createTicker((now) {
      final Duration dt = now - _last;
      _last = now;
      if(dt.inMicroseconds <= 0) return;
      final double dts = (dt.inMicroseconds / 1e6).clamp(0.0, 1 / 20);
      _bg.tick(dts);
      if(mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _next() {
    if(_index < widget.lines.length - 1) {
      setState(() => _index++);
      return;
    }
    SIGMA_ROUTER.go(widget.nextRouteName);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Gfx.render(_bg),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    // ignore: deprecated_member_use
                    Colors.black.withOpacity(0.20),
                    // ignore: deprecated_member_use
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 650),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) {
                          final CurvedAnimation fade = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
                          return FadeTransition(
                            opacity: fade,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.985, end: 1.0).animate(fade),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(key: ValueKey(_index), padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(
                          widget.lines[_index],
                          key: ValueKey(_index),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              )),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: math.max(0, media.padding.bottom - 16)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _next,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Text(
                            _index == widget.lines.length - 1 ? 'Begin' : 'Next',
                            key: ValueKey(_index == widget.lines.length - 1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
