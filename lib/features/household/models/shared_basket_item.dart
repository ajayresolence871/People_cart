import '../../../models/product.dart';

class SharedBasketItem {
  final String id;
  final String householdId;
  final String productId;
  final Product product;
  int quantity;
  final String? addedBy;
  final String addedByName;
  final DateTime? createdAt;

  SharedBasketItem({
    required this.id,
    required this.householdId,
    required this.productId,
    required this.product,
    this.quantity = 1,
    this.addedBy,
    this.addedByName = 'Household member',
    this.createdAt,
  });

  double get totalPrice => product.price * quantity;

  factory SharedBasketItem.fromJson(
    Map<String, dynamic> json, {
    Product? product,
  }) {
    Product resolvedProduct;
    if (product != null) {
      resolvedProduct = product;
    } else if (json['products'] is Map) {
      final productJson = Map<String, dynamic>.from(json['products'] as Map);
      resolvedProduct = Product.fromJson(productJson);
    } else {
      resolvedProduct = Product(
        id: json['product_id']?.toString() ?? '',
        name: json['product_name'] ?? 'Grocery Item',
        price: (json['price'] as num?)?.toDouble() ?? 40.0,
      );
    }

    String addedByDisplay = 'Household member';
    if (json['added_by_name'] != null &&
        json['added_by_name'].toString().trim().isNotEmpty) {
      addedByDisplay = json['added_by_name'].toString().trim();
    } else if (json['display_name'] != null &&
        json['display_name'].toString().trim().isNotEmpty) {
      addedByDisplay = json['display_name'].toString().trim();
    } else if (json['profiles'] is Map &&
        json['profiles']['full_name'] != null) {
      final fullName = json['profiles']['full_name'].toString().trim();
      if (fullName.isNotEmpty) addedByDisplay = fullName;
    }

    return SharedBasketItem(
      id: json['id']?.toString() ?? '',
      householdId: json['household_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? resolvedProduct.id,
      product: resolvedProduct,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      addedBy: json['added_by']?.toString(),
      addedByName: addedByDisplay,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'product_id': productId,
      'quantity': quantity,
      'added_by': addedBy,
      'added_by_name': addedByName,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  SharedBasketItem copyWith({
    String? id,
    String? householdId,
    String? productId,
    Product? product,
    int? quantity,
    String? addedBy,
    String? addedByName,
    DateTime? createdAt,
  }) {
    return SharedBasketItem(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedBy: addedBy ?? this.addedBy,
      addedByName: addedByName ?? this.addedByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
