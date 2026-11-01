import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/refund.dart';
import '../../models/shop_models.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/refund_widgets.dart';
import '../shop/order_detail_screen.dart';

/// Online orders by kitchen step. Counter sales live on the Counter tab.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key, required this.orders});

  final List<ShopOrder> orders;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _query = '';

  bool _matches(ShopOrder order) => _query.isEmpty || '${order.code} ${order.customerName} ${order.phone} ${order.email}'.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders.where((order) => !order.isCounterSale && _matches(order)).toList();
    final tabs = <(String, List<ShopOrder>)>[
      ('New', orders.where((order) => order.status == OrderStatus.received).toList().reversed.toList()),
      ('Preparing', orders.where((order) => order.status == OrderStatus.preparing).toList().reversed.toList()),
      ('Ready', orders.where((order) => order.status == OrderStatus.ready).toList().reversed.toList()),
      ('Done', orders.where((order) => !order.status.isActive).toList()),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(hintText: 'Search code, name or phone', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            tabs: [for (final (label, list) in tabs) Tab(text: '$label · ${list.length}')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final (label, list) in tabs)
                  list.isEmpty
                      ? Center(
                          child: Text('No ${label.toLowerCase()} orders', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: staggered([for (final order in list) AdminOrderTile(order: order)]),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One order with a one-tap button to move it to the next step.
class AdminOrderTile extends StatefulWidget {
  const AdminOrderTile({super.key, required this.order});

  final ShopOrder order;

  @override
  State<AdminOrderTile> createState() => _AdminOrderTileState();
}

class _AdminOrderTileState extends State<AdminOrderTile> {
  bool _busy = false;

  Future<void> _advance() async {
    setState(() => _busy = true);
    try {
      await context.read<ShopRepository>().advanceOrder(widget.order);
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t update: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final next = order.status.next;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminOrderDetail(code: order.code))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: statusColor(context, order.status).withValues(alpha: 0.2),
                      child: Text(
                        order.initials,
                        style: TextStyle(color: statusColor(context, order.status), fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.code} · ${order.customerName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text('${timeAgo(order.createdAt)} · ${rm(order.total)}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(order.deliveryMethod.icon, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  order.items.map((item) => '${item.quantity}× ${item.displayName}').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: StatusChip(order.status, label: order.statusLabel)),
                    const SizedBox(width: 8),
                    if (next != null)
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
                        onPressed: _busy ? null : _advance,
                        child: Text(next.actionLabel),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminOrderDetail extends StatefulWidget {
  const AdminOrderDetail({super.key, required this.code});

  final String code;

  @override
  State<AdminOrderDetail> createState() => _AdminOrderDetailState();
}

class _AdminOrderDetailState extends State<AdminOrderDetail> {
  late final Stream<ShopOrder?> _order = context.read<ShopRepository>().order(widget.code);
  late final Stream<List<Refund>> _refunds = context.read<ShopRepository>().refundsForOrder(widget.code);
  bool _busy = false;

  Future<void> _payout(ShopOrder order, List<Refund> refunds, [Refund? refund]) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Theme(
      data: kitchenThemeData,
      child: RefundPayoutSheet(order: order, refunds: refunds, refund: refund),
    ),
  );

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ShopOrder order) async {
    final repository = context.read<ShopRepository>();
    final picked = await showModalBottomSheet<(CancellationReason, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CancelSheet(reasons: CancellationReason.forShop, title: 'Why is the shop cancelling?'),
    );
    if (picked == null) return;
    await _run(() => repository.cancelOrder(order.code, picked.$1, note: picked.$2, byCustomer: false));
  }

  void _copy(String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage(context, '$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final storefront = context.watch<Storefront>();

    return Theme(
      data: kitchenThemeData,
      child: StreamBuilder<ShopOrder?>(
        stream: _order,
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (order == null) return Scaffold(appBar: AppBar(), body: snapshot.hasError ? ErrorView(snapshot.error) : const LoadingView());
          final next = order.status.next;

          return Scaffold(
            appBar: AppBar(title: Text(order.code)),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: staggered([
                Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSwapText(order.statusLabel, style: displayFont(context, size: 26, color: statusColor(context, order.status))),
                            Text('Placed ${shortDateTime(order.createdAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text(rm(order.total), style: displayFont(context, size: 22, color: context.tart.accent)),
                    ],
                  ),
                ),
                if (order.status.isActive) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (next != null)
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _run(() => context.read<ShopRepository>().advanceOrder(order)),
                            child: Text(next.actionLabel),
                          ),
                        ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        onPressed: _busy ? null : () => _cancel(order),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
                if (order.status == OrderStatus.cancelled && order.cancellationReason != null) ...[
                  const SizedBox(height: 12),
                  Panel(
                    title: 'Cancelled',
                    child: Text('${order.cancellationReason!.label}${order.cancellationNote == null ? '' : '\n${order.cancellationNote}'}'),
                  ),
                ],
                const SizedBox(height: 12),
                Panel(
                  title: 'Customer',
                  padding: const EdgeInsets.fromLTRB(18, 18, 6, 10),
                  child: Column(
                    children: [
                      _DetailRow(icon: Icons.person_outline, text: order.customerName),
                      if (order.email.isNotEmpty) _DetailRow(icon: Icons.alternate_email_rounded, text: order.email, onCopy: () => _copy('Email', order.email)),
                      if (order.phone.isNotEmpty) _DetailRow(icon: Icons.phone_outlined, text: order.phone, onCopy: () => _copy('Phone', order.phone)),
                      if (order.isCounterSale)
                        _DetailRow(icon: Icons.point_of_sale_rounded, text: 'Counter sale${order.servedBy == null ? '' : ' · served by ${order.servedBy}'}')
                      else
                        _DetailRow(
                          icon: order.deliveryMethod.icon,
                          text: '${storefront.label(order.deliveryMethod)}${order.address == null ? '' : '\n${order.address}'}',
                          onCopy: order.address == null ? null : () => _copy('Address', order.address!),
                        ),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        text:
                            '${order.paymentLabel}${(order.changeGiven ?? 0) > 0 ? '\nReceived ${rm(order.amountTendered!)} · change ${rm(order.changeGiven!)}' : ''}',
                      ),
                      if (order.refundedAmount > 0)
                        _DetailRow(icon: Icons.undo_rounded, text: 'Refunded ${rm(order.refundedAmount)} · net ${rm(order.netTotal)}'),
                      if (order.notes != null) _DetailRow(icon: Icons.edit_note_rounded, text: order.notes!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  title: '${order.itemCount} items',
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (refunds.isNotEmpty) ...[
                          const SectionTitle('Refunds', padding: EdgeInsets.fromLTRB(4, 18, 0, 8)),
                          for (final refund in refunds)
                            RefundTile(refund: refund, onTap: refund.status == RefundStatus.requested ? () => _payout(order, refunds, refund) : null),
                        ],
                        if (order.canBeRefunded && refundSnapshot.hasData && order.pendingRefund(refunds) == null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _payout(order, refunds),
                            icon: const Icon(Icons.undo_rounded),
                            label: Text('Issue a refund (up to ${rm(order.refundableAmount)})'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (order.status != OrderStatus.cancelled && !order.isCounterSale) ...[
                  const SizedBox(height: 12),
                  Panel(
                    title: 'Timeline',
                    child: OrderTimeline(order: order),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.onCopy});

  final IconData icon;
  final String text;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Icon(icon, size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(text, style: const TextStyle(height: 1.4)),
          ),
        ),
        if (onCopy != null) IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded, size: 18), tooltip: 'Copy'),
      ],
    );
  }
}
