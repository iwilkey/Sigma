// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sigma/analysis/face_metrics.dart';
import 'package:sigma/share/share_service.dart';

/// Author: Ian Wilkey and Barney Jin
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

/// Author: Ian Wilkey and Barney Jin
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
    if(_loading) return;
    setState(() => _loading = true);
    try {
      await ShareService.shareReport(
        context: context,
        metrics: widget.metrics,
        bgraPixels: widget.bgraPixels,
        imageWidth: widget.imageWidth,
        imageHeight: widget.imageHeight,
        bytesPerRow: widget.bytesPerRow,
        aiInsight: widget.aiInsight,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if(!mounted) return;
      setState(() {
        _loading = false;
        _done = true;
      });
    } catch (e) {
      if(!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: Colors.black87,
        ),
      );
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
          Row(children: [
            const Text('Share Your Sigma Report',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
              ),
              child: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Your portrait photo, AI insights, and all 5 Sigma harmony metrics, beautifully packaged and ready to distribute.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
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
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _share,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Share Report",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                  )
            ),
          ),
        ],
      ),
    ));
  }

}
