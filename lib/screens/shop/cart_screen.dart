import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/shop_models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/tart_art.dart';
import '../auth/sign_in_screen.dart';
import 'checkout_screen.dart';
import 'shop_shell.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _checkout(BuildContext context) async {
    final auth = context.read<AuthService>();
    if (!auth.isSignedIn) {
      final signedIn = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SignInScreen(reason: 'Sign in to place your order')));
      if (signedIn != true || !context.mounted) return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final storefront = context.watch<Storefront>();

    if (cart.isEmpty) {
      return SafeArea(
        child: EmptyState(
          art: 'berry',
          title: 'Your cart is empty',
          message: 'Fill it with pineapple tarts, egg tarts and everything in between.',
          action: 'Browse the menu',
          onAction: () => ShopShell.of(context).openMenu(),
        ),
      );
    }

    final threshold = storefront.freeDeliveryThreshold;
    final remaining = threshold == null ? 0.0 : threshold - cart.subtotal;
    final total = (cart.subtotal - cart.discount).clamp(0, double.infinity).toDouble();

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: ListView(
            // Room for the checkout bar pinned above the navigation.
            padding: EdgeInsets.fromLTRB(20, 16, 20, navClearance(context) + 76),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Your cart', style: Theme.of(context).textTheme.headlineMedium)),
                  TextButton(
                    onPressed: () async {
                      if (await confirm(
                        context,
                        title: 'Empty your cart?',
                        message: 'This removes every item.',
                        confirmLabel: 'Empty cart',
                        destructive: true,
                      )) {
                        cart.clear();
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              Text('${cart.count} item${cart.count == 1 ? '' : 's'}', style: TextStyle(color: context.tart.inkSoft)),
              const SizedBox(height: 16),
              for (final (index, line) in cart.lines.indexed)
                FadeSlideIn(
                  key: ValueKey(line.key),
                  index: index,
                  child: _CartLineTile(line: line),
                ),
              if (threshold != null) ...[const SizedBox(height: 6), _FreeDeliveryMeter(subtotal: cart.subtotal, threshold: threshold, remaining: remaining)],
              const SizedBox(height: 16),
              const _VoucherField(),
              const SizedBox(height: 16),
              Panel(
                child: TotalsTable(subtotal: cart.subtotal, deliveryFee: null, discount: cart.discount, total: total, voucherCode: cart.voucher?.code),
              ),
            ],
          ),
        ),
        // Always reachable, just above the bottom navigation (whose height the shell reports as bottom padding).
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 8,
          child: _CheckoutBar(total: total, count: cart.count, onCheckout: () => _checkout(context)),
        ),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<Cart>();

    return Dismissible(
      key: ValueKey(line.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => cart.remove(line),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: context.tart.primary, borderRadius: context.tart.radius(24)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tart.surface,
          borderRadius: context.tart.radius(24),
          border: Border.all(color: context.tart.line),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: ClipRRect(
                borderRadius: context.tart.radius(18),
                child: ProductPhoto(art: line.product.art, imageUrl: line.product.imageFor(line.size), background: context.tart.tint(line.product.art)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: displayFont(context, size: 15.5, color: context.tart.ink, height: 1.15),
                  ),
                  Text(
                    line.size == null ? line.product.unitLabel : line.product.sizeLabel(line.size!),
                    style: TextStyle(fontSize: 12.5, color: context.tart.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      QuantityStepper(compact: true, value: line.quantity, min: 0, max: line.maxQuantity, onChanged: (value) => cart.setQuantity(line, value)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(rm(line.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeDeliveryMeter extends StatelessWidget {
  const _FreeDeliveryMeter({required this.subtotal, required this.threshold, required this.remaining});

  final double subtotal;
  final double threshold;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.tart.successSoft, borderRadius: context.tart.radius(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, size: 20, color: context.tart.successInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  remaining > 0 ? 'Add ${rm(remaining)} more for free standard delivery' : 'You’ve unlocked free standard delivery!',
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.tart.successInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: context.tart.radius(99),
            child: LinearProgressIndicator(
              value: (subtotal / threshold).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: context.tart.surface.withValues(alpha: 0.7),
              color: context.tart.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherField extends StatefulWidget {
  const _VoucherField();

  @override
  State<_VoucherField> createState() => _VoucherFieldState();
}

class _VoucherFieldState extends State<_VoucherField> {
  final _code = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final cart = context.read<Cart>();
    setState(() => _checking = true);
    try {
      final voucher = await context.read<ShopRepository>().voucher(_code.text);
      if (!mounted) return;
      if (voucher == null || !voucher.isUsable) {
        showMessage(context, 'That voucher code isn’t valid.');
        return;
      }
      cart.applyVoucher(voucher);
      _code.clear();
      FocusScope.of(context).unfocus();
      showMessage(
        context,
        cart.discount > 0 ? 'Voucher applied — you save ${rm(cart.discount)}' : 'Voucher saved. Spend ${rm(voucher.minSubtotal)} to use it.',
      );
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t check that code: $error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final voucher = cart.voucher;

    if (voucher != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        decoration: BoxDecoration(
          color: context.tart.accent.withValues(alpha: 0.35),
          borderRadius: context.tart.radius(20),
          border: Border.all(color: context.tart.accent),
        ),
        child: Row(
          children: [
            Icon(Icons.confirmation_number_rounded, color: context.tart.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voucher.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    cart.discount > 0 ? voucher.description : 'Spend ${rm(voucher.minSubtotal - cart.subtotal)} more to use this voucher',
                    style: TextStyle(fontSize: 12.5, color: context.tart.inkSoft),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: cart.removeVoucher, icon: const Icon(Icons.close_rounded), tooltip: 'Remove voucher'),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Voucher code', prefixIcon: Icon(Icons.confirmation_number_outlined)),
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: _checking ? null : _apply, child: Text(_checking ? '…' : 'Apply')),
      ],
    );
  }
}

/// The total and a Checkout button, pinned above the navigation like the pill on the other tabs.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total, required this.count, required this.onCheckout});

  final double total;
  final int count;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final tart = context.tart;
    return Material(
      color: tart.deep,
      borderRadius: tart.radius(99),
      elevation: 10,
      shadowColor: Colors.black45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 7, 7, 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total · $count item${count == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tart.onDeep.withValues(alpha: 0.65)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwapText(
                      rm(total),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tart.onDeep),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tart.accent,
                foregroundColor: tart.onAccent,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: onCheckout,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
