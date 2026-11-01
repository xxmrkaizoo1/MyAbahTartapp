import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/order.dart';
import '../models/refund.dart';
import '../services/auth_service.dart';
import '../services/format.dart';
import '../services/shop_repository.dart';
import '../theme.dart';
import 'common.dart';

/// One refund with its status, items and any note from staff.
class RefundTile extends StatelessWidget {
  const RefundTile({super.key, required this.refund, this.onTap});

  final Refund refund;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RefundBadge(status: refund.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(refund.reason.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (refund.status == RefundStatus.approved) Text(rm(refund.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                if (refund.items.isNotEmpty)
                  Text(refund.items.map((item) => '${item.quantity}× ${item.displayName}').join(', '), style: TextStyle(color: muted, fontSize: 13)),
                if (refund.details != null)
                  Text(
                    '“${refund.details}”',
                    style: TextStyle(color: muted, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                if (refund.adminNote != null) ...[const SizedBox(height: 4), Text('Shop: ${refund.adminNote}', style: const TextStyle(fontSize: 13))],
                const SizedBox(height: 4),
                Text(
                  ['Asked ${shortDateTime(refund.createdAt)}', if (refund.method != null) refund.method!.label, if (refund.restocked) 'restocked'].join(' · '),
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RefundBadge extends StatelessWidget {
  const _RefundBadge({required this.status});

  final RefundStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: status.color.withValues(alpha: 0.15), borderRadius: context.tart.radius(99)),
    child: Text(
      status.label,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: status.color),
    ),
  );
}

/// Quantity pickers for the items of an order that can still be refunded.
class RefundItemsPicker extends StatelessWidget {
  const RefundItemsPicker({super.key, required this.order, required this.refundable, required this.quantities, required this.onChanged});

  final ShopOrder order;
  final Map<int, int> refundable;
  final Map<int, int> quantities;
  final void Function(int index, int quantity) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, item) in order.items.indexed)
          if ((refundable[index] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${rm(item.unitPrice)} each · up to ${refundable[index]}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  QuantityStepper(compact: true, value: quantities[index] ?? 0, min: 0, max: refundable[index]!, onChanged: (value) => onChanged(index, value)),
                ],
              ),
            ),
      ],
    );
  }
}

double _valueOf(ShopOrder order, Map<int, int> quantities) =>
    quantities.entries.fold(0.0, (acc, entry) => acc + order.items[entry.key].unitPrice * entry.value);

/// A customer picks the items to refund and says what went wrong.
class RequestRefundSheet extends StatefulWidget {
  const RequestRefundSheet({super.key, required this.order, required this.refunds});

  final ShopOrder order;
  final List<Refund> refunds;

  @override
  State<RequestRefundSheet> createState() => _RequestRefundSheetState();
}

