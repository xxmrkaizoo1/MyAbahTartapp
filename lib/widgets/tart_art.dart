import 'dart:math';

import 'package:material_ui/material_ui.dart';

enum _Topping { lattice, blisters, glaze, berries, fan, dust, nuts, swirl, herbs, spikes, petals, peaks, drizzle, crumbs }

class _Flavor {
  const _Flavor(this.label, this.filling, this.topping, this.tint, this.kind);

  final String label;
  final Color filling;
  final Color topping;
  final Color tint;
  final _Topping kind;
}

const _flavors = <String, _Flavor>{
  'pineapple': _Flavor('Pineapple', Color(0xFFF4B53F), Color(0xFFDA8F2A), Color(0xFFFFEBC2), _Topping.lattice),
  'egg': _Flavor('Egg custard', Color(0xFFF7CB4D), Color(0xFF8C4A1B), Color(0xFFFFF0C6), _Topping.blisters),
  'cheese': _Flavor('Cheese', Color(0xFFFFD873), Color(0xFFE29B2E), Color(0xFFFFF3CF), _Topping.glaze),
  'berry': _Flavor('Mixed berries', Color(0xFFFBE9C9), Color(0xFFD7263D), Color(0xFFFFDDE3), _Topping.berries),
  'mango': _Flavor('Mango', Color(0xFFFFC94D), Color(0xFFFF9F1C), Color(0xFFFFE6C2), _Topping.fan),
  'matcha': _Flavor('Matcha', Color(0xFF9CBF5F), Color(0xFFE9F2D3), Color(0xFFE5F0D2), _Topping.dust),
  'nutty': _Flavor('Nuts', Color(0xFFA8642E), Color(0xFF6E3B16), Color(0xFFF3DFC8), _Topping.nuts),
  'chocolate': _Flavor('Chocolate', Color(0xFF4A2716), Color(0xFF7B4528), Color(0xFFEBD9CC), _Topping.swirl),
  'savory': _Flavor('Savoury pie', Color(0xFFF2D58A), Color(0xFF5E8C3A), Color(0xFFF3ECD2), _Topping.herbs),
  'durian': _Flavor('Durian', Color(0xFFF6DC7A), Color(0xFF7FA23A), Color(0xFFF4F0C8), _Topping.spikes),
  'lavender': _Flavor('Earl Grey / Lavender', Color(0xFFC9B1E8), Color(0xFF8B62C9), Color(0xFFEDE3FA), _Topping.petals),
  'lemon': _Flavor('Lemon meringue', Color(0xFFFFE15C), Color(0xFFFFFBF2), Color(0xFFFFF6C9), _Topping.peaks),
  'caramel': _Flavor('Salted caramel', Color(0xFFC27A2C), Color(0xFF8A4B14), Color(0xFFF6E2C8), _Topping.drizzle),
  'pistachio': _Flavor('Pistachio', Color(0xFFB5CF7E), Color(0xFFF29BB5), Color(0xFFEAF2D8), _Topping.crumbs),
};

/// The illustration styles admins can pick for products without a photo, keyed like the website.
Map<String, String> get tartArtLabels => {for (final entry in _flavors.entries) entry.key: entry.value.label};

_Flavor _flavor(String art) => _flavors[art] ?? _flavors['pineapple']!;

/// A soft background colour that matches the tart's filling.
Color tartTint(String art) => _flavor(art).tint;

/// Resolves a stored photo reference: `asset:` paths are bundled with the app, anything else is a web URL.
ImageProvider? photoProvider(String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return null;
  return value.startsWith('asset:') ? AssetImage(value.substring(6)) : NetworkImage(value);
}

/// A round product photo when there is one, otherwise a drawn tart in the product's flavour.
class TartArt extends StatelessWidget {
  const TartArt({super.key, required this.art, this.size = 120, this.imageUrl});

  final String art;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final drawn = CustomPaint(size: Size.square(size), painter: _TartPainter(_flavor(art), art.hashCode));
    final photo = photoProvider(imageUrl);
    if (photo == null) return drawn;

    return ClipOval(
      child: Image(
        image: photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => drawn,
        loadingBuilder: (_, child, progress) => progress == null ? child : drawn,
      ),
    );
  }
}

/// A product or collection photo filling its box, like the website's product images.
/// Without a photo it shows the drawn tart on its flavour colour.
class ProductPhoto extends StatelessWidget {
  const ProductPhoto({super.key, required this.art, this.imageUrl, this.background});

  final String art;
  final String? imageUrl;

  /// Shown behind the drawn tart; defaults to the flavour's tint.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final drawn = ColoredBox(
      color: background ?? tartTint(art),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: TartArt(art: art, size: constraints.biggest.shortestSide * 0.66),
        ),
      ),
    );
    final photo = photoProvider(imageUrl);
    if (photo == null) return SizedBox.expand(child: drawn);

    return SizedBox.expand(
      child: Image(
        image: photo,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => drawn,
        frameBuilder: (_, child, frame, synchronous) => synchronous || frame != null ? child : drawn,
      ),
    );
  }
}

