// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sigma/analysis/face_metrics.dart';
import 'package:sigma/share/share_service.dart';

/// A modal bottom sheet that lets the user optionally enter an email address
/// before sharing their Sigma portrait report PDF.
///
/// Usage:
///   ShareSheet.show(context, metrics: m, bgraPixels: px, ...);
final class ShareSheet {
  ShareSheet._();

  static Future<void> show(
    BuildContext context, {
    required FaceMetrics metrics,
    required Uint8List bgraPixels,
    required int imageWidth,
    required int imageHeight,
    required int bytesPerRow,
    required String aiInsight,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheetContent(
        metrics: metrics,
        bgraPixels: bgraPixels,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        bytesPerRow: bytesPerRow,
        aiInsight: aiInsight,
      ),
    );
  }
}

final class _ShareSheetContent extends StatefulWidget {
  final FaceMetrics metrics;
  final Uint8List bgraPixels;
  final int imageWidth;
  final int imageHeight;
  final int bytesPerRow;
  final String aiInsight;

  const _ShareSheetContent({
    required this.metrics,
    required this.bgraPixels,
    required this.imageWidth,
    required this.imageHeight,
    required this.bytesPerRow,
    required this.aiInsight,
  });

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

final class _ShareSheetContentState extends State<_ShareSheetContent> {
  final TextEditingController _emailCtrl = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _share() async {
    _dismissKeyboard();
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ShareService.shareReport(
        metrics: widget.metrics,
        bgraPixels: widget.bgraPixels,
        imageWidth: widget.imageWidth,
        imageHeight: widget.imageHeight,
        bytesPerRow: widget.bytesPerRow,
        aiInsight: widget.aiInsight,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (mounted) setState(() { _loading = false; _done = true; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: Container(
      margin: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        color: Color(0xFF111118),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────────
          Row(children: [
            const Text('Share Your Report',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.4), width: 1),
              ),
              child: const Text('PDF', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Your portrait photo, AI insight, and all 5 harmony metrics — beautifully packaged.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          // ── Metric preview pills ─────────────────────────────────────────
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _pill('Symmetry', '${widget.metrics.overallSymmetry.toStringAsFixed(1)}%'),
              _pill('Canthal', '${widget.metrics.averageCanthalTilt > 0 ? '+' : ''}${widget.metrics.averageCanthalTilt.toStringAsFixed(1)}°'),
              _pill('Thirds', widget.metrics.facialThirdsRatio),
              _pill('Lips', widget.metrics.lipVolumeRatio),
              _pill('φ Ratio', widget.metrics.horizontalGoldenRatio.toStringAsFixed(3)),
            ],
          ),
          const SizedBox(height: 24),

          // ── Email field ──────────────────────────────────────────────────
          const Text('Email address (optional)',
            style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C26),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x33FFFFFF), width: 1),
            ),
            child: TextField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onSubmitted: (_) => _dismissKeyboard(),
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(color: Colors.white30),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.white30, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'If filled in, the email app will open pre-addressed to this address.',
            style: TextStyle(color: Colors.white30, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 24),

          // ── Share button ─────────────────────────────────────────────────
          SizedBox(
            height: 54,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _done
                  ? Container(
                      key: const ValueKey('done'),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FFCC).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00FFCC), width: 1),
                      ),
                      child: const Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_rounded, color: Color(0xFF00FFCC), size: 20),
                          SizedBox(width: 8),
                          Text('Report shared!', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('share'),
                      onTap: _share,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFCC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                )
                              : const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.ios_share_rounded, color: Colors.black, size: 20),
                                  SizedBox(width: 8),
                                  Text('Share Report', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
                                ]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
