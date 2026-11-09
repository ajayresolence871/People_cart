class WishlistEntry {
  final String productId;
  final DateTime? createdAt;

  const WishlistEntry({required this.productId, this.createdAt});

  factory WishlistEntry.fromJson(Map<String, dynamic> json) {
    return WishlistEntry(
      productId: json['product_id']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
