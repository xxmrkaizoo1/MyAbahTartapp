import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/order.dart';
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
import '../../widgets/product_card.dart';
import '../../widgets/tart_art.dart';
import '../../widgets/theme_picker.dart';
import 'order_detail_screen.dart';
import 'product_screen.dart';
import 'shop_shell.dart';

/// The website's home page (resources/views/shop/home.blade.php), laid out for a phone.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final storefront = context.watch<Storefront>();
    final products = context.watch<List<Product>?>()?.where((product) => product.isActive).toList();

    final available = products ?? const <Product>[];
    // Like the website, only collections with something on sale are shown.
    final categories = context.watch<List<MenuCategory>>().where((category) => available.any((product) => product.categoryId == category.id)).toList();
    final bestsellers = available.where((product) => product.isBestseller).take(4).toList();
    final featured = available.where((product) => product.isSeasonal && !product.isSoldOut).firstOrNull;
    final trending = [...bestsellers, ...available.where((product) => !product.isBestseller)].where((product) => !product.isSoldOut).take(8).toList();
    final newest = [...available]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    Widget section(Widget child, {double top = 40}) => Padding(padding: EdgeInsets.fromLTRB(20, top, 20, 0), child: child);

    final sections = <Widget>[
      _Hero(storefront: storefront, products: available, collections: categories.length, signedIn: auth.isSignedIn),
      _Ticker(storefront: storefront, products: available),
      if (auth.uid != null) _ActiveOrderTracker(uid: auth.uid!),
      if (products == null)
        const LoadingView()
      else if (products.isEmpty)
        section(
          Panel(
            child: Text(
              auth.isAdmin
                  ? 'The menu is empty. Open Kitchen mode from the Me tab and tap “Import website menu”.'
                  : 'Our team is setting up today’s menu. Check back soon!',
              style: const TextStyle(height: 1.4),
            ),
          ),
        )
      else ...[
        if (categories.isNotEmpty)
          section(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(eyebrow: 'Collections', title: 'Find your favourite', action: 'View all', onAction: () => ShopShell.of(context).openMenu()),
                const SizedBox(height: 18),
                _Collections(categories: categories, products: available),
              ],
            ),
          ),
        if (trending.isNotEmpty) ...[
          section(
            SectionHeader(
              eyebrow: auth.isSignedIn ? 'Picked for you' : 'Trending now',
              eyebrowIcon: Icons.auto_awesome_rounded,
              eyebrowColor: context.tart.isDark ? context.tart.success : context.tart.successInk,
              title: auth.isSignedIn ? 'Based on what you love' : 'What everyone’s ordering',
            ),
          ),
          const SizedBox(height: 18),
          _ProductCarousel(products: trending),
        ],
        if (featured != null)
          Padding(
            padding: const EdgeInsets.only(top: 44),
            child: _Spotlight(product: featured),
          ),
        if (bestsellers.isNotEmpty)
          section(
            Column(
              children: [
                SectionHeader(eyebrow: 'Bestsellers', title: 'This month’s favourites', action: 'See all', onAction: () => ShopShell.of(context).openMenu()),
                const SizedBox(height: 18),
                _ProductGrid(products: bestsellers, heroScope: 'home-best', ranked: true),
              ],
            ),
          ),
      ],
      section(_HowItWorks(storefront: storefront), top: 44),
      if (newest.isNotEmpty)
        section(
          Column(
            children: [
              SectionHeader(eyebrow: 'Just landed', title: 'New on the menu', action: 'See all', onAction: () => ShopShell.of(context).openMenu()),
              const SizedBox(height: 18),
              _ProductGrid(products: newest.take(4).toList(), heroScope: 'home-new'),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 44),
        child: _Footer(storefront: storefront, categories: categories),
      ),
      SizedBox(height: navClearance(context)),
    ];

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TopBar(storefront: storefront)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(profile: auth.profile, theme: context.tart),
          ),
          // Each section rises into place, one after another.
          for (final (index, child) in sections.indexed)
            SliverToBoxAdapter(
              child: FadeSlideIn(index: index, child: child),
            ),
        ],
      ),
    );
  }
}

