class UserProfile {
  final String id;
  final String? fullName;
  final String role;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.fullName,
    this.role = 'customer',
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] as String?,
      role: json['role']?.toString().trim().toLowerCase() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
