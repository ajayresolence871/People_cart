class DeliveryPartner {
  final String id;
  final String? name;

  const DeliveryPartner({required this.id, this.name});

  String get displayName {
    final trimmedName = name?.trim();
    return trimmedName == null || trimmedName.isEmpty
        ? 'Partner ${id.substring(0, id.length < 8 ? id.length : 8)}'
        : trimmedName;
  }
}

class DeliveryManagedOrder {
  final String id;
  final DateTime? createdAt;
  final double? totalAmount;
  final String status;
  final String? assignedPartnerId;
  final String? assignedPartnerName;
  final String? customerName;
  final String? customerPhone;
  final String? paymentMethod;
  final String? paymentStatus;
  final int itemCount;
  final List<DeliveryOrderLine> items;
  final String? deliveryAddress;
  final String? navigationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const DeliveryManagedOrder({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    required this.assignedPartnerId,
    this.assignedPartnerName,
    this.customerName,
    this.customerPhone,
    this.paymentMethod,
    this.paymentStatus,
    this.itemCount = 0,
    this.items = const [],
    this.deliveryAddress,
    this.navigationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  bool get isActive =>
      status == 'placed' ||
      status == 'preparing' ||
      status == 'out_for_delivery';
  bool get isOutForDelivery => status == 'out_for_delivery';
  bool get isAssignmentLocked =>
      status == 'out_for_delivery' ||
      status == 'delivered' ||
      status == 'cancelled';

  DeliveryManagedOrder copyWith({
    String? status,
    String? paymentMethod,
    String? paymentStatus,
  String? assignedPartnerId,
  String? assignedPartnerName,
  String? customerName,
  String? customerPhone,
  }) => DeliveryManagedOrder(
    id: id,
    createdAt: createdAt,
    totalAmount: totalAmount,
    status: status ?? this.status,
    assignedPartnerId: assignedPartnerId ?? this.assignedPartnerId,
    assignedPartnerName: assignedPartnerName ?? this.assignedPartnerName,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    itemCount: itemCount,
    items: items,
    deliveryAddress: deliveryAddress,
    navigationAddress: navigationAddress,
    destinationLatitude: destinationLatitude,
    destinationLongitude: destinationLongitude,
  );

  factory DeliveryManagedOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const FormatException('Unexpected assigned order items.');
    }
    final items = (rawItems as List<dynamic>? ?? const [])
        .map((rawItem) {
          if (rawItem is! Map) {
            throw const FormatException('Unexpected assigned order item row.');
          }
          return DeliveryOrderLine.fromJson(Map<String, dynamic>.from(rawItem));
        })
        .toList(growable: false);
    final returnedItemCount = (json['item_count'] as num?)?.toInt();

    final addressSnapshot = json['delivery_address_snapshot'];
    final coordinates = coordinatesFromSnapshot(addressSnapshot);
    final savedAddress =
        addressFromSnapshot(addressSnapshot) ??
        _nonEmptyString(json['delivery_address']);
    final customerName = json['customer_name']?.toString() ?? (addressSnapshot is Map ? addressSnapshot['name']?.toString() : null);
    final customerPhone = json['customer_phone']?.toString() ?? (addressSnapshot is Map ? addressSnapshot['phone']?.toString() : null);
    return DeliveryManagedOrder(
      id: json['order_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'unknown',
      assignedPartnerId: json['assigned_delivery_partner_id']?.toString(),
      assignedPartnerName: json['assigned_partner_name']?.toString(),
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMethod: json['payment_method']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      itemCount:
          returnedItemCount ??
          items.fold<int>(0, (total, item) => total + item.quantity),
      items: items,
      deliveryAddress: savedAddress,
      navigationAddress:
          navigationAddressFromSnapshot(addressSnapshot) ??
          _nonEmptyString(json['delivery_address']) ??
          savedAddress,
      destinationLatitude: coordinates?.$1,
      destinationLongitude: coordinates?.$2,
    );
  }

  static String? addressFromSnapshot(dynamic rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final tag = address['tag']?.toString().trim() ?? '';
    final houseNo = address['house_no']?.toString().trim() ?? '';
    final area = address['area']?.toString().trim() ?? '';
    final landmark = address['landmark']?.toString().trim() ?? '';
    final parts = [
      if (houseNo.isNotEmpty) houseNo,
      if (area.isNotEmpty) area,
      if (landmark.isNotEmpty) 'Near $landmark',
    ];
    if (parts.isEmpty) return null;
    return '${tag.isEmpty ? '' : '$tag · '}${parts.join(', ')}';
  }

  static (double, double)? coordinatesFromSnapshot(dynamic rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final latitude = _coordinate(address['latitude']);
    final longitude = _coordinate(address['longitude']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude, longitude);
  }

  static double? _coordinate(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static String? navigationAddressFromSnapshot(dynamic rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final houseNo = address['house_no']?.toString().trim() ?? '';
    final area = address['area']?.toString().trim() ?? '';
    final landmark = address['landmark']?.toString().trim() ?? '';
    final parts = [
      if (houseNo.isNotEmpty) houseNo,
      if (area.isNotEmpty) area,
      if (landmark.isNotEmpty) landmark,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? _nonEmptyString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class DeliveryOrderLine {
  final String? productId;
  final String productName;
  final int quantity;
  final double? unitPrice;
  final String? imageUrl;

  const DeliveryOrderLine({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  double? get lineTotal => unitPrice == null ? null : unitPrice! * quantity;

  DeliveryOrderLine withImageUrl(String? value) => DeliveryOrderLine(
    productId: productId,
    productName: productName,
    quantity: quantity,
    unitPrice: unitPrice,
    imageUrl: value,
  );

  factory DeliveryOrderLine.fromJson(Map<String, dynamic> json) {
    final rawName = json['product_name']?.toString().trim();
    return DeliveryOrderLine(
      productId: json['product_id']?.toString(),
      productName: rawName == null || rawName.isEmpty
          ? 'Product unavailable'
          : rawName,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      imageUrl: json['image_url']?.toString(),
    );
  }
}
