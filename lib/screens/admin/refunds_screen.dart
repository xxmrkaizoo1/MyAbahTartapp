import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/refund.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/refund_widgets.dart';

/// Every refund, requests waiting for a decision first, like the website's admin/refunds.
class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  late final Stream<List<Refund>> _refunds = context.read<ShopRepository>().allRefunds();
  RefundStatus? _filter;

  Future<void> _open(Refund refund) async {
    final repository = context.read<ShopRepository>();
    final order = await repository.order(refund.orderCode).first;
    if (order == null || !mounted) return;
    final refunds = await repository.refundsForOrder(refund.orderCode).first;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: kitchenThemeData,
        child: RefundPayoutSheet(order: order, refunds: refunds, refund: refund),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refunds')),
      body: StreamBuilder<List<Refund>>(
        stream: _refunds,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(snapshot.error);
          final all = snapshot.data;
          if (all == null) return const LoadingView();

          final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
          final thisMonth = all.where((refund) => refund.status == RefundStatus.approved && !(refund.processedAt ?? refund.createdAt).isBefore(monthStart));
          final pending = all.where((refund) => refund.status == RefundStatus.requested).length;
          final shown = all.where((refund) => _filter == null || refund.status == _filter).toList()
            ..sort((a, b) => (a.status == RefundStatus.requested ? 0 : 1).compareTo(b.status == RefundStatus.requested ? 0 : 1));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: staggered([
              Row(
                children: [
                  Expanded(
                    child: Panel(
                      child: _Figure(label: 'Waiting for you', value: '$pending'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Panel(
                      child: _Figure(label: 'Refunded this month', value: rm(thisMonth.fold(0.0, (acc, refund) => acc + refund.amount))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                  for (final status in RefundStatus.values)
                    ChoiceChip(label: Text(status.label), selected: _filter == status, onSelected: (_) => setState(() => _filter = status)),
                ],
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty) const Panel(child: Text('No refunds here.')),
              for (final refund in shown) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('${refund.orderCode} · ${refund.customerName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                RefundTile(refund: refund, onTap: refund.status == RefundStatus.requested ? () => _open(refund) : null),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        child: Text(value, style: displayFont(context, size: 24, color: context.tart.accent)),
      ),
      Text(label, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );
}
