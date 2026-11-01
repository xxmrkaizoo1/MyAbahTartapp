import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'product.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    this.size,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.art = 'pineapple',
    this.imageUrl,
  });

  final String productId;
  final String name;
  final ProductSize? size;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String art;
  final String? imageUrl;

  factory OrderItem.fromMap(Map data) => OrderItem(
    productId: data['productId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    size: ProductSize.fromCode(data['size'] as String?),
    unitPrice: readDouble(data['unitPrice']),
    quantity: readInt(data['quantity']),
    lineTotal: readDouble(data['lineTotal']),
    art: data['art'] as String? ?? 'pineapple',
    imageUrl: data['imageUrl'] as String?,
  );

  Json toMap() => {
    'productId': productId,
    'name': name,
    'size': size?.code,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'lineTotal': lineTotal,
    'art': art,
    'imageUrl': imageUrl,
  };

  String get displayName => size == null ? name : '$name (${size!.label})';
}

class ShopOrder {
  const ShopOrder({
    required this.code,
    required this.userId,
    required this.customerName,
    this.email = '',
    required this.status,
    required this.deliveryMethod,
    this.phone = '',
    this.address,
    this.notes,
    this.items = const [],
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.discount = 0,
    this.total = 0,
    this.voucherCode,
    this.isPaid = false,
    required this.createdAt,
    this.preparingAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancellationNote,
    this.channel = SalesChannel.online,
    this.paymentMethod = PaymentMethod.cash,
    this.amountTendered,
    this.servedBy,
    this.refundedAmount = 0,
  });

  /// How many days after completion a customer may ask for a refund, as on the website.
  static const refundWindowDays = 7;

  final SalesChannel channel;
  final PaymentMethod paymentMethod;

  /// Cash handed over at the counter.
  final double? amountTendered;

  /// The staff member who rang up a counter sale.
  final String? servedBy;

  /// Money already paid back on approved refunds.
  final double refundedAmount;

  final String code;
  final String userId;
  final String customerName;
  final String email;
  final OrderStatus status;
  final DeliveryMethod deliveryMethod;
  final String phone;
  final String? address;
  final String? notes;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String? voucherCode;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final CancellationReason? cancellationReason;
  final String? cancellationNote;

  factory ShopOrder.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const {};
    return ShopOrder(
      code: doc.id,
      userId: data['userId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Customer',
      email: data['email'] as String? ?? '',
      status: OrderStatus.parse(data['status'] as String?),
      deliveryMethod: DeliveryMethod.parse(data['deliveryMethod'] as String?),
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String?,
      notes: data['notes'] as String?,
      items: [for (final item in (data['items'] as List? ?? const [])) OrderItem.fromMap(item as Map)],
      subtotal: readDouble(data['subtotal']),
      deliveryFee: readDouble(data['deliveryFee']),
      discount: readDouble(data['discount']),
      total: readDouble(data['total']),
      voucherCode: data['voucherCode'] as String?,
      isPaid: data['paymentStatus'] == 'paid',
      // Server timestamps are null until the write reaches Firestore.
      createdAt: readTime(data['createdAt']) ?? DateTime.now(),
      preparingAt: readTime(data['preparingAt']),
      readyAt: readTime(data['readyAt']),
      completedAt: readTime(data['completedAt']),
      cancelledAt: readTime(data['cancelledAt']),
      cancellationReason: CancellationReason.fromCode(data['cancellationReason'] as String?),
      cancellationNote: data['cancellationNote'] as String?,
      channel: SalesChannel.parse(data['channel'] as String?),
      paymentMethod: PaymentMethod.parse(data['paymentMethod'] as String?),
      amountTendered: data['amountTendered'] == null ? null : readDouble(data['amountTendered']),
      servedBy: data['servedBy'] as String?,
      refundedAmount: readDouble(data['refundedAmount']),
    );
  }

  bool get isCounterSale => channel == SalesChannel.counter;

  /// Change handed back for a cash payment.
  double? get changeGiven => amountTendered == null ? null : ((amountTendered! - total) * 100).roundToDouble() / 100;

  /// Total minus what has already been refunded.
  double get netTotal => ((total - refundedAmount) * 100).roundToDouble() / 100;

  double get refundableAmount => netTotal < 0 ? 0 : netTotal;

  bool get canBeRefunded => status == OrderStatus.completed && refundableAmount > 0;

  /// When the kitchen expects the order to be ready, following the website's estimate:
  /// 20 minutes, plus 5 per order ahead in the queue (up to 12) and 2 per item (up to 10).
  DateTime? estimatedReadyAt({int ordersAhead = 0}) {
    if (status != OrderStatus.received && status != OrderStatus.preparing) return readyAt;
    final minutes = 20 + (ordersAhead.clamp(0, 12)) * 5 + (itemCount.clamp(0, 10)) * 2;
    return (preparingAt ?? createdAt).add(Duration(minutes: minutes));
  }

  String get statusLabel => status == OrderStatus.ready ? deliveryMethod.readyLabel : status.label;

  DateTime? timestampFor(OrderStatus status) => switch (status) {
    OrderStatus.received => createdAt,
    OrderStatus.preparing => preparingAt,
    OrderStatus.ready => readyAt,
    OrderStatus.completed => completedAt,
    OrderStatus.cancelled => cancelledAt,
  };

  int get itemCount => items.fold<int>(0, (acc, item) => acc + item.quantity);

  String get paymentLabel {
    if (isCounterSale) return 'Paid at counter · ${paymentMethod.label}';
    if (isPaid) return paymentMethod == PaymentMethod.online ? 'Paid online' : 'Paid in cash';
    return deliveryMethod.requiresAddress ? 'Cash on delivery' : 'Pay at pickup';
  }

  String get initials {
    final words = customerName.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2);
    return words.map((word) => word[0].toUpperCase()).join();
  }
}
