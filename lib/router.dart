// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:sigma/capture/capture.dart';
import 'package:sigma/ephemeral/post_capture.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/analysis/face_processor.dart';
import 'package:sigma/analysis/face_metrics.dart';
import 'package:sigma/ephemeral/disclaimer.dart';
import 'package:sigma/rendering/gfx.dart';
import 'package:sigma/rendering/renderables/blur_dots_background_renderable.dart';

/// Author: Ian Wilkey and Barney Jin
final class Results {
  final FaceMesh mesh;
  final Future<String> aifut;
  String? full;
  Results({
    required this.mesh,
    required this.aifut,
    this.full
  });
}

final GoRouter SIGMA_ROUTER = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => sheetPage(
        state: state,
        from: SwipeFrom.left,
        child: WelcomeScreen(nextRouteName: "/capture")
      ),
    ),
    GoRoute(
      path: '/capture',
      pageBuilder: (context, state) => sheetPage(
        state: state,
        from: SwipeFrom.right,
        child: FaceCaptureState(
          onCapturePressed: (final FaceMesh mesh) {
            final Results res = Results(mesh: mesh, aifut: openAiResultsFuture(
              mesh: mesh
            ));
            context.go(
              '/processing',
              extra: res,
            );
          },
        ),
      ),
    ),
    GoRoute(
      path: '/processing',
      pageBuilder: (context, state) {
        final Results res = state.extra! as Results;
        return sheetPage(
          from: SwipeFrom.right,
          state: state,
          child: ProcessingResultsScreen(
            mesh: res.mesh,
            resultsFuture: res.aifut,
            onSeeFullResults: (text) {
              res.full = text;
              context.go('/review', extra: res);
            },
          ),
        );
      },
    ),
    GoRoute(
      path: '/review',
      pageBuilder: (context, state) {
        final Results res = state.extra! as Results;
        return sheetPage(
          from: SwipeFrom.right,
          state: state,
          child: FaceReviewState(
            mesh: res.mesh, 
            aiResponse: res.full!,
            onDone: () {
              context.go('/');
            },
          ),
        );
      },
    ),
  ],
);

enum SwipeFrom { left, right }

