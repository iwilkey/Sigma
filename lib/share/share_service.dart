import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:sigma/analysis/face_metrics.dart';

/// Author: Ian Wilkey and Barney Jin
///
/// Builds a branded Sigma PDF portrait report and surfaces it
/// via the native iOS share sheet (Mail, AirDrop, Messages, etc.).
final class ShareService {
  ShareService._();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Generates a PDF from [metrics] + the BGRA portrait pixels and opens the
  /// native iOS share sheet.  If [email] is provided the sheet pre-populates
  /// the To: field when the user picks the Mail app.
  static Future<void> shareReport({
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
    required String aiInsight,
    String? email,
  }) async {
    final Uint8List pdfBytes = await _buildPdf(
      metrics: metrics,
      bgraPixels: bgraPixels,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      bytesPerRow: bytesPerRow,
      aiInsight: aiInsight,
    );

    final Directory tmp = await getTemporaryDirectory();
    final File file = File('${tmp.path}/sigma_portrait_report.pdf');
    await file.writeAsBytes(pdfBytes);

    final XFile xFile = XFile(file.path, mimeType: 'application/pdf', name: 'Sigma Portrait Report.pdf');

    // Build a subject/text for the share sheet. If the user specified an email
    // address we pass it as the subject so Mail picks it up automatically.
    await Share.shareXFiles(
      [xFile],
      subject: 'My Sigma Portrait Harmony Report',
      text: email != null && email.isNotEmpty ? 'To: $email' : null,
    );
  }

