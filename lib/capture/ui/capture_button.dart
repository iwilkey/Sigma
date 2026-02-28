import 'package:flutter/material.dart';

/// Author: Ian Wilkey and Barney Jin
final class CaptureButton extends StatefulWidget {
  const CaptureButton({
    super.key,
    required this.onPressed,
  });
  final VoidCallback? onPressed;
  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

final class _CaptureButtonState extends State<CaptureButton> {

  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool v) {
    if(_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(final BuildContext context) {
    final bool enabled = _enabled;
    final double scale = _pressed ? 0.94 : 1.0;
    final double outerOpacity = enabled ? 1.0 : 0.40;
    final double innerOpacity = enabled ? (_pressed ? 0.82 : 0.92) : 0.25;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled
        ? (_) {
            _setPressed(false);
            widget.onPressed?.call();
          }
        : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 86,
          height: 86,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 6,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(outerOpacity),
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(innerOpacity),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
