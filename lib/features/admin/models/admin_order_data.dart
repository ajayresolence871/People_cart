class AdminOrderStatus {
  static const all = <String>[
    'placed',
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  static List<String> nextFor(String status) => switch (status) {
    'placed' => const ['preparing', 'cancelled'],
    'preparing' => const ['cancelled'],
    _ => const [],
  };

  static String label(String status) => switch (status) {
    'placed' => 'Placed',
    'preparing' => 'Preparing',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

class AdminManagedOrder {
  final String id;
  final DateTime? createdAt;
  final double? totalAmount;
  final String status;
  final String? customerName;
  final String? paymentMethod;
  final String? paymentStatus;
  final List<AdminOrderLine> items;

  const AdminManagedOrder({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    required this.customerName,
    this.paymentMethod,
    this.paymentStatus,
    this.items = const [],
  });

  factory AdminManagedOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const FormatException('Unexpected order item details.');
    }

    return AdminManagedOrder(
      id: json['order_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'unknown',
      customerName: json['customer_name']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      items: (rawItems as List<dynamic>? ?? const []).map((item) {
        if (item is! Map) {
          throw const FormatException('Unexpected order item row.');
        }
        return AdminOrderLine.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
    );
  }
}

class AdminOrderLine {
  final String? productId;
  final String productName;
  final int quantity;
  final double? unitPrice;

  final String? imageUrl;

  const AdminOrderLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  double? get lineTotal => unitPrice == null ? null : unitPrice! * quantity;

  AdminOrderLine withImageUrl(String? value) => AdminOrderLine(
    productId: productId,
    productName: productName,
    quantity: quantity,
    unitPrice: unitPrice,
    imageUrl: value,
  );

  factory AdminOrderLine.fromJson(Map<String, dynamic> json) {
    return AdminOrderLine(
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString().trim().isNotEmpty == true
          ? json['product_name'].toString()
          : 'Product unavailable',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      imageUrl: json['image_url']?.toString(),
    );
  }
}
