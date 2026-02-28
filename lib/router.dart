import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sigma/capture/capture.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/analysis/face_processor.dart';
import 'package:sigma/analysis/face_metrics.dart';
import 'package:sigma/analysis/openai_service.dart';

final GoRouter SIGMA_ROUTER = GoRouter(
  initialLocation: '/capture',
  routes: [
    GoRoute(
      path: '/capture',
      pageBuilder: (context, state) => sheetPage(
        state: state,
        child: FaceCaptureState(
          onCapturePressed: (final FaceMesh mesh) {
            context.push('/review', extra: mesh);
          },
        ),
      ),
    ),
    GoRoute(
      path: '/review',
      pageBuilder: (context, state) {
        final FaceMesh mesh = state.extra as FaceMesh;
        return sheetPage(
          state: state,
          child: FaceReviewState(mesh: mesh),
        );
      },
    ),
  ],
);

CustomTransitionPage<void> sheetPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation c = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final Animatable<Offset> s = Tween<Offset>(
        begin: const Offset(0, 1.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final Animatable<double> sc = Tween<double>(
        begin: 0.98,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final Animation<double> so = Tween<double>(
        begin: 0.0,
        end: 0.28,
      ).animate(c);
      return Stack(
        children: [
          IgnorePointer(
            child: FadeTransition(
              opacity: so,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          SlideTransition(
            position: c.drive(s),
            child: ScaleTransition(
              scale: c.drive(sc),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

final class FaceReviewState extends StatefulWidget {
  final FaceMesh mesh;
  const FaceReviewState({super.key, required this.mesh});
  @override
  State<FaceReviewState> createState() => _FaceReviewStateState();
}

final class _FaceReviewStateState extends State<FaceReviewState> {
  ui.Image? _image;
  FaceMetrics? _metrics;
  String? _aiResponse;
  bool _aiLoading = true;

  @override
  void initState() {
    super.initState();
    _metrics = FaceProcessor.processLandmarks(
      widget.mesh.points,
      imageSize: Size(widget.mesh.imageWidth.toDouble(), widget.mesh.imageHeight.toDouble()),
    );
    _decodeImage();
    _fetchAIAnalysis();
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

  Future<void> _fetchAIAnalysis() async {
    if (_metrics == null) {
      setState(() => _aiLoading = false);
      return;
    }
    final String? result = await OpenAIService.analyzePortrait(
      metrics: _metrics!,
      bgraPixels: widget.mesh.bgraPixels,
      imageWidth: widget.mesh.imageWidth,
      imageHeight: widget.mesh.imageHeight,
      bytesPerRow: widget.mesh.bytesPerRow,
    );
    if (mounted) setState(() { _aiResponse = result; _aiLoading = false; });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FaceMetrics? metrics = _metrics;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Analysis Results', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
          tooltip: 'Recapture',
        ),
      ),
      body: metrics == null
          ? const Center(child: Text("Error analyzing facial topology.", style: TextStyle(color: Colors.white)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopologyOverlay(metrics),
                  const SizedBox(height: 32),
                  _buildMetricsDashboard(metrics),
                ],
              ),
            ),
    );
  }

  Widget _buildTopologyOverlay(FaceMetrics metrics) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Center(
            child: AspectRatio(
              aspectRatio: widget.mesh.imageWidth / widget.mesh.imageHeight,
              child: _image != null
                  ? RawImage(image: _image, fit: BoxFit.fill)
                  : const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC))),
            ),
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard(FaceMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI Insight card
        _buildAICard(),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Symmetry Match",
          description: "Perceived reflection alignment",
          value: "${metrics.overallSymmetry.toStringAsFixed(1)}%",
          ideal: "100%",
          icon: Icons.balance,
          isHero: true,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Canthal Tilt",
          description: "Eye expression and biological energy angle",
          value: "${metrics.averageCanthalTilt > 0 ? '+' : ''}${metrics.averageCanthalTilt.toStringAsFixed(1)}°",
          ideal: "Slight Positive",
          icon: Icons.remove_red_eye_outlined,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Facial Thirds",
          description: "Upper : Mid : Lower proportions",
          value: metrics.facialThirdsRatio,
          ideal: "1:1:1",
          icon: Icons.format_line_spacing,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Lip Volume",
          description: "Upper lip vs Lower lip fullness ratio",
          value: metrics.lipVolumeRatio,
          ideal: "1:1.6",
          icon: Icons.face_retouching_natural,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Golden Ratio",
          description: "Horizontal proportion (Width vs Eye Span)",
          value: metrics.horizontalGoldenRatio.toStringAsFixed(3),
          ideal: "1.618",
          icon: Icons.aspect_ratio,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAICard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B2FFF).withValues(alpha: 0.15),
            const Color(0xFF00FFCC).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7B2FFF).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2FFF).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Text('✦', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Portrait Analysis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const Spacer(),
              if (_aiLoading)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2FFF)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_aiLoading)
            const Text(
              'GPT-4o is analyzing your portrait...',
              style: TextStyle(color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic),
            )
          else if (_aiResponse != null)
            Text(
              _aiResponse!,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            )
          else
            const Text(
              'Unable to reach GPT-4o. Check your API key and network connection.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String description,
    required String value,
    required String ideal,
    required IconData icon,
    bool isHero = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHero ? const Color(0xFF00FFCC).withValues(alpha: 0.1) : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
           color: isHero ? const Color(0xFF00FFCC).withValues(alpha: 0.5) : const Color(0x1AFFFFFF),
           width: 1
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHero ? const Color(0xFF00FFCC) : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isHero ? Colors.black : Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isHero ? const Color(0xFF00FFCC) : Colors.white)),
              const SizedBox(height: 4),
              Text("Ideal: $ideal", style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          )
        ],
      ),
    );
  }
}
