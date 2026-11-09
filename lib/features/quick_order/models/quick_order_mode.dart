import '../../../models/product.dart';

class QuickOrderItem {
  final String productId;
  final int quantity;
  Product? product;
  final String? customTitle;

  QuickOrderItem({
    required this.productId,
    this.quantity = 1,
    this.product,
    this.customTitle,
  });

  double get price => product?.price ?? 0.0;
  double get lineTotal => price * quantity;
  bool get isAvailable => product != null && product!.isAvailable;
  String get displayName => product?.name ?? customTitle ?? 'Product';

  factory QuickOrderItem.fromJson(Map<String, dynamic> json, {Product? resolvedProduct}) {
    return QuickOrderItem(
      productId: json['product_id']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      product: resolvedProduct,
      customTitle: json['product_name'] ?? json['custom_title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'custom_title': displayName,
    };
  }

  QuickOrderItem copyWith({
    String? productId,
    int? quantity,
    Product? product,
    String? customTitle,
  }) {
    return QuickOrderItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
      customTitle: customTitle ?? this.customTitle,
    );
  }
}

class QuickOrderMode {
  final String id;
  final String name;
  final String iconName;
  final String tagline;
  final bool isPredefined;
  final List<QuickOrderItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> targetKeywords;

  QuickOrderMode({
    required this.id,
    required this.name,
    this.iconName = 'essentials',
    this.tagline = 'Your regular groceries, one tap away',
    this.isPredefined = false,
    required this.items,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.targetKeywords = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalProductsCount => items.length;

  int get totalUnitsCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get estimatedTotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  List<QuickOrderItem> get availableItems => items.where((i) => i.isAvailable).toList();

  List<QuickOrderItem> get unavailableItems => items.where((i) => !i.isAvailable).toList();

  bool get hasUnavailableItems => unavailableItems.isNotEmpty;

  factory QuickOrderMode.fromJson(Map<String, dynamic> json, {List<Product> catalog = const []}) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((itemJson) {
      final map = itemJson as Map<String, dynamic>;
      final pid = map['product_id']?.toString() ?? '';
      Product? matched;
      try {
        matched = catalog.firstWhere((p) => p.id == pid);
      } catch (_) {
        matched = null;
      }
      return QuickOrderItem.fromJson(map, resolvedProduct: matched);
    }).toList();

    return QuickOrderMode(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Collection',
      iconName: json['icon_name'] ?? 'custom',
      tagline: json['tagline'] ?? 'Custom collection',
      isPredefined: json['is_predefined'] as bool? ?? false,
      items: items,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      targetKeywords: (json['target_keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'tagline': tagline,
      'is_predefined': isPredefined,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'target_keywords': targetKeywords,
    };
  }

  QuickOrderMode copyWith({
    String? id,
    String? name,
    String? iconName,
    String? tagline,
    bool? isPredefined,
    List<QuickOrderItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? targetKeywords,
  }) {
    return QuickOrderMode(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      tagline: tagline ?? this.tagline,
      isPredefined: isPredefined ?? this.isPredefined,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      targetKeywords: targetKeywords ?? this.targetKeywords,
    );
  }
}
