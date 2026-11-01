import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../theme.dart';
import 'motion.dart';
import 'tart_art.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 28, 12, 12)});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// A small rounded label, e.g. "Bestseller".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.foreground, this.icon});

  final String text;

  /// Defaults to the theme's accent colour.
  final Color? color;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = this.foreground ?? (color == null ? context.tart.onAccent : context.tart.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color ?? context.tart.accent, borderRadius: context.tart.radius(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: foreground), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: foreground, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label, this.onDark = false});

  final OrderStatus status;
  final String? label;

  /// Brighter text for chips sitting on a dark card in a light theme.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Color.lerp(status.color, Colors.white, 0.35)! : statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: context.tart.radius(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label ?? status.shortLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99, this.compact = false});

  final int value;
  final int min;
  final int max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 32.0 : 44.0;

    Widget button(IconData icon, int next, bool enabled) => SizedBox.square(
      dimension: size,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        iconSize: compact ? 16 : 20,
        style: IconButton.styleFrom(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface),
        onPressed: enabled ? () => onChanged(next) : null,
        icon: Icon(icon),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: scheme.outline.withValues(alpha: 0.6), borderRadius: context.tart.radius(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, value - 1, value > min),
          SizedBox(
            width: compact ? 30 : 40,
            child: AnimatedSwapText(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 14 : 17),
            ),
          ),
          button(Icons.add_rounded, value + 1, value < max),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.art = 'egg', this.action, this.onAction});

  final String title;
  final String message;
  final String art;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, navClearance(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Floating(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: context.tart.tint(art), shape: BoxShape.circle),
                child: TartArt(art: art, size: 120),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(action!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rounded card with an optional title, used for grouped details.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(18), this.color});

  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!.toUpperCase(),
                style: TextStyle(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(40), child: _SpinningTart()),
  );
}

/// A slowly turning tart, used while something loads.
class _SpinningTart extends StatefulWidget {
  const _SpinningTart();

  @override
  State<_SpinningTart> createState() => _SpinningTartState();
}

class _SpinningTartState extends State<_SpinningTart> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: RotationTransition(
      turns: CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      child: const TartArt(art: 'pineapple', size: 54),
    ),
  );
}

/// Status colours tuned to stay readable on dark themes.
Color statusColor(BuildContext context, OrderStatus status) =>
    Theme.of(context).brightness == Brightness.dark ? Color.lerp(status.color, Colors.white, 0.3)! : status.color;

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final text = '$error';
    final hint = text.contains('permission-denied') ? 'Firestore refused the request. Check that the security rules in firestore.rules are deployed.' : text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(hint, textAlign: TextAlign.center),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String confirmLabel = 'Yes', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
