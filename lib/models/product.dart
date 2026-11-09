class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? categoryId;
  final int stockQuantity;
  final bool isAvailable;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.categoryId,
    this.stockQuantity = 50,
    this.isAvailable = true,
    this.createdAt,
  });

  bool get isInStock => isAvailable && stockQuantity > 0;
  bool get isOutOfStock => !isInStock;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
      categoryId: json['category_id']?.toString(),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category_id': categoryId,
      'stock_quantity': stockQuantity,
      'is_available': isAvailable,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? categoryId,
    int? stockQuantity,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper for original MRP display seen in Zepto UI (strikethrough price)
  double get originalPrice => (price * 1.25).ceilToDouble();

  // Helper for discount amount
  double get discountAmount => (originalPrice - price).clamp(0, double.infinity);

  // Helper for discount percentage
  int get discountPercentage => originalPrice > price
      ? (((originalPrice - price) / originalPrice) * 100).round()
      : 0;
}
