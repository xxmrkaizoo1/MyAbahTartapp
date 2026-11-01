import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/shop_models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_widgets.dart';
import 'order_detail_screen.dart';
import 'shop_shell.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  DeliveryMethod? _method;
  bool _prefilled = false;
  bool _placing = false;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _place(AppUser customer, Storefront storefront, DeliveryMethod method) async {
    if (!_form.currentState!.validate()) return;

    final cart = context.read<Cart>();
    final repository = context.read<ShopRepository>();
    final navigator = Navigator.of(context);
    final shell = ShopShell.of(context);
    setState(() => _placing = true);

    try {
      final code = await repository.placeOrder(
        customer: customer,
        lines: cart.lines,
        method: method,
        storefront: storefront,
        voucher: cart.voucher,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text,
      );

      // Remember contact details for next time, without overwriting ones already saved.
      if (customer.phone == null || (customer.address == null && method.requiresAddress)) {
        await repository.saveProfile(
          customer.uid,
          name: customer.name,
          email: customer.email,
          phone: customer.phone ?? _phone.text.trim(),
          address: customer.address ?? (method.requiresAddress ? _address.text.trim() : null),
        );
      }

      cart.clear();
      shell.goTo(ShopShell.orders);
      navigator.popUntil((route) => route.isFirst);
      navigator.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(code: code, justPlaced: true)));
    } on ShopException catch (error) {
      if (mounted) showMessage(context, error.message);
    } on FirebaseException catch (error) {
      if (mounted) showMessage(context, 'Couldn’t place your order: ${error.message ?? error.code}');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cart = context.watch<Cart>();
    final storefront = context.watch<Storefront>();
    final customer = auth.profile;

    if (customer == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(title: 'Your cart is empty', message: 'Add something tasty first.'),
      );
    }

    if (!_prefilled) {
      _phone.text = customer.phone ?? '';
      _address.text = customer.address ?? '';
      _prefilled = true;
    }

    final methods = storefront.enabledMethods;
    final method = methods.contains(_method) ? _method! : methods.first;
    final summary = cart.summary(storefront, method);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: staggered([
            const _StepLabel(number: 1, text: 'How would you like it?'),
            for (final option in methods)
              _DeliveryOption(
                method: option,
                storefront: storefront,
                subtotal: cart.subtotal,
                selected: option == method,
                onTap: () => setState(() => _method = option),
              ),
            const _StepLabel(number: 2, text: 'Your details'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', hintText: '012-345 6789', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (value) => (value ?? '').replaceAll(RegExp(r'\D'), '').length < 9 ? 'Enter a phone number we can reach you on.' : null,
            ),
            if (method.requiresAddress) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined), alignLabelWithHint: true),
                validator: (value) => (value ?? '').trim().length < 10 ? 'Enter your full delivery address.' : null,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Panel(
                color: context.tart.successSoft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Collect from\n${storefront.get('address')}\n${storefront.get('opening_hours')}', style: const TextStyle(height: 1.45)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Notes for the kitchen (optional)',
                hintText: 'Gift message, gate code…',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const _StepLabel(number: 3, text: 'Payment'),
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: context.tart.accent, borderRadius: context.tart.radius(14)),
                    child: Icon(Icons.payments_outlined, color: context.tart.onAccent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(method.requiresAddress ? 'Cash on delivery' : 'Pay at pickup', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          method.requiresAddress ? 'Pay in cash when your order arrives' : 'Pay in cash when you collect your order',
                          style: TextStyle(color: context.tart.inkSoft, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: context.tart.success),
                ],
              ),
            ),
            if (storefront.get('payment_online_enabled') == '1') ...[
              const SizedBox(height: 10),
              Opacity(
                opacity: 0.55,
                child: Panel(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: context.tart.line, borderRadius: context.tart.radius(14)),
                        child: Icon(Icons.lock_outline_rounded, color: context.tart.ink),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Online payment', style: TextStyle(fontWeight: FontWeight.w800)),
                            Text('FPX online banking, cards and e-wallets, secured by Billplz', style: TextStyle(color: context.tart.inkSoft, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Tag('Coming soon'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Panel(
              title: 'Order summary',
              child: Column(
                children: [
                  for (final line in cart.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('${line.quantity} × ${line.product.name}${line.size == null ? '' : ' (${line.size!.label})'}')),
                          Text(rm(line.lineTotal)),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  TotalsTable(
                    subtotal: summary.subtotal,
                    deliveryFee: summary.deliveryFee,
                    discount: summary.discount,
                    total: summary.total,
                    voucherCode: cart.voucher?.code,
                    deliveryLabel: storefront.label(method),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.tart.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(58)),
              onPressed: _placing ? null : () => _place(customer, storefront, method),
              child: AnimatedSwapText(_placing ? 'Placing your order…' : 'Place order · ${rm(summary.total)}', textAlign: TextAlign.center),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: context.tart.deep,
            child: Text(
              '$number',
              style: TextStyle(color: context.tart.accent, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ],
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({required this.method, required this.storefront, required this.subtotal, required this.selected, required this.onTap});

  final DeliveryMethod method;
  final Storefront storefront;
  final double subtotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fee = storefront.feeFor(method, subtotal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? context.tart.deep : context.tart.surface,
          borderRadius: context.tart.radius(22),
          border: Border.all(color: selected ? context.tart.deep : context.tart.line, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: context.tart.radius(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(method.icon, color: selected ? context.tart.accent : context.tart.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storefront.label(method),
                          style: TextStyle(fontWeight: FontWeight.w800, color: selected ? context.tart.onDeep : context.tart.ink),
                        ),
                        Text(
                          storefront.description(method),
                          style: TextStyle(fontSize: 13, color: selected ? context.tart.onDeep.withValues(alpha: 0.75) : context.tart.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    fee == 0 ? 'Free' : rm(fee),
                    style: TextStyle(fontWeight: FontWeight.w800, color: selected ? context.tart.accent : context.tart.ink),
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
