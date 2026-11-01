import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../screens/shop/product_screen.dart';
import '../services/cart.dart';
import '../services/format.dart';
import '../theme.dart';
import 'common.dart';
import 'motion.dart';
import 'tart_art.dart';

/// The website's product card: a 4:5 photo with badges and a quick-add button, then the details below.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.heroScope, this.width, this.rank, this.reason});

  final Product product;

  /// Where the card is shown (e.g. "home", "menu"), so each picture has a unique Hero tag
  /// even though the tabs stay alive side by side.
  final String heroScope;
  final double? width;

  /// A big number over the photo for bestseller lists.
  final int? rank;

  /// Replaces the tagline, e.g. "Popular in Kerepek".
  final String? reason;

  /// The text under the photo: fixed gaps plus lines that grow with the phone's font size.
  static double _textBlock(BuildContext context) => 30 + MediaQuery.textScalerOf(context).scale(98);

  /// Card height for a given width: the 4:5 photo plus the text block below it.
  static double heightFor(BuildContext context, double width) => width * 1.25 + _textBlock(context);

  String get _heroTag => 'tart-$heroScope-${product.id}';

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductScreen(productId: product.id, heroTag: _heroTag),
    ),
  );

  void _quickAdd(BuildContext context) {
    if (product.hasSizes) {
      _open(context);
      return;
    }
    final added = context.read<Cart>().add(product, null, 1);
    showMessage(context, added > 0 ? '${product.name} added to your cart' : 'No more ${product.name} left in stock');
  }

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final soldOut = product.isSoldOut;
    final category = context.watch<List<MenuCategory>>().where((category) => category.id == product.categoryId).firstOrNull;
    final shadow = [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 16, offset: const Offset(0, 6))];

    return SizedBox(
      width: width,
      child: Pressable(
        scale: 0.97,
        child: GestureDetector(
          onTap: () => _open(context),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Hero(
                        tag: _heroTag,
                        child: ClipRRect(
                          borderRadius: tart.radius(24),
                          child: Opacity(
                            opacity: soldOut ? 0.55 : 1,
                            child: ProductPhoto(art: product.art, imageUrl: product.imageUrl, background: tart.tint(product.art)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      right: 10,
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (product.isSeasonal) _Chip('Limited', background: tart.deep, foreground: tart.onDeep),
                          if (product.isBestseller) _Chip('Bestseller', background: tart.accent, foreground: tart.onAccent),
                          if (soldOut)
                            _Chip('Sold out', background: tart.surface, foreground: tart.ink)
                          else if (product.isLowStock)
                            _Chip('Only ${product.stock} left', background: const Color(0xFFE11D48), foreground: Colors.white),
                        ],
                      ),
                    ),
                    if (rank != null)
                      Positioned(
                        left: 12,
                        bottom: -12,
                        child: Text(
                          '$rank',
                          style: displayFont(context, size: 54, weight: FontWeight.w800, color: Colors.white, height: 1).copyWith(
                            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 2))],
                          ),
                        ),
                      ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Semantics(
                        button: true,
                        label: product.hasSizes ? 'Choose a size for ${product.name}' : 'Add ${product.name} to cart',
                        child: Material(
                          color: tart.surface,
                          shape: product.hasSizes ? const StadiumBorder() : const CircleBorder(),
                          elevation: 0,
                          child: Ink(
                            decoration: ShapeDecoration(shape: product.hasSizes ? const StadiumBorder() : const CircleBorder(), shadows: shadow),
                            child: InkWell(
                              customBorder: product.hasSizes ? const StadiumBorder() : const CircleBorder(),
                              onTap: soldOut ? null : () => _quickAdd(context),
                              child: SizedBox(
                                height: 42,
                                width: product.hasSizes ? null : 42,
                                child: product.hasSizes
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 10, right: 14),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_rounded, size: 17, color: tart.ink),
                                            const SizedBox(width: 3),
                                            Text(
                                              product.sizes.map((size) => size.code).join(' · '),
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tart.ink),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Icon(Icons.add_rounded, size: 21, color: soldOut ? tart.inkSoft : tart.ink),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _textBlock(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tart.inkSoft),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(42),
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: displayFont(context, size: 17, color: tart.ink, height: 1.2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (reason != null)
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 13, color: tart.successInk),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reason!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tart.successInk),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          product.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: tart.inkSoft),
                        ),
                      const SizedBox(height: 7),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${product.hasSizes ? 'From ' : ''}${rm(product.fromPrice)}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: tart.isDark ? tart.accent : Color.lerp(tart.primary, Colors.black, 0.15)),
                            ),
                            TextSpan(
                              text: ' · ${product.unitLabel}',
                              style: TextStyle(color: tart.inkSoft),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ],
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

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.background, required this.foreground});

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.w800, color: foreground),
    ),
  );
}
