import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/cart.dart';
import '../../services/format.dart';
import '../../theme.dart';
import '../../widgets/motion.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

final shopShellKey = GlobalKey<ShopShellState>();

/// The customer app: five tabs behind a floating navigation pill.
class ShopShell extends StatefulWidget {
  const ShopShell({super.key});

  /// Works from pushed screens too, which are not descendants of the shell.
  static ShopShellState of(BuildContext context) => shopShellKey.currentState!;

  static const home = 0;
  static const menu = 1;
  static const cart = 2;
  static const orders = 3;
  static const profile = 4;

  @override
  State<ShopShell> createState() => ShopShellState();
}

class ShopShellState extends State<ShopShell> {
  int _index = ShopShell.home;

  /// The collection the menu tab should open on.
  final menuCategory = ValueNotifier<String?>(null);

  void goTo(int index) => setState(() => _index = index);

  void openMenu([String? categoryId]) {
    menuCategory.value = categoryId;
    goTo(ShopShell.menu);
  }

  @override
  void dispose() {
    menuCategory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == ShopShell.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(ShopShell.home);
      },
      child: Scaffold(
        extendBody: true,
        body: AnimatedTabStack(
          index: _index,
          children: [
            const HomeScreen(),
            MenuScreen(category: menuCategory),
            const CartScreen(),
            const OrdersScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _NavPill(index: _index, onSelected: goTo),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.cottage_outlined, Icons.cottage_rounded, 'Home'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Shop'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Cart'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    final cart = context.watch<Cart>();
    final cartCount = cart.count;
    final showCartPill = cartCount > 0 && index != ShopShell.cart;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The website's mobile "items · total · Checkout" pill, shown while the cart has something in it.
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: showCartPill
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CartPill(count: cartCount, subtotal: cart.subtotal, onTap: () => onSelected(ShopShell.cart)),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: tart.surface.withValues(alpha: 0.96),
              borderRadius: tart.radius(34),
              border: Border.all(color: tart.ink.withValues(alpha: 0.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: tart.isDark ? 0.5 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                for (final (i, (icon, activeIcon, label)) in _items.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      label: label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelected(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              // No overshoot: a bouncy curve would push the shadow's blur below zero and crash the bar.
                              curve: Curves.easeOutCubic,
                              width: i == index ? 56 : 40,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i == index ? tart.primary : Colors.transparent,
                                borderRadius: tart.radius(99),
                                boxShadow: i == index
                                    ? [BoxShadow(color: tart.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                                    : null,
                              ),
                              child: Badge(
                                isLabelVisible: i == ShopShell.cart && cartCount > 0,
                                label: TweenAnimationBuilder<double>(
                                  key: ValueKey(cartCount),
                                  tween: Tween(begin: 1.6, end: 1),
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.elasticOut,
                                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                                  child: Text('$cartCount'),
                                ),
                                backgroundColor: tart.accent,
                                textColor: tart.onAccent,
                                offset: const Offset(6, -4),
                                child: Icon(i == index ? activeIcon : icon, size: 22, color: i == index ? tart.onPrimary : tart.inkSoft),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                                color: i == index ? (tart.isDark ? tart.ink : tart.primary) : tart.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _CartPill extends StatelessWidget {
  const _CartPill({required this.count, required this.subtotal, required this.onTap});

  final int count;
  final double subtotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    return Pressable(
      scale: 0.98,
      child: Material(
        color: tart.deep,
        borderRadius: tart.radius(99),
        elevation: 10,
        shadowColor: Colors.black45,
        child: InkWell(
          onTap: onTap,
          borderRadius: tart.radius(99),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 7, 7, 7),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_rounded, size: 20, color: tart.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwapText(
                    '$count ${count == 1 ? 'item' : 'items'} · ${rm(subtotal)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tart.onDeep),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: tart.accent, borderRadius: tart.radius(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Checkout',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tart.onAccent),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: tart.onAccent),
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
}
