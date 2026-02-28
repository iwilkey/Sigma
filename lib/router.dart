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
  final Set<String> _expanded = {};

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

  Widget _buildMetricsDashboard(FaceMetrics metrics) {
    final double sym = metrics.overallSymmetry;
    final double ct  = metrics.averageCanthalTilt;
    final double gr  = metrics.horizontalGoldenRatio;
    final double fe  = metrics.fiveEyesRatio;
    final List<String> lp = metrics.lipVolumeRatio.split(':');
    final double lv = lp.length == 2 ? (double.tryParse(lp[1]) ?? 1.0) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAICard(),
        const SizedBox(height: 12),
        _buildMetricCard(
          id: 'sym', title: 'Symmetry Match', description: 'Perceived reflection alignment',
          value: '${sym.toStringAsFixed(1)}%', ideal: '100%', icon: Icons.balance, isHero: true,
          explanation: 'Symmetry measures how closely your left and right halves mirror each other (100% = perfect). '
            '${sym >= 90 ? 'Your ${sym.toStringAsFixed(1)}% is top-tier — faces above 90% are perceived as classically balanced and harmonious.' : sym >= 80 ? 'Your ${sym.toStringAsFixed(1)}% is above the human average of ~85%, reflecting a graceful, natural balance.' : 'Your ${sym.toStringAsFixed(1)}% gives your face expressive uniqueness — distinct character that cameras often love.'}',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          id: 'ct', title: 'Canthal Tilt', description: 'Eye expression and biological energy angle',
          value: '${ct > 0 ? '+' : ''}${ct.toStringAsFixed(1)}°', ideal: '+3° – +5°',
          icon: Icons.remove_red_eye_outlined,
          explanation: 'Canthal tilt is the angle between inner and outer eye corners. Positive = upturned ("hunter eyes"), negative = downturned (softer). Ideal: +3° to +5°. '
            '${ct >= 3 ? 'Your +${ct.toStringAsFixed(1)}° falls in the ideal window — upturned corners read as alert and aesthetically attractive.' : ct >= 0 ? 'Your ${ct.toStringAsFixed(1)}° is neutral-to-positive — an open, approachable expression.' : 'Your ${ct.toStringAsFixed(1)}° gives a deep, soulful eye shape that many find uniquely alluring.'}',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          id: 'thirds', title: 'Facial Thirds', description: 'Upper : Mid : Lower proportions',
          value: metrics.facialThirdsRatio, ideal: '1:1:1', icon: Icons.format_line_spacing,
          explanation: 'The face is divided into three horizontal zones: hairline→brow (upper), brow→nose (mid), nose→chin (lower). Ideal is 1:1:1. '
            'Your ratio is ${metrics.facialThirdsRatio}. Minor variation is completely natural and often adds character — most people show some deviation in at least one zone.',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          id: 'lips', title: 'Lip Volume', description: 'Upper lip vs lower lip fullness',
          value: metrics.lipVolumeRatio, ideal: '1:1.6', icon: Icons.face_retouching_natural,
          explanation: 'Lip volume compares upper to lower lip height. Ideal is 1:1.6 (fuller lower lip, following the golden ratio). Your ratio is ${metrics.lipVolumeRatio}. '
            '${lv >= 1.5 ? 'Your full lower lip is close to ideal — a naturally voluminous, attractive shape.' : lv >= 1.1 ? 'Well-proportioned with a defined lower lip — balanced and elegant.' : 'A refined, even lip shape — delicate and composed.'}',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          id: 'gr', title: 'Golden Ratio', description: 'Horizontal proportion (width vs eye span)',
          value: gr.toStringAsFixed(3), ideal: '1.618', icon: Icons.aspect_ratio,
          explanation: 'The golden ratio (1.618) measures face width relative to eye span. Closer to 1.618 = more classically proportioned. Your score: ${gr.toStringAsFixed(3)}. '
            '${(gr - 1.618).abs() <= 0.05 ? 'Remarkably close to the golden standard — your horizontal proportions are classically ideal.' : (gr - 1.618).abs() <= 0.15 ? 'Within a very natural and attractive range. The golden ratio is guidance, not a rule.' : 'Distinctive proportions — often the foundation of a striking, photogenic look.'}',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          id: 'fe', title: 'Five Eyes Rule', description: 'Face width relative to eye span',
          value: fe.toStringAsFixed(2), ideal: '1.00',
          icon: Icons.panorama_wide_angle_select_rounded,
          explanation: 'The five-eyes rule: face width should equal five eye-widths (1.00 = ideal). Your score: ${fe.toStringAsFixed(2)}. '
            '${(fe - 1.0).abs() <= 0.06 ? 'Near-perfect — your eye spacing and face width are in classical balance.' : fe > 1.06 ? 'Slightly closer-set eyes, creating a focused, intense quality to your gaze.' : 'Slightly wider-set eyes, giving an open, warm, and inviting expression.'}',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAICard() {
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

  Widget _buildMetricCard({
    required String id,
    required String title,
    required String description,
    required String value,
    required String ideal,
    required IconData icon,
    required String explanation,
    bool isHero = false,
  }) {
    final bool isOpen = _expanded.contains(id);
    final Color accent = isHero ? const Color(0xFF00FFCC) : Colors.white;
    return GestureDetector(
       onTap: () => setState(() {
        if (isOpen) { _expanded.remove(id); } else { _expanded.add(id); }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isHero
              ? const Color(0xFF00FFCC).withValues(alpha: isOpen ? 0.14 : 0.08)
              : (isOpen ? const Color(0xFF22222A) : const Color(0xFF1E1E24)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHero
                ? const Color(0xFF00FFCC).withValues(alpha: isOpen ? 0.7 : 0.4)
                : (isOpen ? const Color(0x44FFFFFF) : const Color(0x1AFFFFFF)),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isHero ? const Color(0xFF00FFCC) : Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isHero ? Colors.black : Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(description, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: accent)),
                    const SizedBox(height: 3),
                    Text('Ideal: $ideal', style: const TextStyle(fontSize: 11, color: Colors.white30)),
                  ],
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white30, size: 20),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: isOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
                          const SizedBox(height: 12),
                          Text(explanation,
                            style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.65)),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

