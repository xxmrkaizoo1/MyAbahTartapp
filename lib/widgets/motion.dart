import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Motion used across the app. Everything here turns itself off when the phone asks for reduced motion.
bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Page transition for every pushed screen: the new page rises slightly and fades in,
/// while the old one eases back a touch.
class TartPageTransitionsBuilder extends PageTransitionsBuilder {
  const TartPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_reduceMotion(context)) return FadeTransition(opacity: animation, child: child);

    final incoming = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(outgoing),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.96).animate(outgoing),
        child: FadeTransition(
          opacity: incoming,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(incoming),
            child: child,
          ),
        ),
      ),
    );
  }
}

const tartPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: TartPageTransitionsBuilder(),
    TargetPlatform.iOS: TartPageTransitionsBuilder(),
    TargetPlatform.macOS: TartPageTransitionsBuilder(),
    TargetPlatform.windows: TartPageTransitionsBuilder(),
    TargetPlatform.linux: TartPageTransitionsBuilder(),
    TargetPlatform.fuchsia: TartPageTransitionsBuilder(),
  },
);

/// Like [IndexedStack] (tabs keep their scroll position) but the newly shown tab fades and slides in.
class AnimatedTabStack extends StatefulWidget {
  const AnimatedTabStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<AnimatedTabStack> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  int _direction = 1;

  @override
  void didUpdateWidget(AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(index: widget.index, children: widget.children);
    if (_reduceMotion(context)) return stack;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: 0.35 + 0.65 * _curve.value,
        child: Transform.translate(offset: Offset(24 * _direction * (1 - _curve.value), 0), child: child),
      ),
      child: stack,
    );
  }
}

/// Fades and lifts a widget into place when it first appears. Give list items increasing
/// [index]es for a staggered cascade.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 18, this.axis = Axis.vertical});

  final Widget child;
  final int index;
  final double offset;
  final Axis axis;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  static const _step = 45;
  static const _length = 420;

  // The delay is part of the animation (an Interval), so no timers are left running.
  late final int _delay = min(widget.index, 8) * _step;
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delay + _length),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delay / (_delay + _length), 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final distance = widget.offset * (1 - _curve.value);
        return Opacity(
          opacity: _curve.value,
          child: Transform.translate(offset: widget.axis == Axis.vertical ? Offset(0, distance) : Offset(distance, 0), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Shrinks a little while pressed, for cards and big buttons.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.96});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// A gentle up-and-down float, like the website's `animate-float`.
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.distance = 8, this.period = const Duration(seconds: 6), this.phase = 0});

  final Widget child;
  final double distance;
  final Duration period;

  /// 0–1: where in the cycle this one starts, so neighbours don't move in step.
  final double phase;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.period, value: widget.phase)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(offset: Offset(0, -widget.distance * sin(_controller.value * 2 * pi).abs()), child: child),
      child: widget.child,
    );
  }
}

/// An endless sideways scroll of its child, like the website's ticker (`animate-marquee`).
/// Stands still when the phone asks for reduced motion.
class Marquee extends StatefulWidget {
  const Marquee({super.key, required this.child, required this.height, this.speed = 40});

  final Widget child;

  /// The band's height; the content scrolls inside it.
  final double height;

  /// Logical pixels per second.
  final double speed;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  final _childKey = GlobalKey();
  double _width = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final width = _childKey.currentContext?.size?.width ?? 0;
    if (width <= 0 || width == _width) return;
    setState(() => _width = width);
    _controller
      ..duration = Duration(milliseconds: (width / widget.speed * 1000).round())
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(key: _childKey, child: widget.child),
        widget.child,
      ],
    );
    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: _reduceMotion(context) || _width == 0
              ? row
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.translate(offset: Offset(-_width * _controller.value, 0), child: child),
                  child: row,
                ),
        ),
      ),
    );
  }
}

/// A number that counts up to its value, then animates between later values.
class CountUpText extends StatelessWidget {
  const CountUpText({super.key, required this.value, required this.format, this.style});

  final double value;
  final String Function(double value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text(format(current), style: style),
    );
  }
}

/// Swaps text with a quick slide, e.g. prices, counts and statuses that change.
class AnimatedSwapText extends StatelessWidget {
  const AnimatedSwapText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: textAlign == TextAlign.center ? Alignment.center : (textAlign == TextAlign.end ? Alignment.centerRight : Alignment.centerLeft),
        children: [...previous, ?current],
      ),
      child: Text(text, key: ValueKey(text), style: style, textAlign: textAlign),
    );
  }
}

/// Wraps each child in a [FadeSlideIn] so a page's blocks cascade in one after another.
List<Widget> staggered(List<Widget> children) => [for (final (index, child) in children.indexed) FadeSlideIn(index: index, child: child)];