class _TartPainter extends CustomPainter {
  _TartPainter(this.flavor, this.seed);

  final _Flavor flavor;
  final int seed;

  static const _crust = Color(0xFFD99A52);
  static const _crustLight = Color(0xFFEDBE7A);
  static const _crustDark = Color(0xFFB8762F);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final random = Random(seed);

    canvas.drawCircle(
      center + Offset(0, radius * 0.07),
      radius * 0.9,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06),
    );

    // Fluted pastry edge.
    final edge = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final angle = i / steps * 2 * pi;
      final r = radius * 0.92 * (1 + 0.04 * sin(angle * 16));
      final point = center + Offset(cos(angle) * r, sin(angle) * r);
      i == 0 ? edge.moveTo(point.dx, point.dy) : edge.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      edge,
      Paint()
        ..shader = RadialGradient(
          colors: const [_crustLight, _crust, _crustDark],
          stops: const [0.55, 0.85, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(center, radius * 0.74, Paint()..color = _crustDark.withValues(alpha: 0.55));

    final fillingRadius = radius * 0.7;
    final filling = Rect.fromCircle(center: center, radius: fillingRadius);
    canvas.drawCircle(
      center,
      fillingRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [Color.lerp(flavor.filling, Colors.white, 0.28)!, flavor.filling, Color.lerp(flavor.filling, Colors.black, 0.12)!],
          stops: const [0, 0.65, 1],
        ).createShader(filling),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(filling));
    _paintTopping(canvas, center, fillingRadius, random);
    canvas.restore();

    // Glossy highlight.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: fillingRadius * 0.82),
      pi * 1.08,
      pi * 0.42,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 0.06,
    );
  }

  void _paintTopping(Canvas canvas, Offset c, double r, Random random) {
    final paint = Paint()..color = flavor.topping;
    Offset spot(double maxDistance) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = sqrt(random.nextDouble()) * maxDistance;
      return c + Offset(cos(angle) * distance, sin(angle) * distance);
    }

    switch (flavor.kind) {
      case _Topping.lattice:
        final strip = Paint()
          ..color = _crustLight
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round;
        final shade = Paint()
          ..color = _crustDark.withValues(alpha: 0.5)
          ..strokeWidth = r * 0.16;
        for (final direction in [1.0, -1.0]) {
          for (var i = -2; i <= 2; i++) {
            final offset = i * r * 0.42;
            final start = c + Offset(offset - r * direction, -r);
            final end = c + Offset(offset + r * direction, r);
            canvas.drawLine(start + const Offset(0, 2), end + const Offset(0, 2), shade);
            canvas.drawLine(start, end, strip);
          }
        }
      case _Topping.blisters:
        for (var i = 0; i < 16; i++) {
          final blotch = Paint()
            ..color = flavor.topping.withValues(alpha: 0.25 + random.nextDouble() * 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
          canvas.drawCircle(spot(r * 0.9), r * (0.07 + random.nextDouble() * 0.14), blotch);
        }
      case _Topping.glaze:
        canvas.drawCircle(
          c,
          r * 0.95,
          Paint()
            ..color = flavor.topping.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.18,
        );
        for (var i = 0; i < 9; i++) {
          canvas.drawCircle(spot(r * 0.7), r * 0.05, Paint()..color = const Color(0xFFC0392B).withValues(alpha: 0.75));
        }
      case _Topping.berries:
        const colors = [Color(0xFFD7263D), Color(0xFF3B4CCA), Color(0xFFB0124F), Color(0xFFE84855)];
        for (var i = 0; i < 18; i++) {
          final at = spot(r * 0.85);
          final berry = r * (0.11 + random.nextDouble() * 0.07);
          canvas.drawCircle(at, berry, Paint()..color = colors[i % colors.length]);
          canvas.drawCircle(at - Offset(berry * 0.35, berry * 0.35), berry * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.45));
        }
      case _Topping.fan:
        for (var i = 0; i < 9; i++) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(i / 9 * 2 * pi);
          final slice = Rect.fromCenter(center: Offset(0, -r * 0.5), width: r * 0.36, height: r * 0.95);
          canvas.drawOval(slice, Paint()..color = Color.lerp(flavor.topping, Colors.white, (i % 3) * 0.12)!);
          canvas.drawOval(
            slice,
            Paint()
              ..color = const Color(0x22000000)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
          canvas.restore();
        }
      case _Topping.dust:
        for (var i = 0; i < 160; i++) {
          canvas.drawCircle(spot(r), r * 0.018, Paint()..color = Colors.white.withValues(alpha: 0.5));
        }
        canvas.drawCircle(c, r * 0.26, Paint()..color = flavor.topping);
        canvas.drawCircle(
          c,
          r * 0.26,
          Paint()
            ..color = const Color(0x22000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case _Topping.nuts:
        for (var ring = 0; ring < 2; ring++) {
          final count = ring == 0 ? 9 : 4;
          for (var i = 0; i < count; i++) {
            final angle = i / count * 2 * pi + ring * 0.4;
            final distance = ring == 0 ? r * 0.62 : r * 0.24;
            canvas.save();
            canvas.translate(c.dx + cos(angle) * distance, c.dy + sin(angle) * distance);
            canvas.rotate(angle);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.36, height: r * 0.2), paint);
            canvas.drawLine(
              Offset(-r * 0.13, 0),
              Offset(r * 0.13, 0),
              Paint()
                ..color = const Color(0x55000000)
                ..strokeWidth = 1.4,
            );
            canvas.restore();
          }
        }
      case _Topping.swirl:
        final swirl = Path()..moveTo(c.dx, c.dy);
        for (var t = 0.0; t < 6 * pi; t += 0.1) {
          final distance = r * 0.85 * t / (6 * pi);
          swirl.lineTo(c.dx + cos(t) * distance, c.dy + sin(t) * distance);
        }
        canvas.drawPath(
          swirl,
          Paint()
            ..color = flavor.topping
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round,
        );
        for (var i = 0; i < 14; i++) {
          final at = spot(r * 0.85);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: r * 0.1, height: r * 0.06), const Radius.circular(2)),
            Paint()..color = const Color(0xFF2A140A),
          );
        }
      case _Topping.herbs:
        for (var i = 0; i < 6; i++) {
          final at = spot(r * 0.7);
          canvas.drawOval(Rect.fromCenter(center: at, width: r * 0.34, height: r * 0.22), Paint()..color = const Color(0xFFE8D9BF));
          canvas.drawLine(
            at,
            at + Offset(0, r * 0.1),
            Paint()
              ..color = const Color(0xFFB59B76)
              ..strokeWidth = r * 0.06,
          );
        }
        for (var i = 0; i < 12; i++) {
          final at = spot(r * 0.9);
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(random.nextDouble() * pi);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.16, height: r * 0.06), paint);
          canvas.restore();
        }
      case _Topping.spikes:
        for (var i = 0; i < 12; i++) {
          final angle = i / 12 * 2 * pi;
          final tip = c + Offset(cos(angle) * r * 0.55, sin(angle) * r * 0.55);
          final left = c + Offset(cos(angle - 0.25) * r * 0.25, sin(angle - 0.25) * r * 0.25);
          final right = c + Offset(cos(angle + 0.25) * r * 0.25, sin(angle + 0.25) * r * 0.25);
          canvas.drawPath(
            Path()
              ..moveTo(left.dx, left.dy)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(right.dx, right.dy)
              ..close(),
            paint,
          );
        }
        canvas.drawCircle(c, r * 0.24, Paint()..color = const Color(0xFFFFF4C9));
      case _Topping.petals:
        canvas.drawCircle(c, r * 0.32, Paint()..color = Colors.white.withValues(alpha: 0.9));
        for (var i = 0; i < 16; i++) {
          final at = spot(r * 0.88);
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(random.nextDouble() * pi);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.12, height: r * 0.06), paint);
          canvas.restore();
        }
      case _Topping.peaks:
        final positions = [c, for (var i = 0; i < 7; i++) c + Offset(cos(i / 7 * 2 * pi) * r * 0.58, sin(i / 7 * 2 * pi) * r * 0.58)];
        for (final at in positions) {
          canvas.drawCircle(at + const Offset(1.5, 2.5), r * 0.25, Paint()..color = const Color(0xFFC98A3A).withValues(alpha: 0.55));
          canvas.drawCircle(at, r * 0.25, paint);
          canvas.drawCircle(at - Offset(r * 0.07, r * 0.07), r * 0.08, Paint()..color = const Color(0xFFE6B26A).withValues(alpha: 0.6));
        }
      case _Topping.drizzle:
        final drizzle = Paint()
          ..color = flavor.topping
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..strokeCap = StrokeCap.round;
        for (var row = -3; row <= 3; row++) {
          final path = Path()..moveTo(c.dx - r, c.dy + row * r * 0.28);
          for (var x = -r; x <= r; x += r * 0.1) {
            path.lineTo(c.dx + x, c.dy + row * r * 0.28 + sin(x / r * 6 + row) * r * 0.06);
          }
          canvas.drawPath(path, drizzle);
        }
        for (var i = 0; i < 18; i++) {
          final at = spot(r * 0.85);
          canvas.drawRect(Rect.fromCenter(center: at, width: r * 0.05, height: r * 0.05), Paint()..color = Colors.white.withValues(alpha: 0.9));
        }
      case _Topping.crumbs:
        for (var i = 0; i < 40; i++) {
          canvas.drawCircle(spot(r * 0.95), r * (0.025 + random.nextDouble() * 0.04), Paint()..color = const Color(0xFF6E8F3A));
        }
        for (var i = 0; i < 7; i++) {
          final at = spot(r * 0.6);
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(random.nextDouble() * pi);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.22, height: r * 0.13), paint);
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(_TartPainter oldDelegate) => oldDelegate.flavor != flavor;
}
