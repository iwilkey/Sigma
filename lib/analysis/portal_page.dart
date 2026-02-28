import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'face_metrics.dart';
import 'face_processor.dart';
import 'face_painter.dart';

class AnalysisPortalPage extends StatefulWidget {
  const AnalysisPortalPage({super.key});

  @override
  State<AnalysisPortalPage> createState() => _AnalysisPortalPageState();
}

class _AnalysisPortalPageState extends State<AnalysisPortalPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  FaceMetrics? _metrics;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isProcessing = true;
        _metrics = null; // reset previously processed metrics
      });
      _processImage();
    }
  }

  Future<void> _processImage() async {
    // Calls the real MediaPipe Google ML Kit points extraction logic
    final resultingMetrics = await FaceProcessor.processImage(_imageFile!.path);
    if (mounted) {
      setState(() {
        _metrics = resultingMetrics;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), // Premium dark mode
      appBar: AppBar(
        title: const Text('Aesthetic Face Analysis', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageBox(),
            const SizedBox(height: 32),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
            else if (_metrics != null)
              _buildMetricsDashboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_imageFile == null)
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_retouching_natural, size: 64, color: Color(0xFF00FFCC)),
                    SizedBox(height: 16),
                    Text(
                      'Tap to Upload Face Photo',
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              else if (_metrics == null) ...[
                Image.file(_imageFile!, fit: BoxFit.contain),
              ] else ...[
                Center(
                  child: AspectRatio(
                    aspectRatio: _metrics!.imageSize.width / _metrics!.imageSize.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(_imageFile!, fit: BoxFit.fill),
                        ),
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: FaceMeshPainter(
                                metrics: _metrics,
                                imageSize: _metrics!.imageSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Analysis Results",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          title: "Symmetry Distance",
          description: "Perceived reflection alignment",
          value: "${_metrics!.overallSymmetry.toStringAsFixed(1)}%",
          ideal: "100%",
          icon: Icons.balance,
          isHero: true,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Golden Ratio (Phidias)",
          description: "Horizontal proportion (Width vs Eye Span)",
          value: _metrics!.horizontalGoldenRatio.toStringAsFixed(3),
          ideal: "1.618",
          icon: Icons.aspect_ratio,
        ),
        const SizedBox(height: 12),
        Row(
           children: [
             Expanded(
               child: _buildVerticalRatioBar(
                 label: "Upper",
                 percent: _metrics!.verticalUpperProportion,
                 color: Colors.blueAccent,
               )
             ),
             const SizedBox(width: 8),
             Expanded(
               child: _buildVerticalRatioBar(
                 label: "Middle",
                 percent: _metrics!.verticalMidProportion,
                 color: Colors.purpleAccent,
               )
             ),
             const SizedBox(width: 8),
             Expanded(
               child: _buildVerticalRatioBar(
                 label: "Lower",
                 percent: _metrics!.verticalLowerProportion,
                 color: const Color(0xFF00FFCC),
               )
             ),
           ],
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          title: "Five Eyes Rule",
          description: "Space between inner corners vs eye width",
          value: _metrics!.fiveEyesRatio.toStringAsFixed(2),
          ideal: "1.00",
          icon: Icons.visibility,
        ),
        const SizedBox(height: 32),
      ],
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

  Widget _buildVerticalRatioBar({required String label, required double percent, required Color color}) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
               "${(percent * 100).toStringAsFixed(0)}%", 
               style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white10,
              color: color,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            )
          ],
        ),
    );
  }
}
