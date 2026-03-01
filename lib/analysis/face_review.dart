// ignore_for_file: deprecated_member_use

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
import 'package:sigma/analysis/face_tier.dart';
import 'package:sigma/share/share_sheet.dart';

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
      blurSigma: 50,
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

  void _openShareSheet() {
    final FaceMetrics? m = _metrics;
    if (m == null) return;
    ShareSheet.show(
      context,
      metrics: m,
      bgraPixels: widget.mesh.bgraPixels!,
      imageWidth: widget.mesh.imageWidth,
      imageHeight: widget.mesh.imageHeight,
      bytesPerRow: widget.mesh.bytesPerRow,
      aiInsight: _displayedText,
    );
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
                              Stack(children: [
                                Positioned(
                                  top: MediaQuery.of(context).padding.top - 48,
                                  right: 0,
                                  child: AnimatedOpacity(
                                    opacity: _metrics != null ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 400),
                                    child: GestureDetector(
                                      onTap: _openShareSheet,
                                      child: Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                                        ),
                                        child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                _Appear(
                                  show: _showContent,
                                  delay: const Duration(milliseconds: 0),
                                  child: _CircularPortraitCard(
                                    mesh: widget.mesh,
                                    image: _image,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 14),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 60),
                                child: _TierBadgeCard(metrics: metrics),
                              ),
                              const SizedBox(height: 10),
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
                                  subtitle: "Reflection Alignment",
                                  value: "${metrics.overallSymmetry.toStringAsFixed(1)}%",
                                  trailingHint: "Ideal 100%",
                                  icon: Icons.balance_rounded,
                                  explanation: 'Symmetry measures how closely your left and right halves mirror each other (100% = perfect). '
                                    '${metrics.overallSymmetry >= 90 ? "Your ${metrics.overallSymmetry.toStringAsFixed(1)}% is top-tier; faces above 90% are perceived as classically balanced." : metrics.overallSymmetry >= 80 ? "Your ${metrics.overallSymmetry.toStringAsFixed(1)}% is above the human average of ~85%, reflecting a graceful, natural balance." : "Your ${metrics.overallSymmetry.toStringAsFixed(1)}% gives your face expressive uniqueness; distinct character cameras often love."}',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 200),
                                child: _MetricRow(
                                  title: "Canthal Tilt",
                                  subtitle: "Eye Expression Angle",
                                  value:
                                      "${metrics.averageCanthalTilt > 0 ? '+' : ''}${metrics.averageCanthalTilt.toStringAsFixed(1)}°",
                                  trailingHint: "Ideal +3° to +5°",
                                  icon: Icons.visibility_rounded,
                                  explanation: 'Canthal tilt is the angle between inner and outer eye corners. Positive = upturned, negative = downturned. Ideal: +3° to +5°. '
                                    '${metrics.averageCanthalTilt >= 3 ? "Your +${metrics.averageCanthalTilt.toStringAsFixed(1)}° is ideal; upturned corners read as alert and attractive." : metrics.averageCanthalTilt >= 0 ? "Your ${metrics.averageCanthalTilt.toStringAsFixed(1)}° is neutral-to-positive; an open, approachable expression." : "Your ${metrics.averageCanthalTilt.toStringAsFixed(1)}° gives a deep, soulful eye shape many find uniquely alluring."}',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 240),
                                child: _MetricRow(
                                  title: "Facial Thirds",
                                  subtitle: "Facial Proportions",
                                  value: metrics.facialThirdsRatio,
                                  trailingHint: "Ideal 1:1:1",
                                  icon: Icons.view_agenda_rounded,
                                  explanation: 'Divided into three zones: hairline to brow (upper), brow to nose (mid), nose to chin (lower). Ideal is 1:1:1. '
                                    'Your ratio is ${metrics.facialThirdsRatio}. Minor variation is normal and often adds character.',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Appear(
                                show: _showContent,
                                delay: const Duration(milliseconds: 280),
                                child: _MetricRow(
                                  title: "Lip Volume",
                                  subtitle: "Fullness Ratio",
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
                                  subtitle: "Width vs Eye Span",
                                  value: metrics.horizontalGoldenRatio.toStringAsFixed(3),
                                  trailingHint: "Ideal 1.618",
                                  icon: Icons.aspect_ratio_rounded,
                                  explanation: 'The golden ratio (φ = 1.618) measures face width relative to eye span. Your score: ${metrics.horizontalGoldenRatio.toStringAsFixed(3)}. '
                                    '${(metrics.horizontalGoldenRatio - 1.618).abs() <= 0.05 ? "Remarkably close to the golden standard." : (metrics.horizontalGoldenRatio - 1.618).abs() <= 0.15 ? "Within a natural and attractive range." : "Distinctive proportions; often the foundation of a striking look."}',
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      _Appear(
                        show: _showContent && _displayedText.isNotEmpty,
                        delay: const Duration(milliseconds: 250),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: math.max(0, media.padding.bottom - 12),
                          ),
                          child: Container(
                            color: Colors.transparent,  
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: widget.onDone,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 1),
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
              width: 48, height: 48,
              decoration: const BoxDecoration(color: Color(0x22FFFFFF), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.auto_awesome_rounded, size: 24, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            const Text("Overall", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            const Spacer(),
            AnimatedOpacity(
              opacity: showSpinner ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            displayedText.isEmpty ? "Preparing your insights..." : displayedText,
            style: TextStyle(color: displayedText.isEmpty ? Colors.white70 : Colors.white, fontSize: 16, height: 1.3, fontWeight: FontWeight.bold, letterSpacing: -0.1),
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
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  width: 120, // keeps every row's right side identical
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        widget.trailingHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.1),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(
                    child: AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _isOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(color: Colors.white.withOpacity(0.08), height: 1),
                          const SizedBox(height: 12),
                          _MetricDetailsPanel(
                            title: widget.title,
                            subtitle: widget.subtitle,
                            valueText: widget.value,
                            trailingHint: widget.trailingHint,
                            icon: widget.icon,
                            explanation: widget.explanation,
                          ),
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

class _MetricDetailsPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String valueText;
  final String trailingHint;
  final IconData icon;
  final String explanation;

  const _MetricDetailsPanel({
    required this.title,
    required this.subtitle,
    required this.valueText,
    required this.trailingHint,
    required this.icon,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final _MetricVisualSpec spec = _MetricVisualSpec.forMetric(title, valueText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top "header pill" row
        Row(
          children: [
            _PillIcon(icon: icon),
            const SizedBox(width: 10),
            const Text(
              "What you’re looking at",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                fontSize: 14.5,
              ),
            ),
            const Spacer(),
            _HintChip(text: trailingHint),
          ],
        ),
        const SizedBox(height: 12),

        // Gauge (when numeric)
        if (spec.kind == _MetricVisualKind.numeric) ...[
          _MetricGauge(spec: spec),
          const SizedBox(height: 12),
          _StackUpRow(spec: spec),
          const SizedBox(height: 10),
        ] else if (spec.kind == _MetricVisualKind.thirds) ...[
          _ThirdsVisualization(spec: spec),
          const SizedBox(height: 12),
        ],

        // Explanation card
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _SectionDot(),
                const SizedBox(width: 8),
                const Text(
                  "Plain-English explanation",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    fontSize: 14.5,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 14.5,
                  color: Colors.white.withOpacity(0.70),
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.05,
                ),
              ),
              const SizedBox(height: 12),

              // "Quick takeaway" line (short, friendly)
              _MiniCallout(
                label: "Quick takeaway",
                text: spec.takeaway,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricGauge extends StatelessWidget {
  final _MetricVisualSpec spec;
  const _MetricGauge({required this.spec});

  @override
  Widget build(BuildContext context) {
    final double p = spec.progress01.clamp(0.0, 1.0);
    final double idealA = spec.idealStart01.clamp(0.0, 1.0);
    final double idealB = spec.idealEnd01.clamp(0.0, 1.0);
    final double idealL = math.min(idealA, idealB);
    final double idealR = math.max(idealA, idealB);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _SectionDot(),
            const SizedBox(width: 8),
            const Text(
              "Where you land",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                fontSize: 14.5,
              ),
            ),
            const Spacer(),
            Text(
              spec.valueLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                fontSize: 15,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, c) {
              final double w = c.maxWidth;

              const double barH = 10;
              const double markerD = 14;

              // Center the bar on this y so the marker can be centered on the bar line.
              const double barCenterY = 18;

              final double idealX = idealL * w;
              final double idealW = (idealR - idealL) * w;

              // Marker should be centered at p*w.
              final double markerCenterX = p * w;
              final double markerLeft = (markerCenterX - markerD / 2).clamp(0.0, w - markerD);

              return SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    // Track
                    Positioned(
                      left: 0,
                      right: 0,
                      top: barCenterY - barH / 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: barH,
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                    ),

                    // Ideal band
                    Positioned(
                      left: idealX,
                      top: barCenterY - barH / 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: idealW.clamp(6, w),
                          height: barH,
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                    ),

                    // Marker
                    Positioned(
                      left: markerLeft,
                      top: barCenterY - markerD / 2,
                      child: Container(
                        width: markerD,
                        height: markerD,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.55),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                      ),
                    ),

                    // Sub labels
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Text(
                        spec.minLabel,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text(
                        spec.maxLabel,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _TinyBadge(text: "IDEAL ZONE"),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.idealLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackUpRow extends StatelessWidget {
  final _MetricVisualSpec spec;
  const _StackUpRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    final _MetricVerdict v = spec.verdict;

    return Row(
      children: [
        Expanded(
          child: _MiniMetricTile(
            title: "Status",
            value: v.label,
            icon: v.icon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniMetricTile(
            title: "Ideal",
            value: spec.deltaLabel,
            icon: Icons.track_changes_rounded,
          ),
        ),
      ],
    );
  }
}

class _ThirdsVisualization extends StatelessWidget {
  final _MetricVisualSpec spec;
  const _ThirdsVisualization({required this.spec});

  @override
  Widget build(BuildContext context) {
    final List<double> parts = spec.thirdsParts;
    final double sum = parts.fold(0.0, (a, b) => a + b).clamp(1e-6, 1e9);
    final List<double> norm = parts.map((p) => (p / sum).clamp(0.0, 1.0)).toList();

    Widget bar(double f, String label) {
      return Expanded(
        flex: (1000 * f).clamp(1, 1000).toInt(),
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
        ),
      );
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _SectionDot(),
            const SizedBox(width: 8),
            const Text(
              "Proportion map",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                fontSize: 14.5,
              ),
            ),
            const Spacer(),
            Text(
              spec.valueLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                fontSize: 14.5,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // A clean, monochrome “thirds” bar
          Row(
            children: [
              bar(norm[0], "Upper"),
              const SizedBox(width: 6),
              bar(norm[1], "Mid"),
              const SizedBox(width: 6),
              bar(norm[2], "Lower"),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              _TinyBadge(text: "IDEAL"),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Close to 1:1:1 reads as balanced on camera. Small variation is normal and often looks distinctive.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Visual model + helpers ----------

enum _MetricVisualKind { numeric, thirds, unknown }

class _MetricVerdict {
  final String label;
  final IconData icon;
  const _MetricVerdict(this.label, this.icon);
}

class _MetricVisualSpec {
  final _MetricVisualKind kind;

  // Numeric mode
  final double? value;
  final double min;
  final double max;
  final double idealMin;
  final double idealMax;
  final String unit; // like %, °, ""
  final bool higherIsBetter;

  // Thirds mode
  final List<double> thirdsParts;

  final String valueLabel;
  final String minLabel;
  final String maxLabel;
  final String idealLabel;
  final String takeaway;

  const _MetricVisualSpec._({
    required this.kind,
    required this.value,
    required this.min,
    required this.max,
    required this.idealMin,
    required this.idealMax,
    required this.unit,
    required this.higherIsBetter,
    required this.thirdsParts,
    required this.valueLabel,
    required this.minLabel,
    required this.maxLabel,
    required this.idealLabel,
    required this.takeaway,
  });

  double get progress01 {
    final v = value ?? min;
    return ((v - min) / (max - min)).clamp(0.0, 1.0);
  }

  double get idealStart01 => ((idealMin - min) / (max - min)).clamp(0.0, 1.0);
  double get idealEnd01 => ((idealMax - min) / (max - min)).clamp(0.0, 1.0);

  _MetricVerdict get verdict {
    if (kind != _MetricVisualKind.numeric || value == null) {
      return const _MetricVerdict("Readable", Icons.auto_awesome_rounded);
    }
    final double v = value!;
    final bool inIdeal = v >= idealMin && v <= idealMax;

    if (inIdeal) {
      return const _MetricVerdict("In Ideal Range", Icons.verified_rounded);
    }

    // outside ideal: decide “close” vs “far”
    final double dist = (v < idealMin) ? (idealMin - v) : (v - idealMax);
    final double band = (idealMax - idealMin).abs().clamp(1e-6, 1e9);
    final bool close = dist <= band * 1.25;

    if (close) {
      return const _MetricVerdict("Close to Ideal", Icons.insights_rounded);
    } else {
      return const _MetricVerdict("Distinctive", Icons.star_rounded);
    }
  }

  String get deltaLabel {
    if (kind != _MetricVisualKind.numeric || value == null) return "—";
    final double v = value!;
    final bool inIdeal = v >= idealMin && v <= idealMax;
    if (inIdeal) return "Right On";

    final double target = (v < idealMin) ? idealMin : idealMax;
    final double d = (v - target).abs();
    final String dStr = unit.isEmpty ? d.toStringAsFixed(2) : d.toStringAsFixed(1);
    return "±$dStr$unit";
  }

  static _MetricVisualSpec forMetric(String title, String valueText) {
    double? parseFirstNumber(String s) {
      final m = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(s);
      if (m == null) return null;
      return double.tryParse(m.group(0)!);
    }

    List<double> parseThirds(String s) {
      // expects something like "1.0:0.9:1.1" or "1:1:1"
      final parts = s.split(':').map((e) => double.tryParse(e.trim())).toList();
      if (parts.length == 3 && parts.every((x) => x != null)) {
        return parts.map((x) => x!).toList();
      }
      return const [1, 1, 1];
    }

    final String t = title.toLowerCase();

    // Defaults: safe numeric lane if we can parse a number.
    final double? v = parseFirstNumber(valueText);

    if(t.contains("facial thirds")) {
      final thirds = parseThirds(valueText);
      return _MetricVisualSpec._(
        kind: _MetricVisualKind.thirds,
        value: null,
        min: 0,
        max: 1,
        idealMin: 0,
        idealMax: 1,
        unit: "",
        higherIsBetter: true,
        thirdsParts: thirds,
        valueLabel: valueText,
        minLabel: "",
        maxLabel: "",
        idealLabel: "Ideal ≈ 1:1:1",
        takeaway: "These ratios are about balance—small variation is normal and often photogenic.",
      );
    }

    // Metric-specific “beautiful” ranges
    // Symmetry
    if (t.contains("symmetry")) {
      return _MetricVisualSpec._(
        kind: _MetricVisualKind.numeric,
        value: v,
        min: 60,
        max: 100,
        idealMin: 85,
        idealMax: 100,
        unit: "%",
        higherIsBetter: true,
        thirdsParts: const [1, 1, 1],
        valueLabel: valueText,
        minLabel: "60%",
        maxLabel: "100%",
        idealLabel: "85 to 100 percent reads as very balanced",
        takeaway: "This is a balance score. Above the mid 80s usually reads strong on camera.",
      );
    }

    if (t.contains("canthal")) {
      return _MetricVisualSpec._(
        kind: _MetricVisualKind.numeric,
        value: v,
        min: -8,
        max: 8,
        idealMin: 2,
        idealMax: 6,
        unit: "deg",
        higherIsBetter: true,
        thirdsParts: const [1, 1, 1],
        valueLabel: valueText,
        minLabel: "-8",
        maxLabel: "+8",
        idealLabel: "Plus 2 to plus 6 deg is a common flattering range",
        takeaway: "Slightly positive tilt tends to read alert and friendly. Neutral is still totally fine.",
      );
    }

    if (t.contains("golden ratio")) {
      return _MetricVisualSpec._(
        kind: _MetricVisualKind.numeric,
        value: v,
        min: 1.20,
        max: 2.00,
        idealMin: 1.52,
        idealMax: 1.72,
        unit: "",
        higherIsBetter: true,
        thirdsParts: const [1, 1, 1],
        valueLabel: valueText,
        minLabel: "1.20",
        maxLabel: "2.00",
        idealLabel: "About 1.52 to 1.72 is a typical harmonic band",
        takeaway: "This is just a proportion check. Many great faces sit outside the textbook number.",
      );
    }

    if (t.contains("lip volume")) {
      return _MetricVisualSpec._(
        kind: _MetricVisualKind.numeric,
        value: v,
        min: 0.8,
        max: 2.2,
        idealMin: 1.30,
        idealMax: 1.90,
        unit: "",
        higherIsBetter: true,
        thirdsParts: const [1, 1, 1],
        valueLabel: valueText,
        minLabel: "0.8",
        maxLabel: "2.2",
        idealLabel: "About 1.3 to 1.9 is a common natural range",
        takeaway: "A slightly fuller lower lip is common. The goal is overall balance, not a perfect number.",
      );
    }

    // Fallback: numeric if parseable, otherwise unknown
    if (v != null) {
      return _MetricVisualSpec._(
        kind: _MetricVisualKind.numeric,
        value: v,
        min: v - 1,
        max: v + 1,
        idealMin: v - 0.25,
        idealMax: v + 0.25,
        unit: "",
        higherIsBetter: true,
        thirdsParts: const [1, 1, 1],
        valueLabel: valueText,
        minLabel: "low",
        maxLabel: "high",
        idealLabel: "ideal band shown for context",
        takeaway: "Use this as a “shape descriptor.” Your range is meant to explain structure—not label you.",
      );
    }

    return _MetricVisualSpec._(
      kind: _MetricVisualKind.unknown,
      value: null,
      min: 0,
      max: 1,
      idealMin: 0,
      idealMax: 1,
      unit: "",
      higherIsBetter: true,
      thirdsParts: const [1, 1, 1],
      valueLabel: valueText,
      minLabel: "",
      maxLabel: "",
      idealLabel: "",
      takeaway: "This describes a visual relationship—think of it as “what your face is doing,” not “good vs bad.”",
    );
  }
}

// ---------- Small UI atoms (monochrome, rounded, pretty) ----------

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: child,
    );
  }
}

class _PillIcon extends StatelessWidget {
  final IconData icon;
  const _PillIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String text;
  const _HintChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  const _TinyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SectionDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 8,
            offset: const Offset(0, 5),
          )
        ],
      ),
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniMetricTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: -0.2,
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

class _MiniCallout extends StatelessWidget {
  final String label;
  final String text;

  const _MiniCallout({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.05,
                ),
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
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

// ── Tier Badge Card ───────────────────────────────────────────────────────────

final class _TierBadgeCard extends StatelessWidget {
  final FaceMetrics metrics;
  const _TierBadgeCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final FaceTierResult result = FaceTierCalculator.compute(metrics);
    final FaceTier tier = result.tier;
    final Color tierColor = tier.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: letter + score + headline ───────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Big tier letter
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tierColor.withOpacity(0.5), width: 1.4),
                ),
                child: Center(
                  child: Text(
                    tier.letter,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tier.subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Score badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    result.totalScore.toStringAsFixed(1),
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      color: tierColor.withOpacity(0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ── Mini metric bar breakdown ─────────────────────────────────────
          _TierMetricBars(result: result, tierColor: tierColor),
        ],
      ),
    );
  }
}

final class _TierMetricBars extends StatelessWidget {
  final FaceTierResult result;
  final Color tierColor;
  const _TierMetricBars({required this.result, required this.tierColor});

  @override
  Widget build(BuildContext context) {
    final List<(String, double)> bars = [
      ('Symmetry',    result.symmetryScore),
      ('Canthal',     result.canthalScore),
      ('Golden φ',    result.goldenScore),
      ('Thirds',      result.thirdsScore),
      ('Lips',        result.lipScore),
    ];
    return Column(
      children: bars.map((item) {
        final String label = item.$1;
        final double score = item.$2;
        final double frac  = (score / 20.0).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Container(
                        height: 6,
                        width: c.maxWidth * frac,
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  score.toStringAsFixed(1),
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
