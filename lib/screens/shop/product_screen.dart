import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/product.dart';
import '../../models/shop_models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.productId, this.heroTag});

  final String productId;

  /// Matches the tapped card's picture so it flies into place.
  final String? heroTag;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> with SingleTickerProviderStateMixin {
  late final Stream<Product?> _product;
  late final Stream<List<Review>> _reviews;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  ProductSize? _size;
  bool _sizeChosen = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    final repository = context.read<ShopRepository>();
    _product = repository.product(widget.productId);
    _reviews = repository.reviews(widget.productId);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _addToBox(Product product) {
    final added = context.read<Cart>().add(product, _size, _quantity);
    if (added == 0) {
      showMessage(context, 'You already have all the ${product.name} we have left in your cart.');
      return;
    }
    showMessage(context, added < _quantity ? 'Only $added more could be added — that’s all we have left.' : 'Added $added × ${product.name} to your cart');
    setState(() => _quantity = 1);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: _product,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(appBar: AppBar(), body: ErrorView(snapshot.error));
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(), body: const LoadingView());
        final product = snapshot.data;
        if (product == null || !product.isActive) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(title: 'Off the menu', message: 'This tart isn’t available right now.'),
          );
        }

        if (!_sizeChosen) {
          _size = product.defaultSize;
          _sizeChosen = true;
        }
        final inBox = context.watch<Cart>().quantityOf(product, _size);
        final left = product.stockFor(_size) - inBox;
        final tint = context.tart.tint(product.art);
        final photo = product.imageFor(_size);
        final category = context.watch<List<MenuCategory>>().where((category) => category.id == product.categoryId).firstOrNull;

        return Scaffold(
          backgroundColor: context.tart.bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: photo == null ? 360 : MediaQuery.sizeOf(context).width.clamp(300, 460).toDouble(),
                backgroundColor: photo == null ? tint : context.tart.surface,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: context.tart.surface, foregroundColor: context.tart.ink),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: widget.heroTag ?? 'tart-page-${product.id}',
                    child: photo == null
                        ? ColoredBox(
                            color: tint,
                            child: SafeArea(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 30),
                                  child: RotationTransition(
                                    turns: _spin,
                                    child: TartArt(art: product.art, size: 250),
                                  ),
                                ),
                              ),
                            ),
                          )
                        // Each size can have its own photo; cross-fade when the size changes.
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: ProductPhoto(key: ValueKey(photo), art: product.art, imageUrl: photo),
                          ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(28),
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.tart.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 140),
                sliver: SliverList.list(
                  children: [
                    if (category != null) ...[FadeSlideIn(child: Eyebrow(category.name)), const SizedBox(height: 12)],
                    FadeSlideIn(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (product.isBestseller) const Tag('Bestseller', icon: Icons.local_fire_department_rounded),
                          if (product.isSeasonal) Tag('Limited edition', color: context.tart.deep, foreground: context.tart.onDeep, icon: Icons.auto_awesome),
                          Tag(product.unitDetail, color: context.tart.line, foreground: context.tart.ink),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(index: 1, child: Text(product.name, style: Theme.of(context).textTheme.displaySmall)),
                    const SizedBox(height: 6),
                    FadeSlideIn(
                      index: 2,
                      child: Text(
                        product.tagline,
                        style: TextStyle(fontSize: 16, color: context.tart.inkSoft, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AnimatedSwapText(rm(product.priceFor(_size)), style: displayFont(context, size: 30, color: context.tart.primary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StockHint(left: left, soldOut: product.stockFor(_size) < 1),
                      ],
                    ),
                    if (product.hasSizes) ...[
                      const SizedBox(height: 22),
                      const Text('Choose a size', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final size in product.sizes)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: size == product.sizes.last ? 0 : 10),
                                child: _SizeOption(
                                  product: product,
                                  size: size,
                                  selected: size == _size,
                                  onTap: () => setState(() {
                                    _size = size;
                                    _quantity = 1;
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    FadeSlideIn(index: 4, child: Text(product.description, style: const TextStyle(fontSize: 15.5, height: 1.6))),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 5,
                      child: _Reviews(product: product, reviews: _reviews),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.tart.surface,
                borderRadius: context.tart.radius(40),
                boxShadow: [BoxShadow(color: context.tart.deep.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  QuantityStepper(value: _quantity, max: left < 1 ? 1 : left, onChanged: (value) => setState(() => _quantity = value)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: context.tart.primary, foregroundColor: Colors.white),
                      onPressed: left < 1 ? null : () => _addToBox(product),
                      child: FittedBox(
                        child: AnimatedSwapText(
                          left < 1
                              ? (product.stockFor(_size) < 1 ? 'Sold out' : 'All in your cart')
                              : 'Add to cart · ${rm(product.priceFor(_size) * _quantity)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockHint extends StatelessWidget {
  const _StockHint({required this.left, required this.soldOut});

  final int left;
  final bool soldOut;

  @override
  Widget build(BuildContext context) {
    if (soldOut) return Tag('Sold out', color: context.tart.deep, foreground: context.tart.onDeep);
    if (left <= 10) return Tag(left < 1 ? 'All in your cart' : 'Only $left left', color: context.tart.primarySoft, foreground: context.tart.primary);
    return Tag('In stock', color: context.tart.successSoft, foreground: context.tart.successInk, icon: Icons.check_rounded);
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({required this.product, required this.size, required this.selected, required this.onTap});

  final Product product;
  final ProductSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soldOut = product.stockFor(size) < 1;
    final pieces = product.sizePieces[size.code];

    return Opacity(
      opacity: soldOut ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? context.tart.deep : context.tart.surface,
          borderRadius: context.tart.radius(20),
          border: Border.all(color: selected ? context.tart.deep : context.tart.line, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: context.tart.radius(20),
            onTap: soldOut ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    size.label,
                    style: TextStyle(fontWeight: FontWeight.w800, color: selected ? context.tart.accent : context.tart.ink),
                  ),
                  if (pieces != null && pieces > 0)
                    Text('$pieces pcs', style: TextStyle(fontSize: 12, color: selected ? context.tart.onDeep : context.tart.inkSoft)),
                  const SizedBox(height: 4),
                  Text(
                    soldOut ? 'Sold out' : rm(product.priceFor(size)),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? context.tart.onDeep : context.tart.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.product, required this.reviews});

  final Product product;
  final Stream<List<Review>> reviews;

  Future<void> _write(BuildContext context, AppUser user, Review? existing) async {
    final repository = context.read<ShopRepository>();
    final orders = await repository.myOrders(user.uid).first;
    final bought = orders.any((order) => order.status != OrderStatus.cancelled && order.items.any((item) => item.productId == product.id));
    if (!context.mounted) return;
    if (!bought) {
      showMessage(context, 'Only customers who bought this tart can review it.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(product: product, user: user, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return StreamBuilder<List<Review>>(
      stream: reviews,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Review>[];
        final average = list.isEmpty ? 0.0 : list.fold<int>(0, (acc, review) => acc + review.rating) / list.length;
        final mine = list.where((review) => review.userId == auth.uid).firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 10),
                if (list.isNotEmpty) ...[
                  _Stars(rating: average.round()),
                  const SizedBox(width: 6),
                  Text(
                    '${average.toStringAsFixed(1)} (${list.length})',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.tart.inkSoft),
                  ),
                ],
                const Spacer(),
                if (auth.profile != null)
                  TextButton.icon(
                    onPressed: () => _write(context, auth.profile!, mine),
                    icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit_outlined, size: 18),
                    label: Text(mine == null ? 'Write' : 'Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              Text('No reviews yet. Bought this one? Tell others what you thought.', style: TextStyle(color: context.tart.inkSoft))
            else
              for (final review in list.take(10))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.tart.surface,
                    borderRadius: context.tart.radius(20),
                    border: Border.all(color: context.tart.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          _Stars(rating: review.rating, size: 15),
                          if (auth.isAdmin)
                            IconButton(
                              tooltip: 'Delete review',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                              onPressed: () async {
                                final repository = context.read<ShopRepository>();
                                if (await confirm(
                                  context,
                                  title: 'Delete this review?',
                                  message: 'Review by ${review.userName} will be removed.',
                                  confirmLabel: 'Delete',
                                  destructive: true,
                                )) {
                                  await repository.deleteReview(product.id, review.userId);
                                  if (context.mounted) showMessage(context, 'Review by ${review.userName} deleted.');
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(review.comment, style: const TextStyle(height: 1.45)),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 18});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [for (var i = 1; i <= 5; i++) Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: const Color(0xFFE5A50A))],
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.product, required this.user, this.existing});

  final Product product;
  final AppUser user;
  final Review? existing;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 5;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_comment.text.trim().length < 5) {
      showMessage(context, 'Write at least a few words.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ShopRepository>().saveReview(productId: widget.product.id, user: widget.user, rating: _rating, comment: _comment.text.trim());
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Thanks for sharing your review!');
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save your review: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, MediaQuery.viewInsetsOf(context).bottom + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How was the ${widget.product.name}?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 36, color: const Color(0xFFE5A50A)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Flaky? Buttery? Tell us everything.'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Post review')),
          ),
        ],
      ),
    );
  }
}