/// The dark announcement strip above the header.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.storefront});

  final Storefront storefront;

  @override
  Widget build(BuildContext context) {
    if (storefront.get('topbar_enabled') != '1') return const SizedBox.shrink();
    final freeOver = storefront.get('topbar_free_delivery') == '1' ? storefront.freeDeliveryThreshold : null;
    final announcement = storefront.get('announcement');
    final text = [if (freeOver != null) 'Free delivery over ${rm(freeOver)}', if (announcement.isNotEmpty) announcement].join(' · ');
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      color: context.tart.deep,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_rounded, size: 16, color: context.tart.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.tart.onDeep, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating header bar that stays at the top while scrolling.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.profile, required this.theme});

  final AppUser? profile;
  final TartTheme theme;

  @override
  double get minExtent => 76;

  @override
  double get maxExtent => 76;

  @override
  bool shouldRebuild(_HeaderDelegate oldDelegate) => oldDelegate.profile != profile || oldDelegate.theme != theme;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final tart = theme;
    final profile = this.profile;
    final scrolled = overlapsContent || shrinkOffset > 0;

    // A pinned header must fill its whole extent.
    return Container(
      height: maxExtent,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
        decoration: BoxDecoration(
          color: tart.surface.withValues(alpha: scrolled ? 0.97 : 0.8),
          borderRadius: tart.radius(32),
          border: Border.all(color: tart.ink.withValues(alpha: 0.07)),
          boxShadow: [
            if (scrolled)
              BoxShadow(
                color: Colors.black.withValues(alpha: tart.isDark ? 0.5 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Row(
          children: [
            // Shrinks a little on narrow phones with large text instead of overflowing.
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: BrandLogo(size: 42)),
              ),
            ),
            IconButton(
              tooltip: 'Change design',
              onPressed: () => showThemePicker(context),
              icon: Icon(Icons.palette_outlined, color: tart.ink),
            ),
            if (profile != null)
              Material(
                color: Colors.transparent,
                shape: StadiumBorder(side: BorderSide(color: tart.ink.withValues(alpha: 0.1))),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => ShopShell.of(context).goTo(ShopShell.profile),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: tart.accent,
                          child: Text(
                            profile.initials,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tart.onAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            profile.firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 18)),
                onPressed: () => ShopShell.of(context).goTo(ShopShell.profile),
                child: const Text('Sign in'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A soft blurred colour glow, like the website's background blobs.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.storefront, required this.products, required this.collections, required this.signedIn});

  final Storefront storefront;
  final List<Product> products;
  final int collections;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final headline = displayFont(context, size: 40, weight: FontWeight.w800, height: 1.08);
    final freeOver = storefront.freeDeliveryThreshold;
    final stats = [
      ('${products.length}', 'Products'),
      ('$collections', 'Collections'),
      if (freeOver != null) ('RM${freeOver.toStringAsFixed(0)}+', 'Free delivery') else ('Fresh', 'Every order'),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -140,
          right: -140,
          child: _Glow(color: tart.accent.withValues(alpha: tart.isDark ? 0.18 : 0.4), size: 380),
        ),
        Positioned(
          top: 320,
          left: -170,
          child: _Glow(color: tart.primary.withValues(alpha: tart.isDark ? 0.16 : 0.22), size: 360),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            children: [
              if (storefront.get('hero_badge').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: tart.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: tart.ink.withValues(alpha: 0.05)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: tart.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(storefront.get('hero_badge'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${storefront.get('hero_title_start')} '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Squiggle(
                        color: tart.accent,
                        child: Text(storefront.get('hero_title_highlight'), style: headline.copyWith(color: tart.isDark ? tart.accent : tart.primary)),
                      ),
                    ),
                    TextSpan(text: ' ${storefront.get('hero_title_end')}'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: headline,
              ),
              if (storefront.get('hero_intro').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  storefront.get('hero_intro'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.5, height: 1.55, color: tart.inkSoft),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tart.primary,
                    foregroundColor: tart.onPrimary,
                    elevation: 6,
                    shadowColor: tart.primary.withValues(alpha: 0.5),
                  ),
                  onPressed: () => ShopShell.of(context).openMenu(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(storefront.get('hero_button').isEmpty ? 'Shop the menu' : storefront.get('hero_button')),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(backgroundColor: tart.surface.withValues(alpha: 0.8), minimumSize: const Size(64, 54)),
                  onPressed: () => ShopShell.of(context).goTo(signedIn ? ShopShell.orders : ShopShell.profile),
                  child: Text(signedIn ? 'Track my order' : 'Create an account'),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  for (final (index, (value, label)) in stats.indexed) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: tart.surface.withValues(alpha: 0.7),
                          borderRadius: tart.radius(18),
                          border: Border.all(color: tart.ink.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tart.inkSoft),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(value, style: displayFont(context, size: 22, weight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              _Collage(storefront: storefront, products: products),
            ],
          ),
        ),
      ],
    );
  }
}

/// The round hero photo with two floating product bubbles and the limited-edition card.
class _Collage extends StatelessWidget {
  const _Collage({required this.storefront, required this.products});

  final Storefront storefront;
  final List<Product> products;

  void _open(BuildContext context, Product product, String tag) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductScreen(productId: product.id, heroTag: tag),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final floaters = products.where((product) => product.imageUrl != null).take(2).toList();
    final featured = products.where((product) => product.isSeasonal && !product.isSoldOut).firstOrNull;
    final pop = [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 40, offset: const Offset(0, 20))];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 360.0);
        final bubble = size * 0.3;

        return SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: size * 0.06,
                top: size * 0.06,
                right: size * 0.06,
                bottom: size * 0.06,
                child: Container(
                  decoration: BoxDecoration(
                    color: tart.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: tart.surface, width: 8),
                    boxShadow: pop,
                  ),
                  child: ClipOval(
                    child: ProductPhoto(art: 'pineapple', imageUrl: storefront.get('hero_image'), background: tart.accent),
                  ),
                ),
              ),
              for (final (index, product) in floaters.indexed)
                Positioned(
                  left: index == 0 ? -size * 0.02 : null,
                  top: index == 0 ? -size * 0.02 : null,
                  right: index == 1 ? -size * 0.02 : null,
                  bottom: index == 1 ? size * 0.12 : null,
                  child: Floating(
                    distance: 10,
                    phase: index * 0.25,
                    child: GestureDetector(
                      onTap: () => _open(context, product, 'tart-hero-${product.id}'),
                      child: Container(
                        width: bubble,
                        height: bubble,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tart.surface, width: 4),
                          boxShadow: pop,
                        ),
                        child: Hero(
                          tag: 'tart-hero-${product.id}',
                          child: ClipOval(
                            child: ProductPhoto(art: product.art, imageUrl: product.imageUrl),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (featured != null)
                Positioned(
                  left: size * 0.02,
                  bottom: size * 0.02,
                  right: size * 0.2,
                  child: GestureDetector(
                    onTap: () => _open(context, featured, 'tart-feature-${featured.id}'),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                      decoration: BoxDecoration(color: tart.surface.withValues(alpha: 0.96), borderRadius: tart.radius(18), boxShadow: pop),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: tart.deep, borderRadius: tart.radius(12)),
                            child: Icon(Icons.auto_awesome_rounded, color: tart.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LIMITED EDITION',
                                  style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: tart.primary),
                                ),
                                Text(
                                  featured.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${featured.hasSizes ? 'From ' : ''}${rm(featured.fromPrice)} · ${featured.stock} left today',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: tart.inkSoft),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The coloured band of scrolling product names.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.storefront, required this.products});

  final Storefront storefront;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    var names = storefront.tickerItems;
    if (names.isEmpty) names = products.map((product) => product.name).toList();
    if (names.isEmpty) names = const ['Prepared fresh daily'];
    // Repeat so one copy is always wider than the screen.
    final items = [for (var i = 0; i < (12 / names.length).ceil(); i++) ...names];

    return ExcludeSemantics(
      child: Container(
        color: tart.primary,
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Marquee(
          height: 28,
          child: Row(
            children: [
              for (final name in items) ...[
                Text(
                  name,
                  style: displayFont(context, size: 18, weight: FontWeight.w700, color: tart.onPrimary),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Icon(Icons.auto_awesome_rounded, size: 18, color: tart.isDark ? tart.onPrimary : tart.accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A live card for the customer's newest order that is still in progress.
class _ActiveOrderTracker extends StatefulWidget {
  const _ActiveOrderTracker({required this.uid});

  final String uid;

  @override
  State<_ActiveOrderTracker> createState() => _ActiveOrderTrackerState();
}

class _ActiveOrderTrackerState extends State<_ActiveOrderTracker> {
  late Stream<List<ShopOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = context.read<ShopRepository>().myOrders(widget.uid);
  }

  @override
  void didUpdateWidget(_ActiveOrderTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _orders = context.read<ShopRepository>().myOrders(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;

    return StreamBuilder<List<ShopOrder>>(
      stream: _orders,
      builder: (context, snapshot) {
        final active = snapshot.data?.where((order) => order.status.isActive).toList() ?? const [];
        if (active.isEmpty) return const SizedBox.shrink();
        final order = active.first;
        final step = OrderStatus.timeline.indexOf(order.status);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Pressable(
            scale: 0.98,
            child: Material(
              color: tart.deep,
              borderRadius: tart.radius(26),
              elevation: 8,
              shadowColor: Colors.black38,
              child: InkWell(
                borderRadius: tart.radius(26),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(code: order.code))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: tart.accent, borderRadius: tart.radius(16)),
                            child: Icon(Icons.soup_kitchen_rounded, color: tart.onAccent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order ${order.code} is on its way through the kitchen',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tart.onDeep.withValues(alpha: 0.65)),
                                ),
                                const SizedBox(height: 2),
                                AnimatedSwapText(order.statusLabel, style: displayFont(context, size: 19, color: tart.onDeep)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 400 + i * 120),
                                curve: Curves.easeOutCubic,
                                height: 6,
                                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                                decoration: BoxDecoration(
                                  color: i <= step ? tart.accent : tart.onDeep.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ${rm(order.total)}'
                              '${order.status == OrderStatus.ready ? '' : ' · ready ~${clockTime(order.estimatedReadyAt()!)}'}',
                              style: TextStyle(color: tart.onDeep.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: tart.accent, borderRadius: BorderRadius.circular(99)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Track order',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tart.onAccent),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 15, color: tart.onAccent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Colourful collection tiles with a round photo peeking out of the corner; the first one is big.
class _Collections extends StatelessWidget {
  const _Collections({required this.categories, required this.products});

  final List<MenuCategory> categories;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final colours = [tart.accentSoft, tart.primarySoft, const Color(0xFFF3E2D6), tart.successSoft, const Color(0xFFEFE3F6)];

    Widget tile(int index, MenuCategory category, {required bool big}) {
      final count = products.where((product) => product.categoryId == category.id).length;
      final colour = tart.isDark ? Color.lerp(colours[index % colours.length], tart.surface, 0.82)! : colours[index % colours.length];
      final photo = big ? 190.0 : 108.0;

      return Pressable(
        child: Material(
          color: colour,
          borderRadius: tart.radius(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ShopShell.of(context).openMenu(category.id),
            child: SizedBox(
              width: double.infinity,
              height: big ? 196 : 158,
              child: Stack(
                children: [
                  Positioned(
                    right: big ? -30 : -22,
                    bottom: big ? -34 : -22,
                    child: SizedBox.square(
                      dimension: photo,
                      child: ClipOval(
                        child: ProductPhoto(art: category.art, imageUrl: category.imageUrl),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: displayFont(context, size: big ? 32 : 19, weight: FontWeight.w800, height: 1.05),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count product${count == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tart.ink.withValues(alpha: 0.6)),
                        ),
                        const Spacer(),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tart.surface,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Icon(Icons.arrow_forward_rounded, size: 19, color: tart.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final rest = categories.skip(1).toList();
    return Column(
      children: [
        tile(0, categories.first, big: true),
        for (var row = 0; row < rest.length; row += 2) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: tile(row + 1, rest[row], big: false)),
              const SizedBox(width: 12),
              Expanded(child: row + 1 < rest.length ? tile(row + 2, rest[row + 1], big: false) : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }
}

/// A sideways-scrolling row of product cards.
class _ProductCarousel extends StatelessWidget {
  const _ProductCarousel({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final width = min(MediaQuery.sizeOf(context).width * 0.6, 240.0);
    return SizedBox(
      height: ProductCard.heightFor(context, width) + 6,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, index) => FadeSlideIn(
          index: index + 2,
          axis: Axis.horizontal,
          offset: 30,
          child: ProductCard(product: products[index], heroScope: 'home-trend', width: width),
        ),
      ),
    );
  }
}

/// Two product cards per row.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.heroScope, this.ranked = false});

  final List<Product> products;
  final String heroScope;
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 22,
          children: [
            for (final (index, product) in products.indexed) ProductCard(product: product, heroScope: heroScope, width: width, rank: ranked ? index + 1 : null),
          ],
        );
      },
    );
  }
}

/// The dark "Limited edition" band with a spinning dashed ring around the product.
class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final tag = 'tart-spotlight-${product.id}';
    void open() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductScreen(productId: product.id, heroTag: tag),
      ),
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: tart.deep),
      child: Stack(
        children: [
          Positioned(top: -100, left: -100, child: _Glow(color: tart.primary.withValues(alpha: 0.35), size: 320)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 250,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _SpinningRing(color: tart.accent.withValues(alpha: 0.45))),
                      Positioned.fill(
                        left: 20,
                        top: 20,
                        right: 20,
                        bottom: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 8),
                          ),
                          child: Hero(
                            tag: tag,
                            child: ClipOval(
                              child: ProductPhoto(art: product.art, imageUrl: product.imageUrl),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 4,
                        child: Transform.rotate(
                          angle: 0.2,
                          child: Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: tart.accent, shape: BoxShape.circle),
                            child: Text(
                              'Only\n${product.stock} left',
                              textAlign: TextAlign.center,
                              style: displayFont(context, size: 14, weight: FontWeight.w800, color: tart.onAccent, height: 1.1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Eyebrow('Limited edition', color: tart.accent),
                const SizedBox(height: 10),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: displayFont(context, size: 34, weight: FontWeight.w800, color: tart.onDeep, height: 1.05),
                ),
                const SizedBox(height: 12),
                Text(
                  product.description,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tart.onDeep.withValues(alpha: 0.7), height: 1.55),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text(
                      'Today’s batch',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tart.onDeep.withValues(alpha: 0.6)),
                    ),
                    const Spacer(),
                    Text(
                      '${product.stock} remaining',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tart.onDeep.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (product.stock / max(product.stock, product.lowStockThreshold * 3)).clamp(0.06, 1.0)),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) =>
                        LinearProgressIndicator(value: value, minHeight: 8, color: tart.accent, backgroundColor: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${product.hasSizes ? 'From ' : ''}${rm(product.fromPrice)}',
                          style: displayFont(context, size: 26, weight: FontWeight.w800, color: tart.onDeep),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: tart.accent,
                        foregroundColor: tart.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                      ),
                      onPressed: () {
                        if (product.hasSizes) return open();
                        final added = context.read<Cart>().add(product, null, 1);
                        showMessage(context, added > 0 ? '${product.name} added to your cart' : 'No more ${product.name} left in stock');
                      },
                      child: const Text('Order now'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: open,
                    style: TextButton.styleFrom(foregroundColor: tart.onDeep),
                    child: const Text('Details'),
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

class _SpinningRing extends StatefulWidget {
  const _SpinningRing({required this.color});

  final Color color;

  @override
  State<_SpinningRing> createState() => _SpinningRingState();
}

class _SpinningRingState extends State<_SpinningRing> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = CustomPaint(painter: _DashedCircle(widget.color));
    if (MediaQuery.disableAnimationsOf(context)) return ring;
    return RotationTransition(turns: _controller, child: ring);
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    const dashes = 60;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1), i / dashes * 2 * pi, pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => oldDelegate.color != color;
}

/// "How it works": three numbered steps on a white card.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.storefront});

  final Storefront storefront;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    const icons = [Icons.shopping_bag_rounded, Icons.soup_kitchen_rounded, Icons.local_shipping_rounded];

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      decoration: BoxDecoration(
        color: tart.surface,
        borderRadius: tart.radius(32),
        border: Border.all(color: tart.ink.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Column(
        children: [
          SectionHeader(eyebrow: 'How it works', title: storefront.get('steps_title'), center: true),
          for (var step = 1; step <= 3; step++) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: 92,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: tart.primarySoft,
                      borderRadius: tart.radius(22),
                      border: Border.all(color: tart.primary.withValues(alpha: 0.12)),
                    ),
                    child: Icon(icons[step - 1], size: 28, color: tart.isDark ? tart.ink : tart.primary),
                  ),
                  Positioned(
                    top: -2,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tart.deep,
                        shape: BoxShape.circle,
                        border: Border.all(color: tart.surface, width: 2),
                      ),
                      child: Text(
                        '$step',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tart.onDeep),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(storefront.get('step_${step}_title'), textAlign: TextAlign.center, style: displayFont(context, size: 19)),
            const SizedBox(height: 6),
            Text(
              storefront.get('step_${step}_text'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: tart.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// The website footer: about text, theme swatches, collections and the shop's address.
class _Footer extends StatelessWidget {
  const _Footer({required this.storefront, required this.categories});

  final Storefront storefront;
  final List<MenuCategory> categories;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final soft = tart.onDeep.withValues(alpha: 0.7);
    final heading = displayFont(context, size: 16, color: tart.onDeep);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: tart.deep, borderRadius: tart.radius(32)),
      child: Stack(
        children: [
          Positioned(top: -120, right: -90, child: _Glow(color: tart.primary.withValues(alpha: 0.35), size: 340)),
          Positioned(bottom: -140, left: -100, child: _Glow(color: tart.accent.withValues(alpha: 0.18), size: 340)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: 64, light: true),
                const SizedBox(height: 16),
                Text(storefront.get('footer_about'), style: TextStyle(color: soft, height: 1.6, fontSize: 14)),
                const SizedBox(height: 22),
                Text(
                  'COLOUR THEME',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: tart.onDeep.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 10),
                const ThemeSwatches(onDark: true),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Shop', style: heading),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final category in categories)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: soft, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          onPressed: () => ShopShell.of(context).openMenu(category.id),
                          child: Text(category.name),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Text('Visit our shop', style: heading),
                const SizedBox(height: 10),
                Text(storefront.get('address'), style: TextStyle(color: soft, height: 1.55)),
                if (storefront.get('opening_hours').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: tart.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          storefront.get('opening_hours'),
                          style: TextStyle(color: soft, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 26),
                Divider(color: tart.onDeep.withValues(alpha: 0.1), height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '© ${DateTime.now().year} MYabah Tart Lejen. All rights reserved.',
                    style: TextStyle(fontSize: 12, color: tart.onDeep.withValues(alpha: 0.5)),
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
