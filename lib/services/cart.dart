import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/product.dart';
import '../models/shop_models.dart';

class CartLine {
  CartLine({required this.product, this.size, required this.quantity});

  final Product product;
  final ProductSize? size;
  int quantity;

  String get key => '${product.id}|${size?.code ?? ''}';

  double get unitPrice => product.priceFor(size);

  double get lineTotal => round2(unitPrice * quantity);

  int get maxQuantity => product.stockFor(size);
}

class CartSummary {
  const CartSummary({required this.subtotal, required this.deliveryFee, required this.discount, required this.total});

  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
}

/// The customer's cart, kept in memory while the app is open.
class Cart extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};
  Voucher? _voucher;

  List<CartLine> get lines => _lines.values.toList();

  bool get isEmpty => _lines.isEmpty;

  int get count => _lines.values.fold<int>(0, (acc, line) => acc + line.quantity);

  double get subtotal => round2(_lines.values.fold(0.0, (acc, line) => acc + line.lineTotal));

  Voucher? get voucher => _voucher;

  double get discount => _voucher?.discountFor(subtotal) ?? 0;

  int quantityOf(Product product, ProductSize? size) => _lines['${product.id}|${size?.code ?? ''}']?.quantity ?? 0;

  /// Adds up to [quantity] units, never more than are in stock. Returns how many were added.
  int add(Product product, ProductSize? size, int quantity) {
    final line = CartLine(product: product, size: size, quantity: 0);
    final existing = _lines[line.key];
    final current = existing?.quantity ?? 0;
    final added = max(0, min(quantity, product.stockFor(size) - current));
    if (added == 0) return 0;

    _lines[line.key] = CartLine(product: product, size: size, quantity: current + added);
    notifyListeners();
    return added;
  }

  void setQuantity(CartLine line, int quantity) {
    if (quantity <= 0) {
      _lines.remove(line.key);
    } else {
      _lines[line.key]?.quantity = min(quantity, max(1, line.maxQuantity));
    }
    notifyListeners();
  }

  void remove(CartLine line) {
    _lines.remove(line.key);
    notifyListeners();
  }

  void applyVoucher(Voucher voucher) {
    _voucher = voucher;
    notifyListeners();
  }

  void removeVoucher() {
    _voucher = null;
    notifyListeners();
  }

  CartSummary summary(Storefront storefront, DeliveryMethod method) {
    final fee = storefront.feeFor(method, subtotal);
    return CartSummary(subtotal: subtotal, deliveryFee: fee, discount: discount, total: round2(max(0, subtotal + fee - discount)));
  }

  void clear() {
    _lines.clear();
    _voucher = null;
    notifyListeners();
  }
}
