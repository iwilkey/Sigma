import 'package:flutter/material.dart';

final class CaptureButton extends StatelessWidget {
  
  const CaptureButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(final BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 86,
        height: 86,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(width: 6, color: Colors.white),
          ),
          child: Center(
            child: SizedBox(
              width: 66,
              height: 66,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
