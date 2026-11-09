import '../../profile/models/order_history_item.dart';

class CustomerOrderTracking {
  final String id;
  final String status;
  final DateTime? createdAt;
  final double totalAmount;
  final String? deliveryAddress;
  final String? assignedDeliveryPartnerId;
  final String? assignedDeliveryPartnerName;
  final bool partnerDetailsUnavailable;
  final List<OrderItemSummary> items;

  const CustomerOrderTracking({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.totalAmount,
    required this.deliveryAddress,
    this.assignedDeliveryPartnerId,
    this.assignedDeliveryPartnerName,
    this.partnerDetailsUnavailable = false,
    required this.items,
  });

  bool get isActive => const {
    'placed',
    'preparing',
    'out_for_delivery',
  }.contains(status.toLowerCase());

  bool get isCancelled => status.toLowerCase() == 'cancelled';

  bool get isDelivered => status.toLowerCase() == 'delivered';

  int get progressIndex {
    switch (status.toLowerCase()) {
      case 'placed':
        return 0;
      case 'preparing':
        return 1;
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return -1;
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'Order placed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get heading {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'Your order has been placed';
      case 'preparing':
        return 'Your order is being prepared';
      case 'out_for_delivery':
        return 'Your order is on the way';
      case 'delivered':
        return 'Your order was delivered';
      case 'cancelled':
        return 'Your order was cancelled';
      default:
        return 'Order status: $status';
    }
  }

  String get description {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'We have received your order.';
      case 'preparing':
        return 'The store is preparing your items.';
      case 'out_for_delivery':
        return 'Your order is out for delivery.';
      case 'delivered':
        return 'This order is complete.';
      case 'cancelled':
        return 'This order will not continue to delivery.';
      default:
        return 'Check the latest order status.';
    }
  }

  CustomerOrderTracking copyWith({
    String? status,
    String? assignedDeliveryPartnerName,
    bool? partnerDetailsUnavailable,
  }) => CustomerOrderTracking(
    id: id,
    status: status ?? this.status,
    createdAt: createdAt,
    totalAmount: totalAmount,
    deliveryAddress: deliveryAddress,
    assignedDeliveryPartnerId: assignedDeliveryPartnerId,
    assignedDeliveryPartnerName:
        assignedDeliveryPartnerName ?? this.assignedDeliveryPartnerName,
    partnerDetailsUnavailable:
        partnerDetailsUnavailable ?? this.partnerDetailsUnavailable,
    items: items,
  );

  CustomerOrderTracking withDeliveryPartner({
    required String? name,
    required bool unavailable,
  }) => copyWith(
    assignedDeliveryPartnerName: name,
    partnerDetailsUnavailable: unavailable,
  );

  factory CustomerOrderTracking.fromJson(Map<String, dynamic> json) {
    final rawItems = json['order_items'] as List<dynamic>? ?? const [];
    final items = rawItems.map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      return OrderItemSummary(
        productId: item['product_id']?.toString() ?? '',
        productName: item['product_name']?.toString() ?? 'Product',
        quantity: (item['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
        imageUrl: item['image_url']?.toString(),
      );
    }).toList();

    return CustomerOrderTracking(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      deliveryAddress: _addressFromSnapshot(json['delivery_address_snapshot']),
      assignedDeliveryPartnerId: json['assigned_delivery_partner_id']
          ?.toString(),
      items: items,
    );
  }

  static String? _addressFromSnapshot(dynamic rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final houseNo = address['house_no']?.toString().trim() ?? '';
    final area = address['area']?.toString().trim() ?? '';
    final landmark = address['landmark']?.toString().trim() ?? '';
    final parts = [
      if (houseNo.isNotEmpty) houseNo,
      if (area.isNotEmpty) area,
      if (landmark.isNotEmpty) 'Near $landmark',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}
