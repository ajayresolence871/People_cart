class HouseholdMember {
  final String householdId;
  final String userId;
  final String memberRole; // 'owner' or 'member'
  final DateTime? joinedAt;
  final String displayName;

  HouseholdMember({
    required this.householdId,
    required this.userId,
    this.memberRole = 'member',
    this.joinedAt,
    this.displayName = 'Member',
  });

  HouseholdMember copyWith({
    String? householdId,
    String? userId,
    String? memberRole,
    DateTime? joinedAt,
    String? displayName,
  }) {
    return HouseholdMember(
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      memberRole: memberRole ?? this.memberRole,
      joinedAt: joinedAt ?? this.joinedAt,
      displayName: displayName ?? this.displayName,
    );
  }

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      householdId: json['household_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      memberRole: json['member_role'] ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
      displayName: json['display_name'] ??
          (json['profiles'] != null && json['profiles']['full_name'] != null
              ? json['profiles']['full_name']
              : 'Member'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'household_id': householdId,
      'user_id': userId,
      'member_role': memberRole,
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  bool get isOwner => memberRole.toLowerCase() == 'owner';
}

class Household {
  final String id;
  final String name;
  final String joinCode;
  final String createdBy;
  final DateTime? createdAt;
  final List<HouseholdMember> members;

  Household({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    this.createdAt,
    this.members = const [],
  });

  int get memberCount => members.isNotEmpty ? members.length : 1;

  factory Household.fromJson(Map<String, dynamic> json, {List<HouseholdMember> members = const []}) {
    return Household(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'My Household',
      joinCode: json['join_code'] ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      members: members,
    );
  }

  Household copyWith({
    String? id,
    String? name,
    String? joinCode,
    String? createdBy,
    DateTime? createdAt,
    List<HouseholdMember>? members,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      joinCode: joinCode ?? this.joinCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'join_code': joinCode,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
