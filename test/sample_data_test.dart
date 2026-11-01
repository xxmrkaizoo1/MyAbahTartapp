import 'package:flutter_test/flutter_test.dart';
import 'package:myabahtartlejen/models/product.dart';
import 'package:myabahtartlejen/models/shop_models.dart';
import 'package:myabahtartlejen/services/sample_data.dart';
import 'package:myabahtartlejen/services/seed_data.dart';

void main() {
  final menu = [for (final MapEntry(key: id, value: data) in seedProducts.entries) Product.fromMap(id, data)];
  final now = DateTime(2026, 10, 31, 15);
  SampleData build() => SampleData.build(menu: menu, storefront: Storefront.fallback, now: now);

  test('makes 20 customers with unique emails and 24 sales from the real menu', () {
    final sample = build();
    expect(sample.customers, hasLength(20));
    expect(sample.customers.values.map((customer) => customer['email']).toSet(), hasLength(20));
    expect(sample.orders, hasLength(24));

    for (final order in sample.orders.values) {
      final items = order['items'] as List;
      expect(items, isNotEmpty);
      for (final item in items.cast<Map>()) {
        expect(menu.map((product) => product.id), contains(item['productId']));
      }
      final subtotal = items.cast<Map>().fold(0.0, (acc, item) => acc + (item['lineTotal'] as double));
      expect(order['subtotal'], closeTo(subtotal, 0.001));
      expect(order['total'], closeTo((order['subtotal'] as double) + (order['deliveryFee'] as double), 0.001));
      expect((order['createdAt'] as DateTime).isAfter(now), isFalse);
      expect(order['sample'], isTrue);
    }
  });

  test('counter sales are walk-ins and online sales belong to a sample customer', () {
    final sample = build();
    final counter = sample.orders.values.where((order) => order['channel'] == 'counter');
    expect(counter, hasLength(4));
    expect(counter.every((order) => order['userId'] == '' && order['paymentStatus'] == 'paid'), isTrue);
    for (final order in sample.orders.values.where((order) => order['channel'] == 'online')) {
      expect(sample.customers[order['userId']]?['email'], order['email']);
    }
  });

  test('is the same every time, so adding twice replaces instead of doubling', () {
    final first = build(), second = build();
    expect(second.orders.keys, first.orders.keys);
    expect(second.orders['TL-SMP05']!['total'], first.orders['TL-SMP05']!['total']);
  });
}
