import 'dart:math';

import '../models/enums.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/shop_models.dart';

/// Made-up customers and sales for trying out the Customers page and the sales report.
/// Everything is marked `sample: true` so it can be removed again; codes and ids are fixed,
/// so adding the samples twice replaces them instead of doubling them.
class SampleData {
  SampleData({required this.customers, required this.orders});

  /// users/{id} documents.
  final Map<String, Json> customers;

  /// orders/{code} documents, without timestamps converted (the repository does that).
  final Map<String, Json> orders;

  static const customerCount = 20;
  static const onlineSales = 20;
  static const counterSales = 4;

  static const _names = [
    'Nurul Aisyah binti Rahman',
    'Muhammad Haziq bin Azlan',
    'Siti Nur Farhana',
    'Lim Wei Jie',
    'Kavitha a/p Raman',
    'Ahmad Faiz bin Osman',
    'Tan Mei Ling',
    'Nur Izzati binti Hassan',
    'Arjun Nair',
    'Farah Hanim binti Yusof',
    'Wong Kar Wai',
    'Aiman Hakimi bin Zulkifli',
    'Chong Li Ying',
    'Syahirah binti Kamal',
    'Daniel Lee',
    'Puteri Balqis binti Ismail',
    'Ravi Shankar',
    'Amirul Hafiz bin Rosli',
    'Ng Jia Hui',
    'Zulaikha binti Ahmad',
  ];

  static const _areas = [
    'Jalan Telawi 2, Bangsar Baru, 59100 Kuala Lumpur',
    'Jalan SS2/24, 47300 Petaling Jaya',
    'Jalan Setia Bakti, Bukit Damansara, 50490 Kuala Lumpur',
    'Persiaran Wangsa Baiduri, 47500 Subang Jaya',
    'Jalan Tun Razak, 50400 Kuala Lumpur',
    'Jalan PJU 7/2, Mutiara Damansara, 47800 Petaling Jaya',
    'Jalan Kuchai Maju 1, 58200 Kuala Lumpur',
    'Jalan Ampang, 50450 Kuala Lumpur',
    'Jalan Setiawangsa 9, 54200 Kuala Lumpur',
    'Persiaran Raja Muda Musa, 41100 Klang',
  ];

  static const _notes = [null, null, null, 'Please call when you arrive.', 'Leave at the guardhouse.', null, 'For a family gathering, thank you!'];

  /// Builds the samples from the live menu, so items, prices and photos are real.
  factory SampleData.build({required List<Product> menu, required Storefront storefront, required DateTime now}) {
    final random = Random(2026);
    final products = menu.where((product) => product.isActive).toList();
    if (products.isEmpty) throw StateError('The menu is empty. Import the website menu first.');

    final customers = <String, Json>{};
    for (var i = 0; i < customerCount; i++) {
      final name = _names[i];
      final handle = name.toLowerCase().split(RegExp(r'\s+')).take(2).join('.').replaceAll(RegExp(r'[^a-z.]'), '');
      customers['sample-${(i + 1).toString().padLeft(2, '0')}'] = {
        'name': name,
        'email': '$handle@example.com',
        'phone': '01${random.nextInt(9) + 1}-${100 + random.nextInt(900)} ${1000 + random.nextInt(9000)}',
        'address': '${random.nextInt(80) + 1}, ${_areas[i % _areas.length]}',
        'role': 'customer',
        'sample': true,
        'createdAt': now.subtract(Duration(days: 30 + random.nextInt(60))),
      };
    }

    List<OrderItem> pickItems() {
      final picked = (products.toList()..shuffle(random)).take(1 + random.nextInt(min(3, products.length)));
      return [
        for (final product in picked)
          () {
            final size = product.hasSizes ? product.sizes[random.nextInt(product.sizes.length)] : null;
            final quantity = 1 + random.nextInt(3);
            final price = product.priceFor(size);
            return OrderItem(
              productId: product.id,
              name: product.name,
              size: size,
              unitPrice: price,
              quantity: quantity,
              lineTotal: round2(price * quantity),
              art: product.art,
              imageUrl: product.imageFor(size),
            );
          }(),
      ];
    }

    final orders = <String, Json>{};
    final ids = customers.keys.toList();
    final total = onlineSales + counterSales;
    for (var i = 0; i < total; i++) {
      final code = 'TL-SMP${(i + 1).toString().padLeft(2, '0')}';
      final counter = i >= onlineSales;
      // Spread over the last 30 days, during opening hours; the newest few are still in the kitchen.
      final day = now.subtract(Duration(days: (total - 1 - i) * 30 ~/ total));
      var placed = DateTime(day.year, day.month, day.day, 10 + random.nextInt(10), random.nextInt(60));
      if (placed.isAfter(now)) placed = now.subtract(Duration(minutes: 20 + random.nextInt(60)));
      final status = counter
          ? OrderStatus.completed
          : switch (i) {
              19 => OrderStatus.received,
              18 => OrderStatus.preparing,
              7 => OrderStatus.cancelled,
              _ => OrderStatus.completed,
            };
      final items = pickItems();
      final subtotal = round2(items.fold(0.0, (acc, item) => acc + item.lineTotal));
      final methods = storefront.enabledMethods;
      final method = counter ? DeliveryMethod.pickup : methods[random.nextInt(methods.length)];
      final fee = counter ? 0.0 : storefront.feeFor(method, subtotal);
      final orderTotal = round2(subtotal + fee);
      final customer = counter ? null : customers[ids[i % ids.length]]!;
      final payment = counter ? [PaymentMethod.cash, PaymentMethod.eWallet, PaymentMethod.card][i % 3] : PaymentMethod.cash;

      orders[code] = {
        'userId': counter ? '' : ids[i % ids.length],
        'customerName': customer?['name'] ?? 'Walk-in customer',
        'email': customer?['email'] ?? '',
        'status': status.name,
        'channel': (counter ? SalesChannel.counter : SalesChannel.online).name,
        'deliveryMethod': method.name,
        'phone': customer?['phone'] ?? '',
        'address': method.requiresAddress ? customer!['address'] : null,
        'notes': counter ? null : _notes[random.nextInt(_notes.length)],
        'items': items.map((item) => item.toMap()).toList(),
        'productIds': items.map((item) => item.productId).toSet().toList(),
        'subtotal': subtotal,
        'deliveryFee': fee,
        'discount': 0.0,
        'total': orderTotal,
        'voucherCode': null,
        'paymentMethod': payment.code,
        'paymentStatus': status == OrderStatus.completed ? 'paid' : 'unpaid',
        'amountTendered': counter && payment == PaymentMethod.cash ? (orderTotal / 10).ceil() * 10.0 : null,
        'servedBy': counter ? 'Staff' : null,
        'createdAt': placed,
        'preparingAt': status.index >= OrderStatus.preparing.index && status != OrderStatus.cancelled ? placed.add(const Duration(minutes: 5)) : null,
        'readyAt': status.index >= OrderStatus.ready.index && status != OrderStatus.cancelled ? placed.add(const Duration(minutes: 30)) : null,
        'completedAt': status == OrderStatus.completed ? placed.add(Duration(minutes: counter ? 1 : 90)) : null,
        'cancelledAt': status == OrderStatus.cancelled ? placed.add(const Duration(minutes: 10)) : null,
        'cancellationReason': status == OrderStatus.cancelled ? CancellationReason.changedMind.code : null,
        'sample': true,
      };
    }

    return SampleData(customers: customers, orders: orders);
  }
}
