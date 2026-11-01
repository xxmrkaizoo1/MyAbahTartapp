import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import '../services/seed_data.dart';
import 'product.dart';

double round2(double value) => (value * 100).roundToDouble() / 100;

class Voucher {
  const Voucher({
    required this.code,
    this.description = '',
    this.type = typeFixed,
    required this.value,
    this.minSubtotal = 0,
    this.isActive = true,
    this.expiresAt,
  });

  static const typeFixed = 'fixed';
  static const typePercent = 'percent';

  final String code;
  final String description;
  final String type;
  final double value;
  final double minSubtotal;
  final bool isActive;
  final DateTime? expiresAt;

  factory Voucher.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const {};
    return Voucher(
      code: doc.id,
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? typeFixed,
      value: readDouble(data['value']),
      minSubtotal: readDouble(data['minSubtotal']),
      isActive: data['isActive'] as bool? ?? true,
      expiresAt: readTime(data['expiresAt']),
    );
  }

  Json toMap() => {
    'description': description,
    'type': type,
    'value': value,
    'minSubtotal': minSubtotal,
    'isActive': isActive,
    'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
  };

  bool get isUsable => isActive && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  double discountFor(double subtotal) {
    if (!isUsable || subtotal < minSubtotal) return 0;
    final discount = type == typePercent ? subtotal * value / 100 : value;
    return round2(min(discount, subtotal));
  }

  String get valueLabel {
    if (type == typePercent) {
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}%';
    }
    return 'RM ${value.toStringAsFixed(2)}';
  }
}

class Review {
  const Review({required this.userId, required this.userName, required this.rating, required this.comment, this.createdAt});

  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  factory Review.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const {};
    return Review(
      userId: doc.id,
      userName: data['userName'] as String? ?? 'Customer',
      rating: readInt(data['rating']).clamp(1, 5),
      comment: data['comment'] as String? ?? '',
      createdAt: readTime(data['createdAt']),
    );
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.role = 'customer',
    this.fromWebsite = false,
    this.isSample = false,
    this.joinedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String role;

  /// Copied from the website's customer list (tool/import_website_data.py), not an app account.
  final bool fromWebsite;

  /// Made up by "Add sample customers & sales" in Kitchen mode.
  final bool isSample;
  final DateTime? joinedAt;

  factory AppUser.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      role: data['role'] as String? ?? 'customer',
      fromWebsite: data['fromWebsite'] as bool? ?? false,
      isSample: data['sample'] as bool? ?? false,
      joinedAt: readTime(data['createdAt']),
    );
  }

  bool get isAdmin => role == 'admin';

  String get firstName => name.trim().split(' ').first;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2);
    final letters = words.map((word) => word[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Shop-front wording and delivery settings that admins can edit, with the website's defaults.
class Storefront {
  const Storefront(this.values);

  /// The website's settings, copied exactly (seed_data.dart); used until the shop's own settings load.
  static const defaults = seedStorefront;

  static const fallback = Storefront(defaults);

  final Map<String, String> values;

  factory Storefront.fromMap(Json? data) => Storefront({
    ...defaults,
    if (data != null)
      for (final entry in data.entries)
        if (defaults.containsKey(entry.key) && entry.value != null) entry.key: '${entry.value}',
  });

  String get(String key) => values[key] ?? '';

  /// Words scrolling across the home page ticker, one per line in the setting.
  List<String> get tickerItems => get('ticker').split(RegExp(r'[\n,]')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();

  String label(DeliveryMethod method) => get('delivery_${method.name}_label');

  String description(DeliveryMethod method) => get('delivery_${method.name}_description');

  bool isEnabled(DeliveryMethod method) => get('delivery_${method.name}_enabled') == '1';

  List<DeliveryMethod> get enabledMethods {
    final methods = DeliveryMethod.values.where(isEnabled).toList();
    return methods.isEmpty ? [DeliveryMethod.pickup] : methods;
  }

  /// The subtotal from which standard delivery is free, or null when it never is.
  double? get freeDeliveryThreshold {
    final threshold = double.tryParse(get('delivery_free_over')) ?? 0;
    return threshold > 0 && isEnabled(DeliveryMethod.standard) ? threshold : null;
  }

  double feeFor(DeliveryMethod method, double subtotal) {
    final threshold = freeDeliveryThreshold;
    if (method == DeliveryMethod.standard && threshold != null && subtotal >= threshold) return 0;
    return round2(double.tryParse(get('delivery_${method.name}_fee')) ?? 0);
  }
}