  // ── PDF generation ──────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
    required String aiInsight,
  }) async {
    // 1. Convert portrait BGRA → JPEG for embedding
    final Uint8List jpegBytes = _bgraToJpeg(bgraPixels, imageWidth, imageHeight, bytesPerRow);
    final pw.MemoryImage portraitImg = pw.MemoryImage(jpegBytes);

    // 2. Load the Sigma icon as a PDF image (bundled asset)
    pw.MemoryImage? logoImg;
    try {
      final ByteData data = await rootBundle.load('assets/icon.png');
      logoImg = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Icon missing — skip gracefully
    }

    // 3. Colours (dark theme matching the app)
    const PdfColor bg          = PdfColor.fromInt(0xFF0A0A0F);
    const PdfColor surface     = PdfColor.fromInt(0xFF1A1A24);
    const PdfColor accent      = PdfColor.fromInt(0xFF00FFCC);
    const PdfColor white       = PdfColor.fromInt(0xFFFFFFFF);
    const PdfColor white70     = PdfColor.fromInt(0xB3FFFFFF);
    const PdfColor white40     = PdfColor.fromInt(0x66FFFFFF);

    // 4. Build metric rows
    final List<_MetricData> metricItems = [
      _MetricData('Symmetry Match',  '${metrics.overallSymmetry.toStringAsFixed(1)}%', 'Ideal 100%'),
      _MetricData('Canthal Tilt',    '${metrics.averageCanthalTilt > 0 ? '+' : ''}${metrics.averageCanthalTilt.toStringAsFixed(1)}°', 'Ideal +3° – +5°'),
      _MetricData('Facial Thirds',   metrics.facialThirdsRatio,  'Ideal 1:1:1'),
      _MetricData('Lip Volume',      metrics.lipVolumeRatio,     'Ideal 1:1.6'),
      _MetricData('Golden Ratio',    metrics.horizontalGoldenRatio.toStringAsFixed(3), 'Ideal 1.618'),
    ];

    final pw.Document pdf = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (pw.Context ctx) {
        return pw.Container(
          color: bg,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [

              // ── Header bar ──────────────────────────────────────────────────
              pw.Container(
                color: surface,
                padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(children: [
                      if (logoImg != null) ...[
                        pw.Container(
                          width: 32, height: 32,
                          child: pw.Image(logoImg),
                        ),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Text(
                        'Σ SIGMA',
                        style: pw.TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ]),
                    pw.Text(
                      'Portrait Harmony Report',
                      style: pw.TextStyle(color: white70, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────────────────
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [

                      // Left column: portrait + AI insight
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            // Portrait photo (circular-ish via ClipOval approximation)
                            pw.Container(
                              height: 230,
                              decoration: pw.BoxDecoration(
                                color: surface,
                                borderRadius: pw.BorderRadius.circular(16),
                                border: pw.Border.all(color: white40, width: 0.5),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 16,
                                verticalRadius: 16,
                                child: pw.Image(portraitImg, fit: pw.BoxFit.cover),
                              ),
                            ),
                            pw.SizedBox(height: 18),
                            // AI Insight card
                            pw.Container(
                              padding: const pw.EdgeInsets.all(16),
                              decoration: pw.BoxDecoration(
                                color: surface,
                                borderRadius: pw.BorderRadius.circular(12),
                                border: pw.Border.all(color: white40, width: 0.5),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(children: [
                                    pw.Container(
                                      width: 8, height: 8,
                                      decoration: const pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
                                    ),
                                    pw.SizedBox(width: 6),
                                    pw.Text('AI Quick Insight', style: pw.TextStyle(color: accent, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                                  ]),
                                  pw.SizedBox(height: 10),
                                  pw.Text(
                                    aiInsight.isEmpty ? 'No AI insight available.' : aiInsight,
                                    style: pw.TextStyle(color: white70, fontSize: 10, lineSpacing: 3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(width: 24),

                      // Right column: metrics table
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Text(
                              'HARMONY METRICS',
                              style: pw.TextStyle(color: accent, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
                            ),
                            pw.SizedBox(height: 12),
                            ...metricItems.map((m) => _buildMetricRow(m, surface, white, white70, white40, accent)),
                            pw.SizedBox(height: 24),
                            // Divider
                            pw.Divider(color: white40, thickness: 0.4),
                            pw.SizedBox(height: 16),
                            // Dominant harmony label
                            _buildHarmonyBadge(metrics, surface, accent, white, white70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer ──────────────────────────────────────────────────────
              pw.Container(
                color: surface,
                padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Generated by Sigma — HackIllinois 2026',
                      style: pw.TextStyle(color: white40, fontSize: 8)),
                    pw.Text('Barney Jin & Ian Wilkey',
                      style: pw.TextStyle(color: white40, fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ));

    return pdf.save();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildMetricRow(
    _MetricData m,
    PdfColor surface,
    PdfColor white,
    PdfColor white70,
    PdfColor white40,
    PdfColor accent,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: white40, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(m.title, style: pw.TextStyle(color: white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(m.ideal, style: pw.TextStyle(color: white40, fontSize: 9)),
          ]),
          pw.Text(m.value, style: pw.TextStyle(color: accent, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildHarmonyBadge(
    FaceMetrics metrics,
    PdfColor surface,
    PdfColor accent,
    PdfColor white,
    PdfColor white70,
  ) {
    final double sym = metrics.overallSymmetry;
    final double d = (metrics.horizontalGoldenRatio - 1.618).abs();
    int classical = 0;
    if (sym >= 80) classical++;
    if (d <= 0.12) classical++;
    if (metrics.averageCanthalTilt > 0) classical++;
    final String label = classical >= 2 ? 'Classical Timelessness' : 'Contemporary Photographic Appeal';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: accent, width: 0.8),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('DOMINANT STYLE', style: pw.TextStyle(color: accent, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
        pw.SizedBox(height: 6),
        pw.Text(label, style: pw.TextStyle(color: white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Based on Portrait Harmony Framework™', style: pw.TextStyle(color: white70, fontSize: 8)),
      ]),
    );
  }

  static Uint8List _bgraToJpeg(Uint8List bgra, int w, int h, int bytesPerRow) {
    final Uint8List rgba = Uint8List(w * h * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int src = y * bytesPerRow + x * 4;
        final int dst = (y * w + x) * 4;
        rgba[dst + 0] = bgra[src + 2];
        rgba[dst + 1] = bgra[src + 1];
        rgba[dst + 2] = bgra[src + 0];
        rgba[dst + 3] = bgra[src + 3];
      }
    }
    final img.Image original = img.Image.fromBytes(
      width: w, height: h,
      bytes: rgba.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
    final img.Image resized = original.width >= original.height
        ? img.copyResize(original, width: 600)
        : img.copyResize(original, height: 600);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }
}

final class _MetricData {
  final String title;
  final String value;
  final String ideal;
  const _MetricData(this.title, this.value, this.ideal);
}
