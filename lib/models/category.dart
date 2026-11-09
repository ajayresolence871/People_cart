class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final DateTime? createdAt;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.imageUrl,
    this.createdAt,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'is_active': isActive,
    };
  }
}
