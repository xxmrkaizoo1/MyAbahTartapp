import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/refund.dart';
import '../../models/shop_models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/refund_widgets.dart';
import 'shop_shell.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.code, this.justPlaced = false});

  final String code;
  final bool justPlaced;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final Stream<ShopOrder?> _order = context.read<ShopRepository>().order(widget.code);
  late final Stream<List<Refund>> _refunds = context.read<ShopRepository>().refundsForOrder(widget.code, userId: context.read<AuthService>().uid ?? '-');

  Future<void> _requestRefund(ShopOrder order, List<Refund> refunds) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => RequestRefundSheet(order: order, refunds: refunds),
  );

  Future<void> _cancel(ShopOrder order) async {
    final picked = await showModalBottomSheet<(CancellationReason, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CancelSheet(reasons: CancellationReason.forCustomers, title: 'Why are you cancelling?'),
    );
    if (picked == null || !mounted) return;

    try {
      await context.read<ShopRepository>().cancelOrder(order.code, picked.$1, note: picked.$2, byCustomer: true);
      if (mounted) showMessage(context, 'Order ${order.code} has been cancelled.');
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _reorder(ShopOrder order) async {
    final repository = context.read<ShopRepository>();
    final cart = context.read<Cart>();
    var added = 0;

    for (final item in order.items) {
      final product = await repository.productOnce(item.productId);
      if (product == null || !product.isActive) continue;
      if (item.size != null && !product.sizes.contains(item.size)) continue;
      added += cart.add(product, item.size, item.quantity) > 0 ? 1 : 0;
    }
    if (!mounted) return;

    if (added == 0) {
      showMessage(context, 'Sorry, the items in this order are no longer available.');
      return;
    }
    ShopShell.of(context).goTo(ShopShell.cart);
    Navigator.of(context).popUntil((route) => route.isFirst);
    showMessage(context, 'Items from your past order are back in your cart.');
  }

  @override
  Widget build(BuildContext context) {
    final storefront = context.watch<Storefront>();

    return StreamBuilder<ShopOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(appBar: AppBar(), body: ErrorView(snapshot.error));
        final order = snapshot.data;
        if (order == null) return Scaffold(appBar: AppBar(), body: const LoadingView());

        final cancelled = order.status == OrderStatus.cancelled;

        return Scaffold(
          appBar: AppBar(title: Text(order.code)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: staggered([
              if (widget.justPlaced && !cancelled)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: context.tart.successSoft, borderRadius: context.tart.radius(22)),
                  child: Row(
                    children: [
                      Icon(Icons.celebration_rounded, color: context.tart.successInk),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Thank you! Your order is in. We’ll update this page as it moves along.',
                          style: TextStyle(fontWeight: FontWeight.w700, color: context.tart.successInk),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: cancelled ? const Color(0xFF5A2A26) : context.tart.deep, borderRadius: context.tart.radius(30)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS',
                      style: TextStyle(color: context.tart.onDeep.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwapText(order.statusLabel, style: displayFont(context, size: 30, color: context.tart.accent)),
                    const SizedBox(height: 4),
                    Text('Placed ${shortDateTime(order.createdAt)}', style: TextStyle(color: context.tart.onDeep.withValues(alpha: 0.75))),
                    if (order.status == OrderStatus.received || order.status == OrderStatus.preparing) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 18, color: context.tart.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${order.deliveryMethod.requiresAddress ? 'Leaves the kitchen' : 'Ready'} around ${clockTime(order.estimatedReadyAt()!)}',
                              style: TextStyle(color: context.tart.onDeep, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cancelled && order.cancellationReason != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Reason: ${order.cancellationReason!.label}${order.cancellationNote == null ? '' : ' — ${order.cancellationNote}'}',
                        style: TextStyle(color: context.tart.onDeep),
                      ),
                    ],
                  ],
                ),
              ),
              if (!cancelled) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Progress',
                  child: OrderTimeline(order: order),
                ),
              ],
              const SizedBox(height: 16),
              Panel(
                title: storefront.label(order.deliveryMethod),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: order.deliveryMethod.icon,
                      text: order.deliveryMethod.requiresAddress ? (order.address ?? '') : 'Collect from ${storefront.get('address')}',
                    ),
                    _InfoRow(icon: Icons.phone_outlined, text: order.phone),
                    _InfoRow(icon: Icons.payments_outlined, text: order.paymentLabel),
                    if (order.notes != null) _InfoRow(icon: Icons.edit_note_rounded, text: order.notes!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                title: '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                child: Column(
                  children: [
                    OrderItemsList(order: order),
                    const Divider(height: 24),
                    TotalsTable(
                      subtotal: order.subtotal,
                      deliveryFee: order.deliveryFee,
                      discount: order.discount,
                      total: order.total,
                      voucherCode: order.voucherCode,
                      deliveryLabel: storefront.label(order.deliveryMethod),
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<Refund>>(
                stream: _refunds,
                builder: (context, refundSnapshot) {
                  final refunds = refundSnapshot.data ?? const <Refund>[];
                  final canRequest = refundSnapshot.hasData && order.canRequestRefund(refunds);
                  if (refunds.isEmpty && !canRequest) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (refunds.isNotEmpty) ...[
                          Text('Refunds', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          for (final refund in refunds) RefundTile(refund: refund),
                        ],
                        if (canRequest)
                          OutlinedButton.icon(
                            onPressed: () => _requestRefund(order, refunds),
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Something wrong? Request a refund'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              if (order.status == OrderStatus.received)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => _cancel(order),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel order'),
                ),
              if (!order.status.isActive)
                FilledButton.icon(onPressed: () => _reorder(order), icon: const Icon(Icons.replay_rounded), label: const Text('Order again')),
            ]),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

/// Asks for a cancellation reason (and a note when "Something else" is picked).
class CancelSheet extends StatefulWidget {
  const CancelSheet({super.key, required this.reasons, required this.title});

  final List<CancellationReason> reasons;
  final String title;

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  CancellationReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsNote = _reason == CancellationReason.other;
    final canSubmit = _reason != null && (!needsNote || _note.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            RadioGroup<CancellationReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in widget.reasons)
                    RadioListTile<CancellationReason>(contentPadding: EdgeInsets.zero, value: reason, title: Text(reason.label)),
                ],
              ),
            ),
            if (needsNote)
              TextField(
                controller: _note,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Tell us a little more'),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
                onPressed: canSubmit ? () => Navigator.pop(context, (_reason!, needsNote ? _note.text.trim() : null)) : null,
                child: const Text('Cancel order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
