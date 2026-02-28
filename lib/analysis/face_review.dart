import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sigma/analysis/face_metrics.dart';
import 'package:sigma/analysis/face_processor.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/rendering/gfx.dart';
import 'package:sigma/rendering/renderables/blur_dots_background_renderable.dart';

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
                                  explanation: 'Symmetry measures how closely your left and right halves mirror each other (100% = perfect). '
                                    '${metrics.overallSymmetry >= 90 ? "Your ${metrics.overallSymmetry.toStringAsFixed(1)}% is top-tier — faces above 90% are perceived as classically balanced." : metrics.overallSymmetry >= 80 ? "Your ${metrics.overallSymmetry.toStringAsFixed(1)}% is above the human average of ~85%, reflecting a graceful, natural balance." : "Your ${metrics.overallSymmetry.toStringAsFixed(1)}% gives your face expressive uniqueness — distinct character cameras often love."}',
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
                                  trailingHint: "Ideal +3° – +5°",
                                  icon: Icons.visibility_rounded,
                                  explanation: 'Canthal tilt is the angle between inner and outer eye corners. Positive = upturned, negative = downturned. Ideal: +3° to +5°. '
                                    '${metrics.averageCanthalTilt >= 3 ? "Your +${metrics.averageCanthalTilt.toStringAsFixed(1)}° is ideal — upturned corners read as alert and attractive." : metrics.averageCanthalTilt >= 0 ? "Your ${metrics.averageCanthalTilt.toStringAsFixed(1)}° is neutral-to-positive — an open, approachable expression." : "Your ${metrics.averageCanthalTilt.toStringAsFixed(1)}° gives a deep, soulful eye shape many find uniquely alluring."}',
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
                                  explanation: 'Divided into three zones: hairline→brow (upper), brow→nose (mid), nose→chin (lower). Ideal is 1:1:1. '
                                    'Your ratio is ${metrics.facialThirdsRatio}. Minor variation is normal and often adds character.',
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
                                  explanation: 'Compares upper to lower lip height. Ideal is 1:1.6 (fuller lower lip). Your ratio: ${metrics.lipVolumeRatio}.',
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
                                  explanation: 'The golden ratio (φ = 1.618) measures face width relative to eye span. Your score: ${metrics.horizontalGoldenRatio.toStringAsFixed(3)}. '
                                    '${(metrics.horizontalGoldenRatio - 1.618).abs() <= 0.05 ? "Remarkably close to the golden standard." : (metrics.horizontalGoldenRatio - 1.618).abs() <= 0.15 ? "Within a natural and attractive range." : "Distinctive proportions — often the foundation of a striking look."}',
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
  const _AiSnippetCard({required this.displayedText, required this.showSpinner});
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
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(color: Color(0x22FFFFFF), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            const Text("Quick Insight", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            const Spacer(),
            AnimatedOpacity(
              opacity: showSpinner ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            displayedText.isEmpty ? "Preparing your insight…" : displayedText,
            style: TextStyle(color: displayedText.isEmpty ? Colors.white70 : Colors.white, fontSize: 14, height: 1.55, fontWeight: FontWeight.w500, letterSpacing: -0.1),
          ),
        ],
      ),
    );
  }
}

final class _MetricRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final String value;
  final String trailingHint;
  final IconData icon;
  final String explanation;
  const _MetricRow({required this.title, required this.subtitle, required this.value, required this.trailingHint, required this.icon, required this.explanation});
  @override
  State<_MetricRow> createState() => _MetricRowState();
}

final class _MetricRowState extends State<_MetricRow> {
  bool _isOpen = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isOpen = !_isOpen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isOpen ? const Color(0x1FFFFFFF) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _isOpen ? const Color(0x44FFFFFF) : const Color(0x22FFFFFF), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(12)),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(widget.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.2)),
              ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(widget.value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text(widget.trailingHint, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.1)),
              ]),
              const SizedBox(width: 8),
              AnimatedRotation(turns: _isOpen ? 0.5 : 0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20)),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _isOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Divider(color: Colors.white.withOpacity(0.08), height: 1),
                        const SizedBox(height: 10),
                        Text(widget.explanation, style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.65)),
                      ]),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Appear extends StatefulWidget {
  final bool show;
  final Duration delay;
  final Widget child;
  const _Appear({required this.show, required this.delay, required this.child});
  @override
  State<_Appear> createState() => _AppearState();
}

final class _AppearState extends State<_Appear> {
  bool _visible = false;
  @override
  void initState() { super.initState(); if (widget.show) _arm(); }
  @override
  void didUpdateWidget(covariant _Appear old) { super.didUpdateWidget(old); if (widget.show && !_visible) _arm(); }
  void _arm() { Future<void>.delayed(widget.delay, () { if (!mounted) return; setState(() => _visible = true); }); }
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
