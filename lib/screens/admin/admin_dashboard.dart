import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';
import 'admin_orders.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.orders, required this.onOpenOrders});

  final List<ShopOrder> orders;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final products = context.watch<List<Product>?>() ?? const <Product>[];
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final today = orders.where((order) => !order.createdAt.isBefore(startOfDay) && order.status != OrderStatus.cancelled).toList();
    final revenue = today.fold(0.0, (acc, order) => acc + order.total);
    final active = orders.where((order) => order.status.isActive).toList();
    final lowStock = products.where((product) => product.isActive && product.isLowStock).toList()..sort((a, b) => a.stock.compareTo(b.stock));

    // Units sold today per product name.
    final sold = <String, int>{};
    for (final order in today) {
      for (final item in order.items) {
        sold[item.name] = (sold[item.name] ?? 0) + item.quantity;
      }
    }
    final topSellers = sold.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: staggered([
        if (products.isEmpty) const _ImportCatalogCard(),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // A fixed height keeps the tiles from overflowing on narrow phones.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 60 + MediaQuery.textScalerOf(context).scale(56),
          ),
          children: [
            _Metric(label: 'Sales today', value: revenue, format: rm, icon: Icons.payments_rounded, accent: context.tart.accent),
            _Metric(label: 'Orders today', value: today.length.toDouble(), icon: Icons.receipt_long_rounded, accent: Palette.ember),
            _Metric(
              label: 'In the kitchen',
              value: active.length.toDouble(),
              icon: Icons.local_fire_department_rounded,
              accent: const Color(0xFF7FD1A8),
              onTap: onOpenOrders,
            ),
            _Metric(
              label: 'Avg. order',
              value: today.isEmpty ? 0 : revenue / today.length,
              format: rm,
              icon: Icons.shopping_basket_rounded,
              accent: const Color(0xFF9DB7FF),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (final status in [OrderStatus.received, OrderStatus.preparing, OrderStatus.ready])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: status == OrderStatus.ready ? 0 : 10),
                  child: _StatusCount(status: status, count: active.where((order) => order.status == status).length, onTap: onOpenOrders),
                ),
              ),
          ],
        ),
        const SectionTitle('Waiting for you', padding: EdgeInsets.fromLTRB(4, 24, 0, 8)),
        if (active.isEmpty)
          const Panel(child: Text('No open orders. Time for a teh tarik.'))
        else
          for (final order in active.reversed.take(5)) AdminOrderTile(order: order),
        const SectionTitle('Running low', padding: EdgeInsets.fromLTRB(4, 24, 0, 8)),
        if (lowStock.isEmpty)
          const Panel(child: Text('Every tart is well stocked.'))
        else
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final product in lowStock.take(8))
                  ListTile(
                    leading: TartArt(art: product.art, imageUrl: product.imageUrl, size: 40),
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Text(
                      product.isSoldOut ? 'Sold out' : '${product.stock} left',
                      style: TextStyle(fontWeight: FontWeight.w800, color: product.isSoldOut ? Theme.of(context).colorScheme.error : context.tart.accent),
                    ),
                  ),
              ],
            ),
          ),
        if (topSellers.isNotEmpty) ...[
          const SectionTitle('Best sellers today', padding: EdgeInsets.fromLTRB(4, 24, 0, 8)),
          Panel(
            child: Column(
              children: [
                for (final (index, entry) in topSellers.take(5).indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${index + 1}', style: displayFont(context, size: 18, color: context.tart.accent)),
                        ),
                        Expanded(child: Text(entry.key)),
                        Text('${entry.value} sold', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.format, required this.icon, required this.accent, this.onTap});

  final String label;
  final double value;

  /// How to show the number; whole counts by default.
  final String Function(num value)? format;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const Spacer(),
              FittedBox(
                child: CountUpText(
                  value: value,
                  format: (current) => format?.call(current) ?? current.round().toString(),
                  style: displayFont(context, size: 26, color: accent),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({required this.status, required this.count, required this.onTap});

  final OrderStatus status;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: statusColor(context, status).withValues(alpha: 0.16),
      borderRadius: context.tart.radius(20),
      child: InkWell(
        borderRadius: context.tart.radius(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              CountUpText(
                value: count.toDouble(),
                format: (current) => current.round().toString(),
                style: displayFont(context, size: 24, color: statusColor(context, status)),
              ),
              Text(
                status.shortLabel,
                style: TextStyle(color: statusColor(context, status), fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportCatalogCard extends StatefulWidget {
  const _ImportCatalogCard();

  @override
  State<_ImportCatalogCard> createState() => _ImportCatalogCardState();
}

class _ImportCatalogCardState extends State<_ImportCatalogCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Panel(
        color: context.tart.accent.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your menu is empty', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Import the starter menu from the website: 5 collections, 14 tarts and 3 vouchers. You can edit everything afterwards.'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final created = await context.read<ShopRepository>().importStarterCatalog();
                        if (context.mounted) showMessage(context, 'Copied $created items from the website.');
                      } catch (error) {
                        if (context.mounted) showMessage(context, 'Import failed: $error');
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.download_rounded),
              label: Text(_busy ? 'Importing…' : 'Import website menu'),
            ),
          ],
        ),
      ),
    );
  }
}
