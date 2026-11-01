import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'product.dart';

/// How many of a product were brought out to the counter. Null means no limit beyond stock.
class CounterAllowance {
  const CounterAllowance({this.quantity, this.sizes = const {}});

  final int? quantity;

  /// Units per size code; a missing or null size has no limit.
  final Map<String, int?> sizes;

  factory CounterAllowance.fromMap(Map? data) => CounterAllowance(
    quantity: data?['quantity'] == null ? null : readInt(data!['quantity']),
    sizes: {
      if (data?['sizes'] is Map)
        for (final entry in (data!['sizes'] as Map).entries) '${entry.key}': entry.value == null ? null : readInt(entry.value),
    },
  );

  Json toMap() => {'quantity': quantity, 'sizes': sizes.isEmpty ? null : sizes};
}

/// The products put out for sale at the counter on one day, like the website's CounterItem.
class CounterMenu {
  const CounterMenu({required this.date, this.items = const {}});

  /// The day as yyyy-mm-dd, which is also the document id.
  final String date;

  /// Allowances keyed by product id.
  final Map<String, CounterAllowance> items;

  static String keyFor(DateTime day) => '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  factory CounterMenu.fromDoc(DocumentSnapshot<Json> doc) {
    final items = doc.data()?['items'];
    return CounterMenu(
      date: doc.id,
      items: {
        if (items is Map)
          for (final entry in items.entries) '${entry.key}': CounterAllowance.fromMap(entry.value as Map?),
      },
    );
  }

  Json toMap() => {
    'items': {for (final entry in items.entries) entry.key: entry.value.toMap()},
    'updatedAt': FieldValue.serverTimestamp(),
  };

  bool get isEmpty => items.isEmpty;
}

/// Units sold at the counter today, keyed by product id and by "productId|size".
class CounterSales {
  CounterSales(Iterable<({String productId, ProductSize? size, int quantity})> lines) {
    for (final line in lines) {
      byProduct[line.productId] = (byProduct[line.productId] ?? 0) + line.quantity;
      if (line.size != null) {
        final key = '${line.productId}|${line.size!.code}';
        bySize[key] = (bySize[key] ?? 0) + line.quantity;
      }
    }
  }

  final byProduct = <String, int>{};
  final bySize = <String, int>{};

  /// What the counter can still sell: what is left of the amount brought out, never more than real stock.
  int sellable(Product product, ProductSize? size, CounterMenu menu) {
    final allowance = menu.items[product.id];
    final brought = allowance?.quantity;
    final productLeft = brought == null ? product.stock : (brought - (byProduct[product.id] ?? 0)).clamp(0, product.stock);
    if (size == null) return productLeft < 0 ? 0 : productLeft;

    final available = product.stockFor(size) < productLeft ? product.stockFor(size) : productLeft;
    final sizeBrought = allowance?.sizes[size.code];
    if (sizeBrought == null) return available < 0 ? 0 : available;
    final sizeLeft = sizeBrought - (bySize['${product.id}|${size.code}'] ?? 0);
    final result = sizeLeft < available ? sizeLeft : available;
    return result < 0 ? 0 : result;
  }
}
