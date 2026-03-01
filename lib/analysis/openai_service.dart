import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'face_metrics.dart';

String get _kOpenAIKey => dotenv.env['OPENAI_API_KEY'] ?? 'sk-placeholder';

const bool kMockMode = false;

const String kMockResponse =
  'The clarity in your eyes immediately draws the viewer in — there is a quiet '
  'confidence in your gaze that the camera captures naturally. Your Graceful Balance '
  'and Captivating Gaze give your face a quietly magnetic quality that feels effortlessly '
  'composed; side-lighting from the left would beautifully define the natural structure '
  'of your brow and cheekbone.';

String _symmetryLabel(double v) {
  if(v >= 90) return 'Classical Timelessness';       
  if(v >= 80) return 'Natural Harmony';              
  return 'Contemporary Photographic Appeal';          
}

String _goldenRatioLabel(double v) {
  final double d = (v - 1.618).abs();
  if(d <= 0.04) return 'Geometric Perfection';                
  if(d <= 0.12) return 'Classical Timelessness';              
  return 'Contemporary Photographic Appeal';                   
}

String _fiveEyesLabel(double v) {
  final double d = (v - 1.0).abs();
  if(d <= 0.04) return 'Geometric Perfection';                
  if(d <= 0.10) return 'Classical Timelessness';              
  return 'Contemporary Photographic Appeal';                   
}

String _canthalLabel(double v) {
  if(v >= 3 && v <= 6) return 'Classical Timelessness';       
  if(v > 0)            return 'Natural Radiance';             
  return 'Contemporary Photographic Appeal';                   
}

String _thirdsLabel(String ratio) {
  final List<String> parts = ratio.split(':');
  if(parts.length == 3) {
    final List<double> vals = parts.map((s) => double.tryParse(s) ?? 1.0).toList();
    final double maxDev = vals.map((v) => (v - 1.0).abs()).reduce((a, b) => a > b ? a : b);
    if(maxDev <= 0.08) return 'Classical Timelessness';       
    if(maxDev <= 0.20) return 'Natural Harmony';              
  }
  return 'Contemporary Photographic Appeal';                   
}

String _lipLabel(String ratio) {
  final List<String> parts = ratio.split(':');
  if(parts.length == 2) {
    final double r = double.tryParse(parts[1]) ?? 1.0;
    if((r - 1.6).abs() <= 0.1) return 'Geometric Perfection';    
    if(r >= 1.3)               return 'Classical Timelessness';   
    return 'Contemporary Photographic Appeal';                     
  }
  return 'Natural Harmony';
}

final class OpenAIService {

  OpenAIService._();

  static const String _systemPrompt =
    'You are a portrait artist and aesthetic historian. '
    'You use Neoclassical Canons (Roman golden proportions, Leonardo\'s facial thirds, '
    'the five-eyes rule) as your mathematical baseline, and GPT-4o-mini\'s vision '
    'to interpret Modern Aesthetic Deviations as unique beauty assets — never flaws. '
    'For each Portrait Insight, follow the Sandwich: '
    '(1) Hook — name one specific feature you actually see in the photo (hair, eye colour, skin tone); '
    '(2) Harmony — reference the dominant Portrait Harmony tag and explain what aesthetic tradition '
    '    it places this person in (e.g. "Your Classical Timelessness places you in the tradition of '
    '    Renaissance portraiture" or "Your Contemporary Photographic Appeal is exactly what makes '
    '    modern editorial photography striking"); '
    '(3) Tip — one style, hair or facial hair, or makeup suggestion that amplifies their natural character. '
    'Never say "low", "poor", "off", or "asymmetrical". Max 3 sentences. '
    'IMPORTANT: Do NOT write section headers or bold labels like **Hook**, **Harmony**, or **Tip** — write flowing prose only.';

  static Future<String?> analyzePortrait({
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
  }) async {
    if(kMockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return kMockResponse;
    }
    try {
      final Uint8List rgba = _bgraToRgba(bgraPixels, imageWidth, imageHeight, bytesPerRow);
      final img.Image original = img.Image.fromBytes(
        width: imageWidth,
        height: imageHeight,
        bytes: rgba.buffer,
        format: img.Format.uint8,
        numChannels: 4,
      );
      final img.Image resized = original.width >= original.height
        ? img.copyResize(original, width: 512)
        : img.copyResize(original, height: 512);
      final String base64Image = base64Encode(img.encodeJpg(resized, quality: 75));
      final String prompt = _buildPrompt(metrics);
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
      if(response.statusCode != 200) return "Connection error. Please try again.";
      final Map<String, dynamic> json = jsonDecode(response.body);
      return json['choices']?[0]?['message']?['content'] as String?;
    } catch (e) {
      return "An error occurred during analysis.";
    }
  }

  static String _buildPrompt(FaceMetrics metrics) {
    final String canthal = metrics.averageCanthalTilt > 0
        ? '+${metrics.averageCanthalTilt.toStringAsFixed(1)}°'
        : '${metrics.averageCanthalTilt.toStringAsFixed(1)}°';
    final List<String> harmonies = [
      _symmetryLabel(metrics.overallSymmetry),
      _goldenRatioLabel(metrics.horizontalGoldenRatio),
      _fiveEyesLabel(metrics.fiveEyesRatio),
      _canthalLabel(metrics.averageCanthalTilt),
      _thirdsLabel(metrics.facialThirdsRatio),
      _lipLabel(metrics.lipVolumeRatio),
    ];
    int classicalPoints = harmonies.where((h) => h == 'Classical Timelessness' || h == 'Geometric Perfection' || h == 'Natural Harmony').length;
    final String dominantHarmony = (classicalPoints >= 4) 
      ? 'Classical Timelessness' 
      : 'Contemporary Photographic Appeal';
    return '''Sigma Portrait Harmony Analysis:

Dominant Style Anchor: $dominantHarmony

Data Set:
• Symmetry: ${metrics.overallSymmetry.toStringAsFixed(1)}% (${_symmetryLabel(metrics.overallSymmetry)})
• Golden Ratio: ${metrics.horizontalGoldenRatio.toStringAsFixed(3)} (${_goldenRatioLabel(metrics.horizontalGoldenRatio)})
• Five Eyes: ${metrics.fiveEyesRatio.toStringAsFixed(2)} (${_fiveEyesLabel(metrics.fiveEyesRatio)})
• Canthal Tilt: $canthal (${_canthalLabel(metrics.averageCanthalTilt)})
• Facial Thirds: ${metrics.facialThirdsRatio} (${_thirdsLabel(metrics.facialThirdsRatio)})
• Lip Volume: ${metrics.lipVolumeRatio} (${_lipLabel(metrics.lipVolumeRatio)})

Following the Sandwich structure, synthesize these metrics into a supportive Portrait Insight.''';
  }

  static Uint8List _bgraToRgba(Uint8List bgra, int width, int height, int bytesPerRow) {
    final Uint8List rgba = Uint8List(width * height * 4);
    for(int y = 0; y < height; y++) {
      for(int x = 0; x < width; x++) {
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
