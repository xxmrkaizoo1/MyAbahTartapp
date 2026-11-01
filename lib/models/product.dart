import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

typedef Json = Map<String, dynamic>;

DateTime? readTime(dynamic value) => value is Timestamp ? value.toDate() : null;

double readDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int readInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String? _text(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.art, this.imageUrl, this.sortOrder = 0});

  final String id;
  final String name;
  final String art;

  /// A photo for the collection tile: an https URL or a bundled `asset:` path.
  final String? imageUrl;
  final int sortOrder;

  factory MenuCategory.fromDoc(DocumentSnapshot<Json> doc) => MenuCategory.fromMap(doc.id, doc.data() ?? const {});

  factory MenuCategory.fromMap(String id, Json data) => MenuCategory(
    id: id,
    name: data['name'] as String? ?? '',
    art: data['art'] as String? ?? 'pineapple',
    imageUrl: _text(data['imageUrl']),
    sortOrder: readInt(data['sortOrder']),
  );

  Json toMap() => {'name': name, 'art': art, 'imageUrl': imageUrl, 'sortOrder': sortOrder};
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    this.tagline = '',
    this.description = '',
    required this.price,
    this.sizePrices = const {},
    this.sizeStock = const {},
    this.sizePieces = const {},
    this.sizeImages = const {},
    this.unitLabel = 'Single',
    this.weightGrams,
    this.art = 'pineapple',
    this.imageUrl,
    this.stock = 0,
    this.lowStockThreshold = 10,
    this.isActive = true,
    this.isBestseller = false,
    this.isSeasonal = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String categoryId;
  final String tagline;
  final String description;
  final double price;

  /// Prices keyed by size code (S, M, L). Empty when the product has no sizes.
  final Map<String, double> sizePrices;
  final Map<String, int> sizeStock;
  final Map<String, int> sizePieces;

  /// A different photo per size, keyed by size code, like the website's size images.
  final Map<String, String> sizeImages;
  final String unitLabel;
  final int? weightGrams;
  final String art;

  /// The product photo: an https URL or a bundled `asset:` path. Null shows a drawn tart.
  final String? imageUrl;
  final int stock;
  final int lowStockThreshold;
  final bool isActive;
  final bool isBestseller;
  final bool isSeasonal;
  final DateTime? createdAt;

  factory Product.fromDoc(DocumentSnapshot<Json> doc) => Product.fromMap(doc.id, doc.data() ?? const {});

  factory Product.fromMap(String id, Json data) {
    final weight = readInt(data['weightGrams']);
    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      tagline: data['tagline'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: readDouble(data['price']),
      sizePrices: _map(data['sizePrices'], readDouble),
      sizeStock: _map(data['sizeStock'], readInt),
      sizePieces: _map(data['sizePieces'], readInt),
      sizeImages: _map(data['sizeImages'], (value) => '$value'),
      unitLabel: data['unitLabel'] as String? ?? 'Single',
      weightGrams: weight > 0 ? weight : null,
      art: data['art'] as String? ?? 'pineapple',
      imageUrl: _text(data['imageUrl']),
      stock: readInt(data['stock']),
      lowStockThreshold: data['lowStockThreshold'] == null ? 10 : readInt(data['lowStockThreshold']),
      isActive: data['isActive'] as bool? ?? true,
      isBestseller: data['isBestseller'] as bool? ?? false,
      isSeasonal: data['isSeasonal'] as bool? ?? false,
      createdAt: readTime(data['createdAt']),
    );
  }

  static Map<String, T> _map<T>(dynamic value, T Function(dynamic) read) =>
      value is Map ? {for (final entry in value.entries) '${entry.key}': read(entry.value)} : <String, T>{};

  /// Total stock always equals the sum of the size counts for products sold in sizes.
  Json toMap() {
    final counts = {for (final size in sizes) size.code: max(0, sizeStock[size.code] ?? 0)};
    return {
      'name': name,
      'categoryId': categoryId,
      'tagline': tagline,
      'description': description,
      'price': hasSizes ? sizePrices.values.reduce(min) : price,
      'sizePrices': hasSizes ? sizePrices : null,
      'sizeStock': hasSizes ? counts : null,
      'sizePieces': hasSizes && sizePieces.isNotEmpty ? sizePieces : null,
      'sizeImages': hasSizes && sizeImages.isNotEmpty ? sizeImages : null,
      'unitLabel': unitLabel,
      'weightGrams': weightGrams,
      'art': art,
      'imageUrl': imageUrl,
      'stock': hasSizes ? counts.values.fold<int>(0, (acc, n) => acc + n) : max(0, stock),
      'lowStockThreshold': lowStockThreshold,
      'isActive': isActive,
      'isBestseller': isBestseller,
      'isSeasonal': isSeasonal,
    };
  }

  /// The sizes this product is sold in, smallest first.
  List<ProductSize> get sizes => ProductSize.values.where((size) => sizePrices.containsKey(size.code)).toList();

  bool get hasSizes => sizePrices.isNotEmpty;

  double priceFor(ProductSize? size) => size == null ? price : (sizePrices[size.code] ?? price);

  double get fromPrice => hasSizes ? sizePrices.values.reduce(min) : price;

  /// The photo for a size, falling back to the main photo.
  String? imageFor(ProductSize? size) => (size == null ? null : sizeImages[size.code]) ?? imageUrl;

  /// e.g. "Balang · 500 g".
  String get unitDetail => weightGrams == null ? unitLabel : '$unitLabel · ${weightGrams! >= 1000 ? '${weightGrams! / 1000} kg' : '$weightGrams g'}';

  int stockFor(ProductSize? size) => size == null || !hasSizes ? stock : (sizeStock[size.code] ?? 0);

  /// The first size in stock, or the smallest size when every size is sold out.
  ProductSize? get defaultSize {
    if (!hasSizes) return null;
    return sizes.firstWhere((size) => stockFor(size) > 0, orElse: () => sizes.first);
  }

  String sizeLabel(ProductSize size) {
    final pieces = sizePieces[size.code];
    return pieces != null && pieces > 0 ? '${size.label} · $pieces pcs' : size.label;
  }

  bool get isSoldOut => stock < 1;

  bool get isLowStock => stock <= lowStockThreshold;
}
