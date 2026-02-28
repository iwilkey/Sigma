import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sigma/analysis/face_metrics.dart';
import 'package:sigma/analysis/face_processor.dart';
import 'package:sigma/analysis/openai_service.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/rendering/gfx.dart';
import 'package:sigma/rendering/renderables/blur_dots_background_renderable.dart';

/// Author: Ian Wilkey and Barney Jin
final class ProcessingResultsScreen extends StatefulWidget {
  final FaceMesh mesh;
  final Future<String> resultsFuture;
  final Function(String) onSeeFullResults;
  const ProcessingResultsScreen({
    super.key,
    required this.mesh,
    required this.resultsFuture,
    required this.onSeeFullResults,
  });
  @override
  State<ProcessingResultsScreen> createState() => _ProcessingResultsScreenState();
}

/// Author: Ian Wilkey and Barney Jin
final class _ProcessingResultsScreenState extends State<ProcessingResultsScreen> with SingleTickerProviderStateMixin {

  late final BouncyBlurDotsRenderable _bg;
  late final Ticker _ticker;

  Duration _last = Duration.zero;
  bool _hasResult = false;
  String _fullFirstSentence = '';
  String _typed = '';
  Timer? _typeTimer;
  String? _fullText;
  bool _handledFuture = false;

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
      if (dt.inMicroseconds <= 0) return;
      final double dts = (dt.inMicroseconds / 1e6).clamp(0.0, 1 / 20);
      _bg.tick(dts);
      if (mounted) setState(() {});
    })..start();
    _attachFuture();
  }

  void _attachFuture() {
    if(_handledFuture) return;
    _handledFuture = true;
    widget.resultsFuture.then((text) {
      if(!mounted) return;
      _fullText = text;
      _fullFirstSentence = _firstSentence(text);
      setState(() => _hasResult = true);
      _startTypewriter(delay: const Duration(milliseconds: 250));
    }).catchError((_) {
      if(!mounted) return;
      _fullFirstSentence = "We couldn’t generate results right now.";
      setState(() => _hasResult = true);
      _startTypewriter(delay: const Duration(milliseconds: 250));
    });
  }

  void _startTypewriter({Duration delay = Duration.zero}) {
    _typeTimer?.cancel();
    _typed = '';
    Future<void>.delayed(delay, () {
      if(!mounted) return;
      const Duration tick = Duration(milliseconds: 24); // ~40 chars/sec
      int i = 0;
      _typeTimer = Timer.periodic(tick, (t) {
        if(!mounted) return;
        if(i >= _fullFirstSentence.length) {
          t.cancel();
          return;
        }
        i++;
        setState(() {
          _typed = _fullFirstSentence.substring(0, i);
        });
      });
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final Widget spinner = AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      opacity: _hasResult ? 0.0 : 1.0,
      child: const Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            strokeWidth: 3.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
    final Widget typedText = IgnorePointer(
      ignoring: !_hasResult,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        opacity: _hasResult ? 1.0 : 0.0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _typed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
            ),
          ),
        ),
      ),
    );
    final Widget bottomButton = AnimatedOpacity(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      opacity: _hasResult ? 1.0 : 0.0,
      child: Padding(
        padding: EdgeInsets.only(bottom: math.max(0, media.padding.bottom - 16)),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: _hasResult ? () => widget.onSeeFullResults(_fullText!) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "See Full Results",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        spinner,
                        typedText,
                      ],
                    ),
                  ),
                  bottomButton,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _firstSentence(String text) {
    final String t = text.trim();
    if(t.isEmpty) return "Your results are ready.";
    final String cleaned = t.replaceAll(RegExp(r'\s+'), ' ');
    final Match? m = RegExp(r'[.!?](\s|$)').firstMatch(cleaned);
    if(m == null) {
      const int cap = 140;
      return cleaned.length <= cap ? cleaned : '${cleaned.substring(0, cap).trim()}…';
    }
    final int end = m.end;
    return cleaned.substring(0, end).trim();
  }
}

Future<String> openAiResultsFuture({
  required FaceMesh mesh,
  Duration mockMinDelay = const Duration(milliseconds: 900),
  Duration mockMaxDelay = const Duration(milliseconds: 1800),
  int seed = 7,
}) async {
  if(kMockMode) {
    final int spanMs = (mockMaxDelay - mockMinDelay).inMilliseconds;
    final int jitterMs = spanMs <= 0 ? 0 : (seed * 1103515245 + 12345).abs() % spanMs;
    await Future<void>.delayed(mockMinDelay + Duration(milliseconds: jitterMs));
    return kMockResponse;
  }
  final FaceMetrics? metrics = FaceProcessor.processLandmarks(
    mesh.points,
    imageSize: Size(mesh.imageWidth.toDouble(), mesh.imageHeight.toDouble()),
  );
  if(metrics == null) {
    throw StateError('Face metrics unavailable');
  }
  final bgra = mesh.bgraPixels;
  if(bgra == null) {
    throw StateError('No image pixels available (bgraPixels is null)');
  }
  final String? result = await OpenAIService.analyzePortrait(
    metrics: metrics,
    bgraPixels: bgra,
    imageWidth: mesh.imageWidth,
    imageHeight: mesh.imageHeight,
    bytesPerRow: mesh.bytesPerRow,
  );
  if(result == null || result.trim().isEmpty) {
    throw StateError('OpenAI returned empty response');
  }
  return result.trim();
}

