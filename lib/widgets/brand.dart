import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../theme.dart';

/// The shop's round logo with the "MYabah / TART LEJEN" wordmark, as in the website header.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 44, this.light = false, this.compact = false});

  final double size;

  /// White wordmark for dark backgrounds.
  final bool light;

  /// Only the round logo, without the wordmark.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
        image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
      ),
    );
    if (compact) return Semantics(label: 'MYabah Tart Lejen', child: logo);

    return Semantics(
      label: 'MYabah Tart Lejen',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(width: 10),
          ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MYabah',
                  style: tart.display(size: 18, weight: FontWeight.w800, color: light ? Colors.white : tart.ink, height: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  'TART LEJEN',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: light ? Color.lerp(tart.primary, Colors.white, 0.6) : (tart.isDark ? tart.accent : tart.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The website's small uppercase label with a dot in front, e.g. "• COLLECTIONS".
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;

  /// Replaces the dot.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final color = this.color ?? (tart.isDark ? tart.accent : tart.primary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 15, color: color)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tart.accent, shape: BoxShape.circle),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: color),
          ),
        ),
      ],
    );
  }
}

/// A website-style section heading: eyebrow, big title and an optional "View all" link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.eyebrowIcon,
    this.eyebrowColor,
    this.action,
    this.onAction,
    this.center = false,
  });

  final String eyebrow;
  final String title;
  final IconData? eyebrowIcon;
  final Color? eyebrowColor;
  final String? action;
  final VoidCallback? onAction;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow, icon: eyebrowIcon, color: eyebrowColor),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: displayFont(context, size: 26, weight: FontWeight.w800, height: 1.1),
        ),
      ],
    );
    if (center || action == null) return center ? Center(child: heading) : heading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(foregroundColor: context.tart.inkSoft, padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!), const SizedBox(width: 4), const Icon(Icons.arrow_forward_rounded, size: 16)]),
        ),
      ],
    );
  }
}

/// The hand-drawn underline under the highlighted hero word.
class Squiggle extends StatelessWidget {
  const Squiggle({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _SquigglePainter(color), child: child);
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The website's SVG path "M2 9C50 3 150 3 198 8" on a 200×12 box, stretched under the word.
    final sx = size.width / 200;
    final top = size.height - 6;
    final path = Path()
      ..moveTo(2 * sx, top + 9 * 0.6)
      ..cubicTo(50 * sx, top + 3 * 0.6, 150 * sx, top + 3 * 0.6, 198 * sx, top + 8 * 0.6);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter oldDelegate) => oldDelegate.color != color;
}

/// Round swatches for every design, as in the website footer. Tapping one switches the app's look.
class ThemeSwatches extends StatelessWidget {
  const ThemeSwatches({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final tart = context.tart;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final theme in TartTheme.all)
          Semantics(
            button: true,
            selected: theme.id == controller.theme.id,
            label: theme.label,
            child: GestureDetector(
              onTap: () => controller.select(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: theme.id == controller.theme.id ? (onDark ? tart.accent : tart.primary) : (onDark ? Colors.white24 : tart.line),
                    width: theme.id == controller.theme.id ? 2.5 : 1,
                  ),
                ),
                child: SizedBox(
                  width: 34,
                  height: 18,
                  child: Stack(
                    children: [
                      for (final (index, color) in theme.swatches.indexed)
                        Positioned(
                          left: index * 8.0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: onDark ? tart.deep : tart.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
