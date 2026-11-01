import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/counter_menu.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/refund.dart';
import '../models/shop_models.dart';
import 'cart.dart';
import 'sample_data.dart';
import 'seed_data.dart';

/// A problem the customer or staff member can fix, shown to them as-is.
class ShopException implements Exception {
  const ShopException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// All Firestore reads and writes for the shop.
class ShopRepository {
  ShopRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _random = Random.secure();

  CollectionReference<Json> get _products => _db.collection('products');
  CollectionReference<Json> get _categories => _db.collection('categories');
  CollectionReference<Json> get _orders => _db.collection('orders');
  CollectionReference<Json> get _vouchers => _db.collection('vouchers');
  CollectionReference<Json> get _users => _db.collection('users');
  DocumentReference<Json> get _storefront => _db.collection('settings').doc('storefront');

  // ---------------------------------------------------------------- Catalog

  Stream<List<MenuCategory>> categories() =>
      _categories.snapshots().map((snapshot) => snapshot.docs.map(MenuCategory.fromDoc).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  /// Every product, including hidden ones. The shop screens filter on [Product.isActive].
  Stream<List<Product>> products() =>
      _products.snapshots().map((snapshot) => snapshot.docs.map(Product.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));

  Stream<Product?> product(String id) => _products.doc(id).snapshots().map((doc) => doc.exists ? Product.fromDoc(doc) : null);

  Future<Product?> productOnce(String id) async {
    final doc = await _products.doc(id).get();
    return doc.exists ? Product.fromDoc(doc) : null;
  }

  Stream<Storefront> storefront() => _storefront.snapshots().map((doc) => Storefront.fromMap(doc.data()));

  Future<Voucher?> voucher(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final doc = await _vouchers.doc(normalized).get();
    return doc.exists ? Voucher.fromDoc(doc) : null;
  }

  // ---------------------------------------------------------------- Reviews

  Stream<List<Review>> reviews(String productId) => _products
      .doc(productId)
      .collection('reviews')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Review.fromDoc).toList()..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())));

  Future<void> saveReview({required String productId, required AppUser user, required int rating, required String comment}) => _products
      .doc(productId)
      .collection('reviews')
      .doc(user.uid)
      .set({'userName': user.name, 'rating': rating, 'comment': comment, 'createdAt': FieldValue.serverTimestamp()});

  Future<void> deleteReview(String productId, String userId) => _products.doc(productId).collection('reviews').doc(userId).delete();

  // ---------------------------------------------------------------- Users

  /// Everyone with a profile: app accounts and customers copied from the website. Staff only.
  Stream<List<AppUser>> customers() => _users.snapshots().map((snapshot) => snapshot.docs.map(AppUser.fromDoc).where((user) => !user.isAdmin).toList());

  /// Moves orders and refunds copied from the website onto this customer's app account,
  /// matched by their verified email. Returns how many were moved.
  Future<int> claimWebsiteHistory(String uid, String email) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return 0;
    var moved = 0;
    for (final collection in [_orders, _refunds]) {
      final found = await collection.where('fromWebsite', isEqualTo: true).where('email', isEqualTo: key).get();
      for (final doc in found.docs.where((doc) => doc.data()['userId'] != uid)) {
        await doc.reference.update({'userId': uid});
        moved++;
      }
    }
    return moved;
  }

  Stream<AppUser?> userProfile(String uid) => _users.doc(uid).snapshots().map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  /// Never writes `role`: only the Firebase console can make someone an admin.
  Future<void> saveProfile(String uid, {required String name, required String email, String? phone, String? address}) =>
      _users.doc(uid).set({'name': name, 'email': email, 'phone': ?phone, 'address': ?address}, SetOptions(merge: true));

  // ---------------------------------------------------------------- Orders

  Stream<List<ShopOrder>> myOrders(String uid) => _orders
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ShopOrder.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Stream<ShopOrder?> order(String code) => _orders.doc(code).snapshots().map((doc) => doc.exists ? ShopOrder.fromDoc(doc) : null);

  /// The most recent orders, for the kitchen screens.
  Stream<List<ShopOrder>> recentOrders({int limit = 300}) =>
      _orders.orderBy('createdAt', descending: true).limit(limit).snapshots().map((snapshot) => snapshot.docs.map(ShopOrder.fromDoc).toList());

  String _newCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'TL-${List.generate(5, (_) => alphabet[_random.nextInt(alphabet.length)]).join()}';
  }

  /// Checks stock, takes it off the shelf and creates the order in one transaction, using the latest prices.
  Future<String> placeOrder({
    required AppUser customer,
    required List<CartLine> lines,
    required DeliveryMethod method,
    required Storefront storefront,
    Voucher? voucher,
    required String phone,
    String? address,
    String? notes,
  }) {
    if (lines.isEmpty) throw const ShopException('Your cart is empty.');

    return _db.runTransaction((tx) async {
      final fresh = <String, Product>{};
      for (final id in lines.map((line) => line.product.id).toSet()) {
        final snapshot = await tx.get(_products.doc(id));
        if (!snapshot.exists) throw const ShopException('One of the items in your cart is no longer on the menu.');
        fresh[id] = Product.fromDoc(snapshot);
      }

      // Units wanted per product, keyed by size code ('' for products without sizes).
      final demand = <String, Map<String, int>>{};
      for (final line in lines) {
        final sizes = demand.putIfAbsent(line.product.id, () => {});
        sizes[line.size?.code ?? ''] = (sizes[line.size?.code ?? ''] ?? 0) + line.quantity;
      }

      for (final MapEntry(key: id, value: sizes) in demand.entries) {
        final product = fresh[id]!;
        if (!product.isActive) throw ShopException('${product.name} is no longer available.');
        for (final MapEntry(key: code, value: quantity) in sizes.entries) {
          final size = ProductSize.fromCode(code);
          final available = product.stockFor(size);
          if (available < quantity) {
            final name = size == null ? product.name : '${product.name} (${size.label})';
            throw ShopException('Sorry, only $available of $name left. Please update your cart.');
          }
        }
      }

      late DocumentReference<Json> orderRef;
      String code;
      do {
        code = _newCode();
        orderRef = _orders.doc(code);
      } while ((await tx.get(orderRef)).exists);

      for (final MapEntry(key: id, value: sizes) in demand.entries) {
        tx.update(_products.doc(id), _stockChange(fresh[id]!, sizes, -1));
      }

      final items = [
        for (final line in lines)
          OrderItem(
            productId: line.product.id,
            name: fresh[line.product.id]!.name,
            size: line.size,
            unitPrice: fresh[line.product.id]!.priceFor(line.size),
            quantity: line.quantity,
            lineTotal: round2(fresh[line.product.id]!.priceFor(line.size) * line.quantity),
            art: fresh[line.product.id]!.art,
            imageUrl: fresh[line.product.id]!.imageFor(line.size),
          ),
      ];
      final subtotal = round2(items.fold(0.0, (acc, item) => acc + item.lineTotal));
      final fee = storefront.feeFor(method, subtotal);
      final discount = voucher?.discountFor(subtotal) ?? 0;

      tx.set(orderRef, {
        'userId': customer.uid,
        'customerName': customer.name,
        'email': customer.email,
        'status': OrderStatus.received.name,
        'deliveryMethod': method.name,
        'phone': phone,
        'address': method.requiresAddress ? address : null,
        'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
        'items': items.map((item) => item.toMap()).toList(),
        'productIds': demand.keys.toList(),
        'subtotal': subtotal,
        'deliveryFee': fee,
        'discount': discount,
        'total': round2(max(0, subtotal + fee - discount)),
        'voucherCode': discount > 0 ? voucher!.code : null,
        'channel': SalesChannel.online.name,
        'paymentMethod': PaymentMethod.cash.code,
        'paymentStatus': 'unpaid',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return code;
    });
  }

  Future<DocumentReference<Json>> _freeOrderRef(Transaction tx) async {
    while (true) {
      final ref = _orders.doc(_newCode());
      if (!(await tx.get(ref)).exists) return ref;
    }
  }

  // ---------------------------------------------------------------- Counter (POS)

  CollectionReference<Json> get _counterMenus => _db.collection('counterMenus');

  Stream<CounterMenu> counterMenu(DateTime day) {
    final key = CounterMenu.keyFor(day);
    return _counterMenus.doc(key).snapshots().map((doc) => doc.exists ? CounterMenu.fromDoc(doc) : CounterMenu(date: key));
  }

  Future<CounterMenu> counterMenuOnce(DateTime day) async {
    final doc = await _counterMenus.doc(CounterMenu.keyFor(day)).get();
    return doc.exists ? CounterMenu.fromDoc(doc) : CounterMenu(date: CounterMenu.keyFor(day));
  }

  Future<void> saveCounterMenu(CounterMenu menu) => _counterMenus.doc(menu.date).set(menu.toMap());

  /// Rings up a walk-in sale: checks stock, takes it off the shelf and records a completed counter order.
  Future<String> recordCounterSale({
    required List<CartLine> lines,
    required double discount,
    required PaymentMethod paymentMethod,
    double? amountTendered,
    String? customerName,
    required String servedBy,
  }) {
    if (lines.isEmpty) throw const ShopException('Add at least one item to the sale.');

    return _db.runTransaction((tx) async {
      final fresh = <String, Product>{};
      for (final id in lines.map((line) => line.product.id).toSet()) {
        final snapshot = await tx.get(_products.doc(id));
        if (!snapshot.exists) throw const ShopException('One of the items is no longer for sale.');
        fresh[id] = Product.fromDoc(snapshot);
      }

      final demand = <String, Map<String, int>>{};
      for (final line in lines) {
        final sizes = demand.putIfAbsent(line.product.id, () => {});
        sizes[line.size?.code ?? ''] = (sizes[line.size?.code ?? ''] ?? 0) + line.quantity;
      }
      for (final MapEntry(key: id, value: sizes) in demand.entries) {
        final product = fresh[id]!;
        for (final MapEntry(key: code, value: quantity) in sizes.entries) {
          final size = ProductSize.fromCode(code);
          if (product.stockFor(size) < quantity) {
            throw ShopException('Only ${product.stockFor(size)} of ${product.name}${size == null ? '' : ' (${size.label})'} in stock.');
          }
        }
      }

      final items = [
        for (final line in lines)
          OrderItem(
            productId: line.product.id,
            name: fresh[line.product.id]!.name,
            size: line.size,
            unitPrice: fresh[line.product.id]!.priceFor(line.size),
            quantity: line.quantity,
            lineTotal: round2(fresh[line.product.id]!.priceFor(line.size) * line.quantity),
            art: fresh[line.product.id]!.art,
            imageUrl: fresh[line.product.id]!.imageFor(line.size),
          ),
      ];
      final subtotal = round2(items.fold(0.0, (acc, item) => acc + item.lineTotal));
      final cut = round2(min(max(0, discount), subtotal));
      final total = round2(subtotal - cut);
      if (paymentMethod == PaymentMethod.cash && (amountTendered ?? 0) < total) {
        throw ShopException('The cash received is less than the total of RM ${total.toStringAsFixed(2)}.');
      }

      final orderRef = await _freeOrderRef(tx);
      for (final MapEntry(key: id, value: sizes) in demand.entries) {
        tx.update(_products.doc(id), _stockChange(fresh[id]!, sizes, -1));
      }
      tx.set(orderRef, {
        'userId': '',
        'customerName': customerName == null || customerName.trim().isEmpty ? 'Walk-in customer' : customerName.trim(),
        'email': '',
        'status': OrderStatus.completed.name,
        'channel': SalesChannel.counter.name,
        'deliveryMethod': DeliveryMethod.pickup.name,
        'phone': '',
        'items': items.map((item) => item.toMap()).toList(),
        'productIds': demand.keys.toList(),
        'subtotal': subtotal,
        'deliveryFee': 0,
        'discount': cut,
        'total': total,
        'paymentMethod': paymentMethod.code,
        'paymentStatus': 'paid',
        'amountTendered': paymentMethod == PaymentMethod.cash ? amountTendered : null,
        'servedBy': servedBy,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'paidAt': FieldValue.serverTimestamp(),
      });
      return orderRef.id;
    });
  }

  /// Orders placed since [from], newest first, for the sales report and the counter.
  Stream<List<ShopOrder>> ordersSince(DateTime from) => _orders
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ShopOrder.fromDoc).toList());

  // ---------------------------------------------------------------- Refunds

  CollectionReference<Json> get _refunds => _db.collection('refunds');

  /// A customer's view passes [userId] so the query matches the security rules.
  Stream<List<Refund>> refundsForOrder(String orderCode, {String? userId}) {
    Query<Json> query = _refunds.where('orderCode', isEqualTo: orderCode);
    if (userId != null) query = query.where('userId', isEqualTo: userId);
    return query.snapshots().map((snapshot) => snapshot.docs.map(Refund.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Stream<List<Refund>> allRefunds() =>
      _refunds.orderBy('createdAt', descending: true).limit(200).snapshots().map((snapshot) => snapshot.docs.map(Refund.fromDoc).toList());

  List<Json> _refundItems(ShopOrder order, Map<int, int> quantities) => [
    for (final MapEntry(key: index, value: quantity) in quantities.entries)
      if (quantity > 0 && index < order.items.length)
        RefundItem(
          index: index,
          name: order.items[index].name,
          size: order.items[index].size,
          quantity: quantity,
          unitPrice: order.items[index].unitPrice,
        ).toMap(),
  ];

  /// A customer asks for money back on items from a completed order.
  Future<void> requestRefund({
    required ShopOrder order,
    required List<Refund> existing,
    required RefundReason reason,
    String? details,
    required Map<int, int> quantities,
  }) async {
    if (!order.canRequestRefund(existing)) throw const ShopException('This order can no longer be refunded online. Please contact us instead.');
    final refundable = order.refundableQuantities(existing);
    if (quantities.entries.any((entry) => entry.value > (refundable[entry.key] ?? 0))) {
      throw const ShopException('You picked more items than can be refunded.');
    }
    final items = _refundItems(order, quantities);
    if (items.isEmpty) throw const ShopException('Choose at least one item to refund.');

    await _refunds.add({
      'orderCode': order.code,
      'userId': order.userId,
      'customerName': order.customerName,
      'status': RefundStatus.requested.name,
      'reason': reason.code,
      'details': details == null || details.trim().isEmpty ? null : details.trim(),
      'items': items,
      'amount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Pays a refund out and, if asked, puts the returned items back in stock.
  Future<void> approveRefund(
    Refund refund, {
    required double amount,
    required RefundMethod method,
    required bool restock,
    String? note,
    required String staffName,
  }) {
    return _db.runTransaction((tx) async {
      final refundRef = _refunds.doc(refund.id);
      final current = Refund.fromDoc(await tx.get(refundRef));
      if (current.status != RefundStatus.requested) throw const ShopException('This refund has already been handled.');
      await _payOut(tx, refundRef, current.orderCode, current.items, amount: amount, method: method, restock: restock, note: note, staffName: staffName);
    });
  }

  /// Staff refund an order straight away, e.g. after a phone call.
  Future<void> issueRefund({
    required ShopOrder order,
    required RefundReason reason,
    required Map<int, int> quantities,
    required double amount,
    required RefundMethod method,
    required bool restock,
    String? note,
    required String staffName,
  }) {
    final items = [for (final item in _refundItems(order, quantities)) RefundItem.fromMap(item)];
    return _db.runTransaction((tx) async {
      final refundRef = _refunds.doc();
      await _payOut(
        tx,
        refundRef,
        order.code,
        items,
        amount: amount,
        method: method,
        restock: restock,
        note: note,
        staffName: staffName,
        create: {
          'orderCode': order.code,
          'userId': order.userId,
          'customerName': order.customerName,
          'reason': reason.code,
          'details': 'Issued by staff.',
          'items': items.map((item) => item.toMap()).toList(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> _payOut(
    Transaction tx,
    DocumentReference<Json> refundRef,
    String orderCode,
    List<RefundItem> items, {
    required double amount,
    required RefundMethod method,
    required bool restock,
    String? note,
    required String staffName,
    Json? create,
  }) async {
    final orderRef = _orders.doc(orderCode);
    final order = ShopOrder.fromDoc(await tx.get(orderRef));
    if (!order.canBeRefunded) throw ShopException('Order $orderCode can’t be refunded.');
    if (amount <= 0 || amount > order.refundableAmount + 0.001) {
      throw ShopException('Enter an amount between RM 0.01 and RM ${order.refundableAmount.toStringAsFixed(2)}.');
    }

    final returned = <String, Map<String, int>>{};
    if (restock) {
      for (final item in items) {
        if (item.index >= order.items.length) continue;
        final orderItem = order.items[item.index];
        final sizes = returned.putIfAbsent(orderItem.productId, () => {});
        sizes[orderItem.size?.code ?? ''] = (sizes[orderItem.size?.code ?? ''] ?? 0) + item.quantity;
      }
    }
    final products = <String, Product>{};
    for (final id in returned.keys) {
      final snapshot = await tx.get(_products.doc(id));
      if (snapshot.exists) products[id] = Product.fromDoc(snapshot);
    }

    final payout = {
      'status': RefundStatus.approved.name,
      'amount': round2(amount),
      'method': method.code,
      'restocked': restock,
      'adminNote': note == null || note.trim().isEmpty ? null : note.trim(),
      'processedBy': staffName,
      'processedAt': FieldValue.serverTimestamp(),
    };
    create == null ? tx.update(refundRef, payout) : tx.set(refundRef, {...create, ...payout});
    tx.update(orderRef, {'refundedAmount': round2(order.refundedAmount + amount)});
    for (final MapEntry(key: id, value: product) in products.entries) {
      tx.update(_products.doc(id), _stockChange(product, returned[id]!, 1));
    }
  }

  Future<void> rejectRefund(Refund refund, {required String note, required String staffName}) {
    return _db.runTransaction((tx) async {
      final refundRef = _refunds.doc(refund.id);
      final current = Refund.fromDoc(await tx.get(refundRef));
      if (current.status != RefundStatus.requested) throw const ShopException('This refund has already been handled.');
      tx.update(refundRef, {
        'status': RefundStatus.rejected.name,
        'amount': 0,
        'adminNote': note.trim(),
        'processedBy': staffName,
        'processedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// The stock fields after adding ([direction] 1) or taking ([direction] -1) the given units.
  Json _stockChange(Product product, Map<String, int> unitsBySize, int direction) {
    if (!product.hasSizes) {
      final units = unitsBySize.values.fold<int>(0, (acc, n) => acc + n);
      return {'stock': max(0, product.stock + direction * units)};
    }

    final counts = {for (final size in product.sizes) size.code: product.stockFor(size)};
    for (final MapEntry(key: code, value: units) in unitsBySize.entries) {
      final target = counts.containsKey(code) ? code : product.defaultSize!.code;
      counts[target] = max(0, counts[target]! + direction * units);
    }
    return {'sizeStock': counts, 'stock': counts.values.fold<int>(0, (acc, n) => acc + n)};
  }

  /// Cancels an order and puts its items back in stock. Customers may only cancel orders not yet being prepared.
  Future<void> cancelOrder(String code, CancellationReason reason, {String? note, required bool byCustomer}) {
    return _db.runTransaction((tx) async {
      final orderRef = _orders.doc(code);
      final order = ShopOrder.fromDoc(await tx.get(orderRef));

      if (!order.status.isActive) throw const ShopException('This order is already closed.');
      if (byCustomer && order.status != OrderStatus.received) {
        throw const ShopException('Orders already being prepared can’t be cancelled.');
      }

      final returned = <String, Map<String, int>>{};
      for (final item in order.items) {
        final sizes = returned.putIfAbsent(item.productId, () => {});
        sizes[item.size?.code ?? ''] = (sizes[item.size?.code ?? ''] ?? 0) + item.quantity;
      }

      final products = <String, Product>{};
      for (final id in returned.keys) {
        final snapshot = await tx.get(_products.doc(id));
        if (snapshot.exists) products[id] = Product.fromDoc(snapshot);
      }

      for (final MapEntry(key: id, value: product) in products.entries) {
        tx.update(_products.doc(id), _stockChange(product, returned[id]!, 1));
      }

      tx.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason.code,
        'cancellationNote': note == null || note.trim().isEmpty ? null : note.trim(),
      });
    });
  }

  /// Moves an order to its next step. Cash orders count as paid once completed.
  Future<void> advanceOrder(ShopOrder order) async {
    final next = order.status.next;
    if (next == null) return;

    await _orders.doc(order.code).update({
      'status': next.name,
      next.timestampField: FieldValue.serverTimestamp(),
      if (next == OrderStatus.completed && !order.isPaid) ...{'paymentStatus': 'paid', 'paidAt': FieldValue.serverTimestamp()},
    });
  }

  // ---------------------------------------------------------------- Admin: menu

  static String slugify(String text) => text.toLowerCase().replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

  /// Saves a product. New products get an id made from their name.
  Future<String> saveProduct(Product product, {required bool isNew}) async {
    if (!isNew) {
      await _products.doc(product.id).update(product.toMap());
      return product.id;
    }

    final base = slugify(product.name).isEmpty ? 'tart' : slugify(product.name);
    var id = base;
    for (var suffix = 2; (await _products.doc(id).get()).exists; suffix++) {
      id = '$base-$suffix';
    }
    await _products.doc(id).set({...product.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return id;
  }

  Future<void> deleteProduct(String id) => _products.doc(id).delete();

  Future<void> setProductActive(Product product, bool isActive) => _products.doc(product.id).update({'isActive': isActive});

  /// Sets stock counts by size (the `null` key for products without sizes). Sizes left out keep their count.
  Future<void> setStock(Product product, Map<ProductSize?, int> counts) {
    if (!product.hasSizes) {
      return _products.doc(product.id).update({'stock': max(0, counts[null] ?? product.stock)});
    }
    final sizeStock = {for (final size in product.sizes) size.code: max(0, counts[size] ?? product.stockFor(size))};
    return _products.doc(product.id).update({'sizeStock': sizeStock, 'stock': sizeStock.values.fold<int>(0, (acc, value) => acc + value)});
  }

  Future<void> saveCategory(MenuCategory category) => _categories.doc(category.id).set(category.toMap());

  Future<void> deleteCategory(String id) => _categories.doc(id).delete();

  // ---------------------------------------------------------------- Admin: vouchers & settings

  Stream<List<Voucher>> vouchers() =>
      _vouchers.snapshots().map((snapshot) => snapshot.docs.map(Voucher.fromDoc).toList()..sort((a, b) => a.code.compareTo(b.code)));

  Future<void> saveVoucher(Voucher voucher) => _vouchers.doc(voucher.code.trim().toUpperCase()).set(voucher.toMap());

  Future<void> deleteVoucher(String code) => _vouchers.doc(code).delete();

  Future<void> saveStorefront(Map<String, String> values) => _storefront.set(values, SetOptions(merge: true));

  /// Billplz and Lalamove keys. Staff-only: kept out of the public settings document.
  DocumentReference<Json> get _integrations => _db.collection('private').doc('integrations');

  Stream<Json> integrations() => _integrations.snapshots().map((doc) => doc.data() ?? const {});

  Future<void> saveIntegrations(Json values) => _integrations.set({...values, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  /// Adds a delivery from the supplier to stock, without overwriting sales made meanwhile.
  Future<void> restock(Product product, ProductSize? size, int quantity) {
    if (quantity <= 0) return Future.value();
    if (!product.hasSizes || size == null) {
      return _products.doc(product.id).update({'stock': FieldValue.increment(quantity)});
    }
    return _products.doc(product.id).update({'sizeStock.${size.code}': FieldValue.increment(quantity), 'stock': FieldValue.increment(quantity)});
  }

  // ---------------------------------------------------------------- Sample data

  /// Adds 20 made-up customers and their sales (plus a few counter sales) built from the live menu.
  /// Stock is not touched. Returns the number of customers and orders written.
  Future<(int, int)> addSampleData(List<Product> menu, Storefront storefront) async {
    final sample = SampleData.build(menu: menu, storefront: storefront, now: DateTime.now());
    Json withTimestamps(Json data) => {for (final MapEntry(:key, :value) in data.entries) key: value is DateTime ? Timestamp.fromDate(value) : value};

    final batch = _db.batch();
    for (final MapEntry(key: id, value: data) in sample.customers.entries) {
      batch.set(_users.doc(id), withTimestamps(data));
    }
    for (final MapEntry(key: code, value: data) in sample.orders.entries) {
      batch.set(_orders.doc(code), withTimestamps(data));
    }
    await batch.commit();
    return (sample.customers.length, sample.orders.length);
  }

  /// Deletes everything [addSampleData] made. Real customers and orders are never touched.
  Future<int> removeSampleData() async {
    final batch = _db.batch();
    var removed = 0;
    for (final collection in [_users, _orders]) {
      for (final doc in (await collection.where('sample', isEqualTo: true).get()).docs) {
        batch.delete(doc.reference);
        removed++;
      }
    }
    await batch.commit();
    return removed;
  }

  /// Copies the website's collections, products, vouchers and shop settings into Firestore exactly as they are
  /// in the website database (see seed_data.dart), replacing earlier copies, and removes the old placeholder menu.
  Future<int> importStarterCatalog() async {
    final batch = _db.batch();
    var copied = 0;

    for (final MapEntry(key: id, value: data) in seedCategories.entries) {
      batch.set(_categories.doc(id), MenuCategory.fromMap(id, data).toMap());
      copied++;
    }

    for (final MapEntry(key: id, value: data) in seedProducts.entries) {
      final exists = (await _products.doc(id).get()).exists;
      batch.set(_products.doc(id), {...Product.fromMap(id, data).toMap(), if (!exists) 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      copied++;
    }

    for (final id in placeholderProductIds) {
      batch.delete(_products.doc(id));
    }
    for (final id in placeholderCategoryIds) {
      batch.delete(_categories.doc(id));
    }

    for (final voucher in seedVouchers) {
      final expiresAt = voucher['expiresAt'] as String?;
      batch.set(_vouchers.doc(voucher['code'] as String), {
        'description': voucher['description'],
        'type': voucher['type'],
        'value': voucher['value'],
        'minSubtotal': voucher['minSubtotal'],
        'isActive': voucher['isActive'],
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(DateTime.parse(expiresAt)),
      });
      copied++;
    }

    batch.set(_storefront, seedStorefront, SetOptions(merge: true));
    await batch.commit();
    return copied;
  }
}