CustomTransitionPage<void> sheetPage({
  required GoRouterState state,
  required Widget child,
  SwipeFrom from = SwipeFrom.right,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: true,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation primary = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final double dir = (from == SwipeFrom.right) ? 1.0 : -1.0;
      final Animation<Offset> inSlide = Tween<Offset>(
        begin: Offset(dir, 0),
        end: Offset.zero,
      ).animate(primary);
      final Animation<Offset> outSlide = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-0.18 * dir, 0),
      ).animate(primary);
      final Animation<double> shadow = Tween<double>(
        begin: 0.0,
        end: 0.22,
      ).animate(primary);
      return Stack(
        fit: StackFit.expand,
        children: [
          SlideTransition(
            position: outSlide,
            child: const ColoredBox(color: Colors.black),
          ),
          SlideTransition(
            position: inSlide,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: shadow,
                    builder: (context, _) {
                      return Align(
                        alignment:
                            (from == SwipeFrom.right) ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: (from == SwipeFrom.right)
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              end: (from == SwipeFrom.right)
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              colors: [
                                Colors.black.withOpacity(shadow.value),
                                Colors.black.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Author: Ian Wilkey and Barney Jin
final class FaceReviewState extends StatefulWidget {
  final FaceMesh mesh;
  final String aiResponse;
  final VoidCallback onDone;
  const FaceReviewState({
    super.key,
    required this.mesh,
    required this.aiResponse,
    required this.onDone,
  });
  @override
  State<FaceReviewState> createState() => _FaceReviewStateState();
}

/// Author: Ian Wilkey and Barney Jin
final class _FaceReviewStateState extends State<FaceReviewState> with SingleTickerProviderStateMixin {

  late final BouncyBlurDotsRenderable _bg;
  late final Ticker _ticker;

  Duration _last = Duration.zero;
  ui.Image? _image;
  FaceMetrics? _metrics;
  String _displayedText = '';
  Timer? _typewriter;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _metrics = FaceProcessor.processLandmarks(
      widget.mesh.points,
      imageSize: Size(
        widget.mesh.imageWidth.toDouble(),
        widget.mesh.imageHeight.toDouble(),
      ),
    );
    _decodeImage();
    _bg = BouncyBlurDotsRenderable(
      seed: 3,
      dotCount: 14,
      blurSigma: 26,
      speed: 1.0,
    );
    _ticker = createTicker((now) {
      final Duration dt = now - _last;
      _last = now;
      if (dt.inMicroseconds <= 0) return;
      final double dts = (dt.inMicroseconds / 1e6).clamp(0.0, 1 / 20);
      _bg.tick(dts);
      if (mounted) setState(() {});
    })..start();
    _startTypewriter(widget.aiResponse);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if(!mounted) return;
      setState(() => _showContent = true);
    });
  }

  void _decodeImage() {
    ui.decodeImageFromPixels(
      widget.mesh.bgraPixels!,
      widget.mesh.imageWidth,
      widget.mesh.imageHeight,
      ui.PixelFormat.bgra8888,
      (ui.Image img) {
        if (mounted) setState(() => _image = img);
      },
      rowBytes: widget.mesh.bytesPerRow,
    );
  }

  void _startTypewriter(String text) {
    _typewriter?.cancel();
    _displayedText = '';
    int i = 0;
    const Duration tick = Duration(milliseconds: 18);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if(!mounted) return;
      _typewriter = Timer.periodic(tick, (t) {
        if(!mounted) {
          t.cancel();
          return;
        }
        if(i < text.length) {
          setState(() => _displayedText = text.substring(0, i + 1));
          i++;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _typewriter?.cancel();
    _image?.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FaceMetrics? metrics = _metrics;
    final MediaQueryData media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
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
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.70),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: metrics == null
                ? const Center(
                    child: Text(
                      "Error analyzing facial topology.",
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 72,),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 0),
                                child: _CircularPortraitCard(
                                  mesh: widget.mesh,
                                  image: _image,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 90),
                                child: _AiSnippetCard(
                                  displayedText: _displayedText,
                                  showSpinner: _displayedText.isEmpty,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 160),
                                child: _MetricRow(
                                  title: "Symmetry Match",
                                  subtitle: "Perceived reflection alignment",
                                  value: "${metrics.overallSymmetry.toStringAsFixed(1)}%",
                                  trailingHint: "Ideal 100%",
                                  icon: Icons.balance_rounded,
                                  emphasize: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 200),
                                child: _MetricRow(
                                  title: "Canthal Tilt",
                                  subtitle: "Eye expression angle",
                                  value:
                                      "${metrics.averageCanthalTilt > 0 ? '+' : ''}${metrics.averageCanthalTilt.toStringAsFixed(1)}°",
                                  trailingHint: "Slight positive",
                                  icon: Icons.visibility_rounded,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 240),
                                child: _MetricRow(
                                  title: "Facial Thirds",
                                  subtitle: "Upper : Mid : Lower proportions",
                                  value: metrics.facialThirdsRatio,
                                  trailingHint: "Ideal 1:1:1",
                                  icon: Icons.view_agenda_rounded,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 280),
                                child: _MetricRow(
                                  title: "Lip Volume",
                                  subtitle: "Upper vs lower fullness ratio",
                                  value: metrics.lipVolumeRatio,
                                  trailingHint: "Ideal 1:1.6",
                                  icon: Icons.face_retouching_natural_rounded,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 320),
                                child: _MetricRow(
                                  title: "Golden Ratio",
                                  subtitle: "Width vs eye span",
                                  value: metrics.horizontalGoldenRatio.toStringAsFixed(3),
                                  trailingHint: "Ideal 1.618",
                                  icon: Icons.aspect_ratio_rounded,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),

                      // Bottom button: Done (single callback)
                      _Appear(
                        show: _showContent && _displayedText.isNotEmpty,
                        delay: const Duration(milliseconds: 250),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: math.max(0, media.padding.bottom - 12),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: widget.onDone,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Done",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

final class _CircularPortraitCard extends StatelessWidget {
  final FaceMesh mesh;
  final ui.Image? image;
  const _CircularPortraitCard({
    required this.mesh,
    required this.image,
  });
  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double diameter = (w * 0.78).clamp(260.0, 360.0);
    return Center(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x14FFFFFF),
          border: Border.all(color: const Color(0x22FFFFFF), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if(image != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: mesh.imageWidth.toDouble(),
                    height: mesh.imageHeight.toDouble(),
                    child: RawImage(image: image),
                  ),
                )
              else
                const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.22),
                        Colors.black.withOpacity(0.06),
                        Colors.black.withOpacity(0.30),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.10), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AiSnippetCard extends StatelessWidget {
  final String displayedText;
  final bool showSpinner;

  const _AiSnippetCard({
    required this.displayedText,
    required this.showSpinner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0x22FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Quick Insight",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: showSpinner ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayedText.isEmpty ? "Preparing your insight…" : displayedText,
            style: TextStyle(
              color: displayedText.isEmpty ? Colors.white70 : Colors.white,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

final class _MetricRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String trailingHint;
  final IconData icon;
  final bool emphasize;

  const _MetricRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.trailingHint,
    required this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = emphasize ? const Color(0x66FFFFFF) : const Color(0x22FFFFFF);
    final Color bg = emphasize ? const Color(0x22FFFFFF) : const Color(0x14FFFFFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: emphasize ? 22 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                trailingHint,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _Appear extends StatefulWidget {
  final bool show;
  final Duration delay;
  final Widget child;
  const _Appear({
    required this.show,
    required this.delay,
    required this.child,
  });
  @override
  State<_Appear> createState() => _AppearState();
}

final class _AppearState extends State<_Appear> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.show) _arm();
  }

  @override
  void didUpdateWidget(covariant _Appear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !_visible) _arm();
  }

  void _arm() {
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.02),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
