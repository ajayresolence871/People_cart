class AddressModel {
  final String id;
  final String tag; // 'Home', 'Work', 'Other'
  final String houseNo;
  final String area;
  final String landmark;
  final String recipientName;
  final String phoneNumber;
  final int deliveryTimeMinutes;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.tag,
    required this.houseNo,
    required this.area,
    this.landmark = '',
    required this.recipientName,
    required this.phoneNumber,
    this.deliveryTimeMinutes = 7,
    this.isDefault = false,
  });

  String get fullAddress {
    final parts = [houseNo, area, if (landmark.isNotEmpty) 'Near $landmark'];
    return parts.where((p) => p.isNotEmpty).join(', ');
  }

  String get shortDisplay {
    return '$tag — $houseNo, $area';
  }

  bool get isValidForDelivery =>
      id.trim().isNotEmpty &&
      houseNo.trim().isNotEmpty &&
      area.trim().isNotEmpty &&
      recipientName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty;

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? '',
      tag: json['tag'] ?? 'Home',
      houseNo: json['house_no'] ?? '',
      area: json['area'] ?? '',
      landmark: json['landmark'] ?? '',
      recipientName: json['recipient_name'] ?? 'User',
      phoneNumber: json['phone_number'] ?? '',
      deliveryTimeMinutes:
          (json['delivery_time_minutes'] as num?)?.toInt() ?? 7,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag': tag,
      'house_no': houseNo,
      'area': area,
      'landmark': landmark,
      'recipient_name': recipientName,
      'phone_number': phoneNumber,
      'delivery_time_minutes': deliveryTimeMinutes,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? tag,
    String? houseNo,
    String? area,
    String? landmark,
    String? recipientName,
    String? phoneNumber,
    int? deliveryTimeMinutes,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      houseNo: houseNo ?? this.houseNo,
      area: area ?? this.area,
      landmark: landmark ?? this.landmark,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      deliveryTimeMinutes: deliveryTimeMinutes ?? this.deliveryTimeMinutes,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
