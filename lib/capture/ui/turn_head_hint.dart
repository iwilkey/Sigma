import 'package:flutter/material.dart';

/// Author: Ian Wilkey and Barney Jin
final class TurnHeadHint extends StatefulWidget {
  const TurnHeadHint({
    super.key,
    required this.visible,
  });
  final bool visible;
  @override
  State<TurnHeadHint> createState() => _TurnHeadHintState();
}

/// Author: Ian Wilkey and Barney Jin
final class _TurnHeadHintState extends State<TurnHeadHint> with SingleTickerProviderStateMixin {

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final double t = _pulse.value;
            final double textOpacity = 0.70 + (0.25 * t);
            // ignore: deprecated_member_use
            final Color textColor = Colors.white.withOpacity(textOpacity);
            // ignore: deprecated_member_use
            final Color iconColor = Colors.white.withOpacity(0.88 + 0.07 * t);
            return Transform.translate(
              offset: Offset(0, 0),
              child: _HintPill(
                textColor: textColor,
                iconColor: iconColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Author: Ian Wilkey and Barney Jin
final class _HintPill extends StatelessWidget {

  const _HintPill({
    required this.textColor,
    required this.iconColor,
  });

  final Color textColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.question_answer,
                size: 28,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Turn your head slowly side to side, keeping your face centered and well-lit until it’s detected.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
