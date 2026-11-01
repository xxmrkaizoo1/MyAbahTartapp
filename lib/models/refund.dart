import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'order.dart';
import 'product.dart';

class RefundItem {
  const RefundItem({required this.index, required this.name, this.size, required this.quantity, required this.unitPrice});

  /// Position of the item in the order's item list.
  final int index;
  final String name;
  final ProductSize? size;
  final int quantity;
  final double unitPrice;

  factory RefundItem.fromMap(Map data) => RefundItem(
    index: readInt(data['index']),
    name: data['name'] as String? ?? '',
    size: ProductSize.fromCode(data['size'] as String?),
    quantity: readInt(data['quantity']),
    unitPrice: readDouble(data['unitPrice']),
  );

  Json toMap() => {'index': index, 'name': name, 'size': size?.code, 'quantity': quantity, 'unitPrice': unitPrice};

  double get value => ((unitPrice * quantity) * 100).roundToDouble() / 100;

  String get displayName => size == null ? name : '$name (${size!.label})';
}

class Refund {
  const Refund({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.customerName,
    required this.status,
    required this.reason,
    this.details,
    this.items = const [],
    this.amount = 0,
    this.method,
    this.restocked = false,
    this.adminNote,
    this.processedBy,
    required this.createdAt,
    this.processedAt,
  });

  final String id;
  final String orderCode;

  /// Empty for refunds staff issued themselves.
  final String userId;
  final String customerName;
  final RefundStatus status;
  final RefundReason reason;
  final String? details;
  final List<RefundItem> items;
  final double amount;
  final RefundMethod? method;
  final bool restocked;
  final String? adminNote;
  final String? processedBy;
  final DateTime createdAt;
  final DateTime? processedAt;

  factory Refund.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const {};
    return Refund(
      id: doc.id,
      orderCode: data['orderCode'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Customer',
      status: RefundStatus.parse(data['status'] as String?),
      reason: RefundReason.parse(data['reason'] as String?),
      details: data['details'] as String?,
      items: [for (final item in (data['items'] as List? ?? const [])) RefundItem.fromMap(item as Map)],
      amount: readDouble(data['amount']),
      method: RefundMethod.parse(data['method'] as String?),
      restocked: data['restocked'] as bool? ?? false,
      adminNote: data['adminNote'] as String?,
      processedBy: data['processedBy'] as String?,
      createdAt: readTime(data['createdAt']) ?? DateTime.now(),
      processedAt: readTime(data['processedAt']),
    );
  }

  /// The value of the returned items at the prices the customer paid.
  double get itemsValue => ((items.fold(0.0, (acc, item) => acc + item.value)) * 100).roundToDouble() / 100;
}

/// Refund rules that need both an order and its refunds, matching the website's Order model.
extension OrderRefunds on ShopOrder {
  /// Units of each item (by position) not yet refunded or awaiting a decision.
  Map<int, int> refundableQuantities(List<Refund> refunds) {
    final claimed = <int, int>{};
    for (final refund in refunds.where((refund) => refund.status != RefundStatus.rejected)) {
      for (final item in refund.items) {
        claimed[item.index] = (claimed[item.index] ?? 0) + item.quantity;
      }
    }
    return {for (final (index, item) in items.indexed) index: (item.quantity - (claimed[index] ?? 0)).clamp(0, item.quantity)};
  }

  Refund? pendingRefund(List<Refund> refunds) => refunds.where((refund) => refund.status == RefundStatus.requested).firstOrNull;

  /// Whether the customer can still ask for a refund themselves.
  bool canRequestRefund(List<Refund> refunds) =>
      canBeRefunded &&
      !isCounterSale &&
      userId.isNotEmpty &&
      pendingRefund(refunds) == null &&
      completedAt != null &&
      completedAt!.isAfter(DateTime.now().subtract(const Duration(days: ShopOrder.refundWindowDays))) &&
      refundableQuantities(refunds).values.any((quantity) => quantity > 0);
}