class _RequestRefundSheetState extends State<RequestRefundSheet> {
  final _quantities = <int, int>{};
  final _details = TextEditingController();
  RefundReason? _reason;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return showMessage(context, 'Tell us what went wrong.');
    if (_reason == RefundReason.other && _details.text.trim().isEmpty) return showMessage(context, 'Please tell us what went wrong.');
    setState(() => _sending = true);
    try {
      await context.read<ShopRepository>().requestRefund(
        order: widget.order,
        existing: widget.refunds,
        reason: _reason!,
        details: _details.text,
        quantities: _quantities,
      );
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Refund request sent. We’ll review it within one working day.');
      }
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refundable = widget.order.refundableQuantities(widget.refunds);
    final value = _valueOf(widget.order, _quantities);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request a refund', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Pick the items that had a problem. You can ask within ${ShopOrder.refundWindowDays} days of receiving your order.',
              style: TextStyle(color: context.tart.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            RefundItemsPicker(
              order: widget.order,
              refundable: refundable,
              quantities: _quantities,
              onChanged: (index, quantity) => setState(() => _quantities[index] = quantity),
            ),
            const SizedBox(height: 8),
            RadioGroup<RefundReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in RefundReason.values)
                    RadioListTile<RefundReason>(contentPadding: EdgeInsets.zero, dense: true, value: reason, title: Text(reason.label)),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Anything else we should know? Photos can be sent on WhatsApp.'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending || value <= 0 ? null : _send,
                child: Text(
                  _sending
                      ? 'Sending…'
                      : value <= 0
                      ? 'Pick at least one item'
                      : 'Ask for ${rm(value)} back',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Staff choose how much to pay back, how, and whether the items go back on the shelf.
/// With [refund] they approve or decline a customer's request; without it they issue a new refund.
class RefundPayoutSheet extends StatefulWidget {
  const RefundPayoutSheet({super.key, required this.order, required this.refunds, this.refund});

  final ShopOrder order;
  final List<Refund> refunds;
  final Refund? refund;

  @override
  State<RefundPayoutSheet> createState() => _RefundPayoutSheetState();
}

class _RefundPayoutSheetState extends State<RefundPayoutSheet> {
  final _quantities = <int, int>{};
  late final _amount = TextEditingController(
    text: widget.refund == null ? '' : widget.refund!.itemsValue.clamp(0, widget.order.refundableAmount).toStringAsFixed(2),
  );
  final _note = TextEditingController();
  RefundReason _reason = RefundReason.other;
  RefundMethod _method = RefundMethod.bankTransfer;
  bool _restock = false;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(ShopRepository repository, String staff) action, String done) async {
    final repository = context.read<ShopRepository>();
    final staff = context.read<AuthService>().profile?.name ?? 'Staff';
    setState(() => _busy = true);
    try {
      await action(repository, staff);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, done);
      }
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _approve() {
    final amount = double.tryParse(_amount.text) ?? 0;
    final existing = widget.refund;
    _run(
      (repository, staff) => existing == null
          ? repository.issueRefund(
              order: widget.order,
              reason: _reason,
              quantities: _quantities,
              amount: amount,
              method: _method,
              restock: _restock,
              note: _note.text,
              staffName: staff,
            )
          : repository.approveRefund(existing, amount: amount, method: _method, restock: _restock, note: _note.text, staffName: staff),
      'Refunded ${rm(amount)} on order ${widget.order.code}.',
    );
  }

  void _decline() {
    if (_note.text.trim().isEmpty) return showMessage(context, 'Tell the customer why the refund was declined.');
    _run((repository, staff) => repository.rejectRefund(widget.refund!, note: _note.text, staffName: staff), 'Refund for order ${widget.order.code} declined.');
  }

  @override
  Widget build(BuildContext context) {
    final refund = widget.refund;
    final refundable = widget.order.refundableQuantities(widget.refunds);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(refund == null ? 'Refund ${widget.order.code}' : 'Refund request · ${widget.order.code}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Up to ${rm(widget.order.refundableAmount)} can still be refunded.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (refund != null)
              RefundTile(refund: refund)
            else ...[
              DropdownButtonFormField<RefundReason>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: [for (final reason in RefundReason.values) DropdownMenuItem(value: reason, child: Text(reason.label))],
                onChanged: (value) => setState(() => _reason = value ?? _reason),
              ),
              const SizedBox(height: 8),
              RefundItemsPicker(
                order: widget.order,
                refundable: refundable,
                quantities: _quantities,
                onChanged: (index, quantity) => setState(() {
                  _quantities[index] = quantity;
                  _amount.text = _valueOf(widget.order, _quantities).clamp(0, widget.order.refundableAmount).toStringAsFixed(2);
                }),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount to pay back (RM)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RefundMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Paid back by'),
              items: [for (final method in RefundMethod.values) DropdownMenuItem(value: method, child: Text(method.label))],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Put the items back in stock'),
              subtitle: const Text('Only if they can be sold again'),
              value: _restock,
              onChanged: (value) => setState(() => _restock = value),
            ),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: refund == null ? 'Note (optional)' : 'Note to the customer'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (refund != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: _busy ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(onPressed: _busy ? null : _approve, child: Text(_busy ? 'Saving…' : 'Refund')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
