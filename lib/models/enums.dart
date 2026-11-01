import 'package:material_ui/material_ui.dart';

enum ProductSize {
  small('S', 'Small'),
  medium('M', 'Medium'),
  large('L', 'Large');

  const ProductSize(this.code, this.label);

  final String code;
  final String label;

  static ProductSize? fromCode(String? code) {
    for (final size in values) {
      if (size.code == code) return size;
    }
    return null;
  }
}

enum OrderStatus {
  received('Order Received', 'New'),
  preparing('Being Prepared', 'Preparing'),
  ready('Ready', 'Ready'),
  completed('Completed', 'Completed'),
  cancelled('Cancelled', 'Cancelled');

  const OrderStatus(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  /// The statuses shown on the progress timeline.
  static const timeline = [OrderStatus.received, OrderStatus.preparing, OrderStatus.ready, OrderStatus.completed];

  static OrderStatus parse(String? value) => values.firstWhere((status) => status.name == value, orElse: () => OrderStatus.received);

  OrderStatus? get next => switch (this) {
    OrderStatus.received => OrderStatus.preparing,
    OrderStatus.preparing => OrderStatus.ready,
    OrderStatus.ready => OrderStatus.completed,
    _ => null,
  };

  bool get isActive => this == OrderStatus.received || this == OrderStatus.preparing || this == OrderStatus.ready;

  /// The verb on the button that moves an order into this status.
  String get actionLabel => switch (this) {
    OrderStatus.preparing => 'Start preparing',
    OrderStatus.ready => 'Mark ready',
    OrderStatus.completed => 'Complete',
    OrderStatus.cancelled => 'Cancel',
    OrderStatus.received => 'Receive',
  };

  /// The order document field that stamps when this status was reached.
  String get timestampField => '${name}At';

  Color get color => switch (this) {
    OrderStatus.received => const Color(0xFF2F7FD3),
    OrderStatus.preparing => const Color(0xFFE09B12),
    OrderStatus.ready => const Color(0xFF2E9D6A),
    OrderStatus.completed => const Color(0xFF8A6F61),
    OrderStatus.cancelled => const Color(0xFFD64545),
  };
}

enum DeliveryMethod {
  standard(Icons.local_shipping_outlined),
  express(Icons.bolt_rounded),
  pickup(Icons.storefront_outlined);

  const DeliveryMethod(this.icon);

  final IconData icon;

  static DeliveryMethod parse(String? value) => values.firstWhere((method) => method.name == value, orElse: () => DeliveryMethod.standard);

  bool get requiresAddress => this != DeliveryMethod.pickup;

  String get readyLabel => this == DeliveryMethod.pickup ? 'Ready for Pickup' : 'Out for Delivery';
}

enum CancellationReason {
  address('address', 'Address problem or outside our delivery area'),
  outOfStock('out_of_stock', 'Item sold out'),
  unreachable('unreachable', 'Couldn’t reach the customer'),
  payment('payment', 'Payment problem'),
  shopClosed('shop_closed', 'Kitchen closed or too busy'),
  customerRequest('customer_request', 'Customer asked to cancel'),
  changedMind('changed_mind', 'Changed my mind'),
  orderedByMistake('ordered_by_mistake', 'Ordered the wrong items or quantity'),
  wrongDetails('wrong_details', 'Wrong address or phone number'),
  takingTooLong('taking_too_long', 'It’s taking too long'),
  other('other', 'Something else');

  const CancellationReason(this.code, this.label);

  final String code;
  final String label;

  static const forShop = [address, outOfStock, unreachable, payment, shopClosed, customerRequest, other];
  static const forCustomers = [changedMind, orderedByMistake, wrongDetails, takingTooLong, other];

  static CancellationReason? fromCode(String? code) {
    for (final reason in values) {
      if (reason.code == code) return reason;
    }
    return null;
  }
}

enum SalesChannel {
  online('Online'),
  counter('Counter');

  const SalesChannel(this.label);

  final String label;

  static SalesChannel parse(String? value) => values.firstWhere((channel) => channel.name == value, orElse: () => SalesChannel.online);

  /// Chart colours: the website's blue and orange, stepped to pass contrast and colour-blind checks on the dark kitchen surface.
  Color get color => this == SalesChannel.online ? const Color(0xFF3D8BE6) : const Color(0xFFDE5F2C);
}

enum PaymentMethod {
  cash('cash', 'Cash', Icons.payments_outlined),
  eWallet('e_wallet', 'E-wallet / QR', Icons.qr_code_2_rounded),
  card('card', 'Card', Icons.credit_card_rounded),
  online('online', 'Online (Billplz)', Icons.lock_outline_rounded);

  const PaymentMethod(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;

  /// The ways a customer can pay at the shop counter.
  static const forCounter = [cash, eWallet, card];

  static PaymentMethod parse(String? code) => values.firstWhere((method) => method.code == code, orElse: () => PaymentMethod.cash);
}

enum RefundReason {
  damaged('damaged', 'Arrived damaged'),
  wrongItem('wrong_item', 'Wrong item or size'),
  missingItem('missing_item', 'Item missing'),
  quality('quality', 'Not fresh / quality issue'),
  other('other', 'Something else');

  const RefundReason(this.code, this.label);

  final String code;
  final String label;

  static RefundReason parse(String? code) => values.firstWhere((reason) => reason.code == code, orElse: () => RefundReason.other);
}

enum RefundStatus {
  requested('Awaiting review', Color(0xFFE09B12)),
  approved('Refunded', Color(0xFF2E9D6A)),
  rejected('Declined', Color(0xFFD64545));

  const RefundStatus(this.label, this.color);

  final String label;
  final Color color;

  static RefundStatus parse(String? value) => values.firstWhere((status) => status.name == value, orElse: () => RefundStatus.requested);
}

enum RefundMethod {
  cash('cash', 'Cash'),
  bankTransfer('bank_transfer', 'Bank transfer'),
  eWallet('e_wallet', 'E-wallet (DuitNow / TNG)');

  const RefundMethod(this.code, this.label);

  final String code;
  final String label;

  static RefundMethod? parse(String? code) {
    for (final method in values) {
      if (method.code == code) return method;
    }
    return null;
  }
}
