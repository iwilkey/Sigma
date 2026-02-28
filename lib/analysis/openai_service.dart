import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'face_metrics.dart';
//"Beauty is more than math. These insights are based on geometric patterns in portrait photography to help you find your best angles!"

/// ⚠️  Place your OpenAI API key here.
/// For production, move this to a secure backend proxy — never ship a key in a
/// public app binary.
const String _kOpenAIKey = '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';

// ---------------------------------------------------------------------------
// Metric → Positive Label helpers
// ---------------------------------------------------------------------------

String _symmetryLabel(double v) {
  if (v >= 92) return 'Remarkable Symmetry';
  if (v >= 85) return 'Graceful Balance';
  if (v >= 75) return 'Artistic Character';
  return 'Expressive Uniqueness';
}

String _goldenRatioLabel(double v) {
  final double d = (v - 1.618).abs();
  if (d <= 0.05) return 'Classic Proportions';
  if (d <= 0.15) return 'Distinctive Features';
  return 'Bold Structure';
}

String _fiveEyesLabel(double v) {
  final double d = (v - 1.0).abs();
  if (d <= 0.05) return 'Balanced Composition';
  if (d <= 0.12) return 'Captivating Gaze';
  return 'Statement Eyes';
}

String _canthalLabel(double v) {
  if (v >= 3) return 'Uplifted Eye Energy';
  if (v >= 0) return 'Soft Eye Expression';
  return 'Deep, Soulful Eyes';
}

String _thirdsLabel(String ratio) {
  // Parse first two numbers from "1:x:y"
  final parts = ratio.split(':');
  if (parts.length == 3) {
    final m = double.tryParse(parts[1]) ?? 1.0;
    final l = double.tryParse(parts[2]) ?? 1.0;
    if ((m - 1.0).abs() < 0.15 && (l - 1.0).abs() < 0.15) return 'Harmonious Thirds';
    if (l > 1.15) return 'Strong, Defined Lower Face';
    if (m > 1.15) return 'Expressive Mid-Face';
  }
  return 'Balanced Facial Flow';
}

String _lipLabel(String ratio) {
  final parts = ratio.split(':');
  if (parts.length == 2) {
    final r = double.tryParse(parts[1]) ?? 1.0;
    if (r >= 1.5) return 'Full, Voluminous Lips';
    if (r >= 1.1) return 'Naturally Defined Lips';
    return 'Delicate Lip Shape';
  }
  return 'Balanced Lip Volume';
}

// ---------------------------------------------------------------------------

final class OpenAIService {
  OpenAIService._();

  static const String _systemPrompt =
    'You are a professional portrait photographer and aesthetic enthusiast. '
    'Your role is to deliver a warm, uplifting "Portrait Insight" that celebrates '
    'the unique character revealed by the user\'s facial metrics. '
    'CRITICAL RULES: '
    '1. Never use negative or comparative words like "low", "poor", "imperfect", or "asymmetrical". '
    '2. Reframe every metric using the positive label already provided — trust the labels. '
    '3. Structure your response as a Sandwich: '
    '   a) Hook — mention one specific soft detail you actually see in the photo '
    '      (e.g., warm eye colour, expressive brow, or natural smile). '
    '   b) Insight — connect 1-2 of the provided positive labels to a personality or aesthetic trait. '
    '   c) Tip — give one concrete style or lighting suggestion that enhances their natural features. '
    '4. Keep it to 3 sentences maximum. Warm, confident, grounded — not over-the-top flattery.';

  /// Sends the captured face image (BGRA bytes) plus positive labels derived
  /// from [FaceMetrics] to GPT-4o-mini in low-resolution mode.
  static Future<String?> analyzePortrait({
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
  }) async {
    try {
      // 1. Convert BGRA → RGBA
      final Uint8List rgba = _bgraToRgba(bgraPixels, imageWidth, imageHeight, bytesPerRow);

      // 2. Decode → resize preserving aspect ratio → encode JPEG
      final img.Image original = img.Image.fromBytes(
        width: imageWidth,
        height: imageHeight,
        bytes: rgba.buffer,
        format: img.Format.uint8,
        numChannels: 4,
      );
      final img.Image resized = imageWidth >= imageHeight
          ? img.copyResize(original, width: 512)
          : img.copyResize(original, height: 512);
      final String base64Image = base64Encode(img.encodeJpg(resized, quality: 75));

      // 3. Build the user prompt with pre-translated positivity labels
      final String prompt = _buildPrompt(metrics);

      // 4. Call GPT-4o-mini with system + user messages
      final http.Response response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_kOpenAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'max_tokens': 200,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                    'detail': 'low',
                  },
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) return null;
      final Map<String, dynamic> json = jsonDecode(response.body);
      return json['choices']?[0]?['message']?['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------

  static String _buildPrompt(FaceMetrics metrics) {
    final String canthal = metrics.averageCanthalTilt > 0
        ? '+${metrics.averageCanthalTilt.toStringAsFixed(1)}°'
        : '${metrics.averageCanthalTilt.toStringAsFixed(1)}°';

    return '''Here are the Portrait Insight labels for this person:

• Symmetry profile: ${_symmetryLabel(metrics.overallSymmetry)}
• Facial proportions: ${_goldenRatioLabel(metrics.horizontalGoldenRatio)}
• Eye composition: ${_fiveEyesLabel(metrics.fiveEyesRatio)}
• Eye expression (canthal tilt $canthal): ${_canthalLabel(metrics.averageCanthalTilt)}
• Facial structure (thirds ${metrics.facialThirdsRatio}): ${_thirdsLabel(metrics.facialThirdsRatio)}
• Lip character (${metrics.lipVolumeRatio}): ${_lipLabel(metrics.lipVolumeRatio)}

Now write the Portrait Insight following the Sandwich structure described in your instructions.''';
  }

  static Uint8List _bgraToRgba(
      Uint8List bgra, int width, int height, int bytesPerRow) {
    final Uint8List rgba = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int src = y * bytesPerRow + x * 4;
        final int dst = (y * width + x) * 4;
        rgba[dst + 0] = bgra[src + 2];
        rgba[dst + 1] = bgra[src + 1];
        rgba[dst + 2] = bgra[src + 0];
        rgba[dst + 3] = bgra[src + 3];
      }
    }
    return rgba;
  }
}
