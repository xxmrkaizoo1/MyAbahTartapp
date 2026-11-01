import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../models/order.dart';
import '../services/format.dart';
import 'tart_art.dart';

/// The vertical Received → Preparing → Ready → Completed progress line.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = order.status == OrderStatus.cancelled ? -1 : OrderStatus.timeline.indexOf(order.status);

    return Column(
      children: [
        for (final (index, status) in OrderStatus.timeline.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= reached ? status.color : Colors.transparent,
                          border: Border.all(color: index <= reached ? status.color : scheme.outline, width: 2),
                        ),
                        child: index < reached
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : index == reached
                            ? const Icon(Icons.circle, size: 8, color: Colors.white)
                            : null,
                      ),
                      if (index < OrderStatus.timeline.length - 1)
                        Expanded(
                          child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: index < reached ? status.color : scheme.outline),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status == OrderStatus.ready ? order.deliveryMethod.readyLabel : status.label,
                          style: TextStyle(fontWeight: FontWeight.w800, color: index <= reached ? scheme.onSurface : scheme.onSurfaceVariant),
                        ),
                        if (order.timestampFor(status) != null && index <= reached)
                          Text(shortDateTime(order.timestampFor(status)!), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class OrderItemsList extends StatelessWidget {
  const OrderItemsList({super.key, required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                TartArt(art: item.art, imageUrl: item.imageUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${item.quantity} × ${rm(item.unitPrice)}', style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
                Text(rm(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

class TotalsTable extends StatelessWidget {
  const TotalsTable({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    this.voucherCode,
    this.deliveryLabel = 'Delivery',
  });

  final double subtotal;
  final double? deliveryFee;
  final double discount;
  final double total;
  final String? voucherCode;
  final String deliveryLabel;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget row(String label, String value, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: bold ? null : muted, fontWeight: bold ? FontWeight.w800 : null, fontSize: bold ? 17 : 14.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 19 : 14.5, color: color),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row('Subtotal', rm(subtotal)),
        if (discount > 0) row(voucherCode == null ? 'Discount' : 'Voucher $voucherCode', '− ${rm(discount)}', color: const Color(0xFF2E9D6A)),
        row(
          deliveryLabel,
          deliveryFee == null
              ? 'At checkout'
              : deliveryFee == 0
              ? 'Free'
              : rm(deliveryFee!),
        ),
        const Divider(height: 20),
        row('Total', rm(total), bold: true),
      ],
    );
  }
}

/// A row of small overlapping tart pictures for an order's items.
class TartStack extends StatelessWidget {
  const TartStack({super.key, required this.arts, this.size = 40});

  final List<String> arts;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = arts.take(3).toList();
    return SizedBox(
      width: size + (shown.length - 1) * size * 0.55,
      height: size,
      child: Stack(
        children: [
          for (final (index, art) in shown.indexed)
            Positioned(
              left: index * size * 0.55,
              child: TartArt(art: art, size: size),
            ),
        ],
      ),
    );
  }
}
