import '../../../models/product.dart';

class OrderItemSummary {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;

  OrderItemSummary({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  double get totalPrice => unitPrice * quantity;

  OrderItemSummary withImageUrl(String? value) => OrderItemSummary(
    productId: productId,
    productName: productName,
    quantity: quantity,
    unitPrice: unitPrice,
    imageUrl: value,
  );

  static List<OrderItemSummary> withCatalogImages(
    Iterable<OrderItemSummary> items,
    Iterable<Product> products,
  ) {
    final imageUrls = {
      for (final product in products)
        if (product.imageUrl?.trim().isNotEmpty == true)
          product.id: product.imageUrl!,
    };
    return items
        .map(
          (item) => item.withImageUrl(
            item.imageUrl?.trim().isNotEmpty == true
                ? item.imageUrl
                : imageUrls[item.productId],
          ),
        )
        .toList();
  }

  factory OrderItemSummary.fromJson(Map<String, dynamic> json) {
    return OrderItemSummary(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name'] ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'image_url': imageUrl,
    };
  }

  Product toProduct() {
    return Product(
      id: productId,
      name: productName,
      price: unitPrice,
      imageUrl: imageUrl,
    );
  }
}

class OrderHistoryItem {
  final String orderId;
  final String status; // 'Delivered', 'Out for Delivery', 'Order Placed'
  final DateTime createdAt;
  final double totalAmount;
  final String? paymentMethod;
  final String? deliveryAddress;
  final List<OrderItemSummary> items;

  OrderHistoryItem({
    required this.orderId,
    this.status = 'Unknown status',
    required this.createdAt,
    required this.totalAmount,
    this.paymentMethod,
    this.deliveryAddress,
    required this.items,
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  OrderHistoryItem copyWith({String? status}) => OrderHistoryItem(
    orderId: orderId,
    status: status ?? this.status,
    createdAt: createdAt,
    totalAmount: totalAmount,
    paymentMethod: paymentMethod,
    deliveryAddress: deliveryAddress,
    items: items,
  );

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((i) => OrderItemSummary.fromJson(i as Map<String, dynamic>))
        .toList();

    return OrderHistoryItem(
      orderId: json['order_id'] ?? '',
      status: json['status'] ?? 'Unknown status',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString(),
      deliveryAddress: json['delivery_address']?.toString(),
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'delivery_address': deliveryAddress,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
