import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:sigma/analysis/face_metrics.dart';

/// Author: Barney Jin and Ian Wilkey
final class ShareService {

  ShareService._();

  static Future<void> shareReport({
    required BuildContext context,
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
    required String aiInsight,
    String? email,
  }) async {
    try {
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
      final XFile xFile = XFile(
        file.path,
        mimeType: 'application/pdf',
        name: 'Sigma Portrait Report.pdf',
      );
      final String? trimmedEmail = _trimOrNull(email);
      // ignore: use_build_context_synchronously
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
      await Share.shareXFiles(
        <XFile>[xFile],
        subject: 'My Sigma Portrait Harmony Report',
        text: trimmedEmail == null ? null : 'To $trimmedEmail',
        sharePositionOrigin: origin,
      );
    } catch (e, st) {
      debugPrint('ShareService.shareReport failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  static Future<Uint8List> _buildPdf({
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
    required String aiInsight,
  }) async {
    final pw.ThemeData? theme = await _tryLoadPdfTheme();
    final Uint8List jpegBytes = _bgraToJpeg(bgraPixels, imageWidth, imageHeight, bytesPerRow);
    final pw.MemoryImage portraitImg = pw.MemoryImage(jpegBytes);
    pw.MemoryImage? logoImg;
    try {
      final ByteData data = await rootBundle.load('assets/icon.png');
      logoImg = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logoImg = null;
    }
    const PdfColor bg = PdfColor.fromInt(0xFF0A0A0F);
    const PdfColor surface = PdfColor.fromInt(0xFF1A1A24);
    const PdfColor accent = PdfColor.fromInt(0xFF00FFCC);
    const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);
    const PdfColor white70 = PdfColor.fromInt(0xB3FFFFFF);
    const PdfColor white40 = PdfColor.fromInt(0x66FFFFFF);
    final List<_MetricData> metricItems = <_MetricData>[
      _MetricData('Symmetry Match', '${metrics.overallSymmetry.toStringAsFixed(1)} percent', 'Ideal 100 percent'),
      _MetricData('Canthal Tilt', _formatCanthalDeg(metrics.averageCanthalTilt), 'Ideal plus 3 to plus 5 deg'),
      _MetricData('Facial Thirds', _asciiHuman(metrics.facialThirdsRatio), 'Ideal 1 to 1 to 1'),
      _MetricData('Lip Volume', _asciiHuman(metrics.lipVolumeRatio), 'Ideal 1 to 1.6'),
      _MetricData('Golden Ratio', _asciiHuman(metrics.horizontalGoldenRatio.toStringAsFixed(3)), 'Ideal 1.618'),
    ];
    final pw.Document pdf = theme == null ? pw.Document() : pw.Document(theme: theme);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context ctx) {
          return pw.Container(
            color: bg,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: <pw.Widget>[
                pw.Container(
                  color: surface,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: <pw.Widget>[
                      pw.Row(
                        children: <pw.Widget>[
                          if(logoImg != null) ...<pw.Widget>[
                            pw.Container(width: 32, height: 32, child: pw.Image(logoImg)),
                            pw.SizedBox(width: 10),
                          ],
                          pw.Text(
                            'SIGMA',
                            style: pw.TextStyle(
                              color: accent,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Beauty is more than math.',
                        style: pw.TextStyle(color: white70, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(32),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: <pw.Widget>[
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
                              pw.Container(
                                padding: const pw.EdgeInsets.all(16),
                                decoration: pw.BoxDecoration(
                                  color: surface,
                                  borderRadius: pw.BorderRadius.circular(12),
                                  border: pw.Border.all(color: white40, width: 0.5),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: <pw.Widget>[
                                    pw.Row(
                                      children: <pw.Widget>[
                                        pw.Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
                                        ),
                                        pw.SizedBox(width: 6),
                                        pw.Text(
                                          'AI Quick Insight',
                                          style: pw.TextStyle(
                                            color: accent,
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    pw.SizedBox(height: 10),
                                    pw.Text(
                                      aiInsight.trim().isEmpty ? 'No AI insight available.' : _asciiHuman(aiInsight),
                                      style: pw.TextStyle(color: white70, fontSize: 10, lineSpacing: 3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 24),
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: <pw.Widget>[
                              pw.Text(
                                'HARMONY METRICS',
                                style: pw.TextStyle(color: accent, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
                              ),
                              pw.SizedBox(height: 12),
                              ...metricItems.map((m) => _buildMetricRow(m, surface, white, white40, accent)),
                              pw.SizedBox(height: 24),
                              pw.Divider(color: white40, thickness: 0.4),
                              pw.SizedBox(height: 16),
                              _buildHarmonyBadge(metrics, surface, accent, white, white70),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Container(
                  color: surface,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: <pw.Widget>[
                      pw.Text('Generated by Sigma Engine, HackIllinois 2026 Project Submission', style: pw.TextStyle(color: white40, fontSize: 8)),
                      pw.Text('Co-Created by Barney Jin and Ian Wilkey', style: pw.TextStyle(color: white40, fontSize: 8)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<pw.ThemeData?> _tryLoadPdfTheme() async {
    try {
      final ByteData regularData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final ByteData boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
      final pw.Font regular = pw.Font.ttf(regularData);
      final pw.Font bold = pw.Font.ttf(boldData);
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (e) {
      debugPrint('PDF font load skipped: $e');
      return null;
    }
  }

  static pw.Widget _buildMetricRow(
    _MetricData m,
    PdfColor surface,
    PdfColor white,
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
        children: <pw.Widget>[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(_asciiHuman(m.title), style: pw.TextStyle(color: white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(_asciiHuman(m.ideal), style: pw.TextStyle(color: white40, fontSize: 9)),
            ],
          ),
          pw.Text(_asciiHuman(m.value), style: pw.TextStyle(color: accent, fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
    if(sym >= 80) classical++;
    if(d <= 0.12) classical++;
    if(metrics.averageCanthalTilt > 0) classical++;
    final String label = classical >= 2 ? 'Classical Timelessness' : 'Contemporary Photographic Appeal';
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: accent, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('DOMINANT STYLE', style: pw.TextStyle(color: accent, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
          pw.SizedBox(height: 6),
          pw.Text(_asciiHuman(label), style: pw.TextStyle(color: white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Based on Portrait Harmony Framework', style: pw.TextStyle(color: white70, fontSize: 8)),
        ],
      ),
    );
  }

  static Uint8List _bgraToJpeg(Uint8List bgra, int w, int h, int bytesPerRow) {
    final Uint8List rgba = Uint8List(w * h * 4);
    for(int y = 0; y < h; y++) {
      for(int x = 0; x < w; x++) {
        final int src = y * bytesPerRow + x * 4;
        final int dst = (y * w + x) * 4;
        rgba[dst + 0] = bgra[src + 2];
        rgba[dst + 1] = bgra[src + 1];
        rgba[dst + 2] = bgra[src + 0];
        rgba[dst + 3] = bgra[src + 3];
      }
    }
    final img.Image original = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rgba.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
    final img.Image resized = original.width >= original.height
      ? img.copyResize(original, width: 600)
      : img.copyResize(original, height: 600);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }

  static String? _trimOrNull(String? s) {
    if(s == null) return null;
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }

  static String _formatCanthalDeg(double tiltDeg) {
    final String sign = tiltDeg > 0 ? '+ ' : tiltDeg < 0 ? '- ' : '';
    return '$sign${tiltDeg.abs().toStringAsFixed(1)} deg.';
  }

  static String _asciiHuman(String s) {
    String t = s;
    t = t.replaceAll(String.fromCharCode(0x2019), "'");
    t = t.replaceAll(String.fromCharCode(0x2018), "'");
    t = t.replaceAll(String.fromCharCode(0x201C), '"');
    t = t.replaceAll(String.fromCharCode(0x201D), '"');
    t = t.replaceAll(String.fromCharCode(0x2014), '-');
    t = t.replaceAll(String.fromCharCode(0x2013), '-');
    t = t.replaceAll(String.fromCharCode(0x00B0), ' deg');
    t = t.replaceAll(String.fromCharCode(0x03C6), 'phi');
    t = t.replaceAll(String.fromCharCode(0x00A0), ' ');
    final StringBuffer out = StringBuffer();
    bool lastWasSpace = false;
    for(int i = 0; i < t.length; i++) {
      final int c = t.codeUnitAt(i);
      if(c < 32 || c > 126) {
        if(!lastWasSpace) {
          out.write(' ');
          lastWasSpace = true;
        }
        continue;
      }
      final String ch = String.fromCharCode(c);
      if(ch == '\n' || ch == '\r' || ch == '\t') {
        if(!lastWasSpace) {
          out.write(' ');
          lastWasSpace = true;
        }
        continue;
      }
      if(ch == ' ') {
        if(!lastWasSpace) {
          out.write(' ');
          lastWasSpace = true;
        }
        continue;
      }
      out.write(ch);
      lastWasSpace = false;
    }
    return out.toString().trim();
  }
}

final class _MetricData {
  final String title;
  final String value;
  final String ideal;
  const _MetricData(this.title, this.value, this.ideal);
}
