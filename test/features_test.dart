import 'package:flutter_test/flutter_test.dart';
import 'package:myabahtartlejen/models/counter_menu.dart';
import 'package:myabahtartlejen/models/enums.dart';
import 'package:myabahtartlejen/models/order.dart';
import 'package:myabahtartlejen/models/product.dart';
import 'package:myabahtartlejen/models/refund.dart';
import 'package:myabahtartlejen/theme.dart';

ShopOrder order({OrderStatus status = OrderStatus.completed, DateTime? completedAt, double refunded = 0, SalesChannel channel = SalesChannel.online}) =>
    ShopOrder(
      code: 'TL-TEST1',
      userId: 'customer-1',
      customerName: 'Aisyah',
      status: status,
      deliveryMethod: DeliveryMethod.standard,
      channel: channel,
      items: const [
        OrderItem(productId: 'egg', name: 'Egg Tart', unitPrice: 26, quantity: 2, lineTotal: 52),
        OrderItem(productId: 'lemon', name: 'Lemon Tart', unitPrice: 13.5, quantity: 1, lineTotal: 13.5),
      ],
      total: 70.5,
      refundedAmount: refunded,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      completedAt: completedAt ?? DateTime.now().subtract(const Duration(days: 1)),
    );

Refund refund(RefundStatus status, int index, int quantity) => Refund(
  id: 'r$index$quantity',
  orderCode: 'TL-TEST1',
  userId: 'customer-1',
  customerName: 'Aisyah',
  status: status,
  reason: RefundReason.damaged,
  items: [RefundItem(index: index, name: 'x', quantity: quantity, unitPrice: 26)],
  createdAt: DateTime.now(),
);

void main() {
  group('refunds follow the website rules', () {
    test('a fresh completed online order can be refunded', () {
      expect(order().canRequestRefund(const []), isTrue);
      expect(order().refundableQuantities(const []), {0: 2, 1: 1});
    });

    test('not after the 7-day window, not for counter sales, not while one is pending', () {
      expect(order(completedAt: DateTime.now().subtract(const Duration(days: 8))).canRequestRefund(const []), isFalse);
      expect(order(channel: SalesChannel.counter).canRequestRefund(const []), isFalse);
      expect(order().canRequestRefund([refund(RefundStatus.requested, 0, 1)]), isFalse);
      expect(order(status: OrderStatus.preparing).canRequestRefund(const []), isFalse);
    });

    test('claimed items are taken off, declined ones are not', () {
      final refunds = [refund(RefundStatus.approved, 0, 1), refund(RefundStatus.rejected, 1, 1)];
      expect(order(refunded: 26).refundableQuantities(refunds), {0: 1, 1: 1});
      expect(order(refunded: 26).refundableAmount, 44.5);
      expect(order(refunded: 70.5).canBeRefunded, isFalse);
    });
  });

  group('counter allowances', () {
    const sized = Product(id: 'p', name: 'Egg Tart', categoryId: 'c', price: 10, sizePrices: {'S': 10, 'L': 25}, sizeStock: {'S': 8, 'L': 4}, stock: 12);

    test('no counter menu means real stock is the limit', () {
      final sales = CounterSales(const []);
      expect(sales.sellable(sized, null, const CounterMenu(date: 'd')), 12);
      expect(sales.sellable(sized, ProductSize.large, const CounterMenu(date: 'd')), 4);
    });

    test('what was brought out, minus what sold, never above stock', () {
      const menu = CounterMenu(
        date: 'd',
        items: {
          'p': CounterAllowance(quantity: 6, sizes: {'S': 5, 'L': 1}),
        },
      );
      final sales = CounterSales([(productId: 'p', size: ProductSize.small, quantity: 3)]);
      expect(sales.sellable(sized, null, menu), 3);
      expect(sales.sellable(sized, ProductSize.small, menu), 2);
      expect(sales.sellable(sized, ProductSize.large, menu), 1);
    });
  });

  test('order ready estimate matches the website formula', () {
    final placed = DateTime(2026, 10, 31, 10);
    final active = ShopOrder(
      code: 'TL-X',
      userId: 'u',
      customerName: 'A',
      status: OrderStatus.received,
      deliveryMethod: DeliveryMethod.pickup,
      createdAt: placed,
      items: const [OrderItem(productId: 'p', name: 'P', unitPrice: 1, quantity: 3, lineTotal: 3)],
    );
    expect(active.estimatedReadyAt(ordersAhead: 2), placed.add(const Duration(minutes: 20 + 10 + 6)));
  });

  test('every website theme is available and sharp themes square off pills', () {
    expect(TartTheme.all.map((theme) => theme.id), containsAll(['matcha', 'raspberry', 'blueberry', 'caramel', 'lavender', 'midnight', 'mono', 'aurora']));
    expect(TartTheme.byId('mono').radius(99).topLeft.x, 10);
    expect(TartTheme.byId('lavender').radius(20).topLeft.x, 25);
    expect(TartTheme.byId('nope').id, 'matcha');
  });
}
