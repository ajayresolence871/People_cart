import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/product.dart';
import '../models/household.dart';
import '../models/shared_basket_item.dart';

@visibleForTesting
Map<String, dynamic> buildSharedBasketInsertPayload({
  required Object householdId,
  required String productId,
  required int quantity,
  required String authenticatedUserId,
}) => {
  'household_id': householdId,
  'product_id': productId,
  'quantity': quantity,
  'added_by': authenticatedUserId,
};

@visibleForTesting
List<SharedBasketItem> mapSharedBasketRowsWithContributorNames(
  Iterable<Map<String, dynamic>> rows,
  Map<String, String> contributorNames,
) {
  return rows.map((row) {
    final map = Map<String, dynamic>.from(row);
    final contributorId = map['added_by']?.toString();
    final nameFromMap = contributorId == null
        ? null
        : contributorNames[contributorId];
    if (nameFromMap != null && nameFromMap.trim().isNotEmpty) {
      map['added_by_name'] = nameFromMap.trim();
    } else if (map['display_name'] != null &&
        map['display_name'].toString().trim().isNotEmpty) {
      map['added_by_name'] = map['display_name'].toString().trim();
    }
    return SharedBasketItem.fromJson(map);
  }).toList();
}

@visibleForTesting
Future<Map<String, String>> resolveHouseholdMemberNames(
  SupabaseClient client,
  String householdId, {
  List<String>? userIds,
}) async {
  final parsedHouseholdId = int.tryParse(householdId) ?? householdId;
  final targetUserIds = (userIds ?? const <String>[])
      .where((id) => id.trim().isNotEmpty)
      .toSet()
      .toList();
  final Map<String, String> nameMap = {};

  try {
    final memberRows = await client.rpc(
      'household_member_names',
      params: {'p_household_id': householdId},
    );
    if (memberRows is List) {
      for (final row in memberRows) {
        if (row is! Map) continue;
        final id = row['user_id']?.toString();
        final fullName = row['full_name']?.toString();
        if (id != null &&
            (targetUserIds.isEmpty || targetUserIds.contains(id)) &&
            fullName != null &&
            fullName.trim().isNotEmpty) {
          nameMap[id] = fullName.trim();
        }
      }
    }
  } catch (error) {
    debugPrint('HouseholdService member names RPC notice: $error');

    // Keep a profile-table fallback for deployments where household members
    // are already readable and the scoped RPC has not yet been installed.
    try {
      final memberRows = await client
          .from('household_members')
          .select('user_id')
          .eq('household_id', parsedHouseholdId);
      final householdMemberIds = (memberRows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final lookupIds = targetUserIds.isEmpty
          ? householdMemberIds.toList()
          : householdMemberIds
                .where((id) => targetUserIds.contains(id))
                .toList();
      if (lookupIds.isNotEmpty) {
        final profileRows = await client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', lookupIds);
        for (final row in (profileRows as List<dynamic>)) {
          final map = row as Map<String, dynamic>;
          final id = map['id']?.toString();
          final fullName = map['full_name']?.toString();
          if (id != null && fullName != null && fullName.trim().isNotEmpty) {
            nameMap[id] = fullName.trim();
          }
        }
      }
    } catch (error) {
      debugPrint('HouseholdService profile name fallback notice: $error');
    }
  }

  return nameMap;
}

class HouseholdService {
  final SupabaseClient? _explicitClient;
  static const String _guestUserKey = 'pc_household_guest_uid';

  HouseholdService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Obtains the current active user ID (either Supabase Auth user or a persistent guest ID)
  Future<String> getCurrentUserId() async {
    final client = _client;
    if (client != null && client.auth.currentUser != null) {
      return client.auth.currentUser!.id;
    }

    // Fallback persistent guest user ID for bootcamp/demo testing
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString(_guestUserKey);
    if (guestId == null) {
      guestId =
          'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await prefs.setString(_guestUserKey, guestId);
    }
    return guestId;
  }

  /// Requires the real signed-in identity for shared basket writes.
  String requireAuthenticatedUserId() {
    final userId = _client?.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in to add items to a shared household basket.');
    }
    return userId;
  }

  /// Retrieves the current user's display name from the profiles table.
  Future<String?> getCurrentUserDisplayName() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return null;
    final userId = client.auth.currentUser!.id;

    try {
      final profile = await client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null && profile['full_name'] != null) {
        final name = profile['full_name'].toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (error) {
      debugPrint('HouseholdService profile name lookup notice: $error');
    }

    return null;
  }

  /// Generates a clean, unique join code (e.g. PC-8K2N)
  String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final code = List.generate(
      4,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'PC-$code';
  }

  /// Fetches the household for the current user
  Future<Household?> getCurrentUserHousehold() async {
    final client = _client;
    if (client == null) return null;

    try {
      final userId = await getCurrentUserId();
      if (userId.startsWith('guest_')) return null;

      // A user may belong to more than one household. This screen currently
      // displays one household, so load the most recently joined membership.
      final memberResponse = await client
          .from('household_members')
          .select('household_id, user_id, member_role, joined_at')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (memberResponse == null) return null;

      final dynamic rawHouseholdId = memberResponse['household_id'];
      if (rawHouseholdId == null) return null;

      final householdIdStr = rawHouseholdId.toString();
      final parsedHouseholdId = int.tryParse(householdIdStr) ?? rawHouseholdId;

      // 2. Fetch household details
      final householdResponse = await client
          .from('households')
          .select()
          .eq('id', parsedHouseholdId)
          .maybeSingle();

      if (householdResponse == null) return null;

      // 3. Fetch all members of this household
      final membersResponse = await client
          .from('household_members')
          .select()
          .eq('household_id', parsedHouseholdId);

      final List<dynamic> memberList =
          (membersResponse as List<dynamic>?) ?? [];
      final members = memberList.map((m) {
        final map = m as Map<String, dynamic>;
        final memberUserId = map['user_id']?.toString() ?? '';
        final isSelf = memberUserId == userId;
        final role = map['member_role']?.toString().toLowerCase() == 'owner'
            ? 'Owner'
            : 'Member';
        final defaultDisplayName = isSelf ? 'You ($role)' : role;
        return HouseholdMember.fromJson(map)
            .copyWith(displayName: map['display_name'] ?? defaultDisplayName);
      }).toList();

      return Household.fromJson(householdResponse, members: members);
    } catch (e) {
      debugPrint('HouseholdService.getCurrentUserHousehold error: $e');
      rethrow;
    }
  }

  /// Fetches all items in the shared basket for a household with resolved contributor display names
  Future<List<SharedBasketItem>> getSharedBasketItems(
    String householdId,
  ) async {
    final client = _client;
    if (client == null) {
      throw StateError('The shared household basket is not available.');
    }

    try {
      final parsedHouseholdId = int.tryParse(householdId) ?? householdId;
      final response = await client
          .from('shared_basket_items')
          .select('*, products(*)')
          .eq('household_id', parsedHouseholdId)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      // Extract unique user IDs that contributed items and always include the
      // active user so their real profile name resolves instead of the fallback
      // text.
      final currentUserId = await getCurrentUserId();
      final userIds = data
          .map((item) => item['added_by']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty && !id.startsWith('guest_'))
          .toSet()
          .toList();
      if (currentUserId.isNotEmpty && !currentUserId.startsWith('guest_')) {
        userIds.add(currentUserId);
      }

      final nameMap = userIds.isEmpty
          ? <String, String>{}
          : await resolveHouseholdMemberNames(
              client,
              householdId,
              userIds: userIds,
            );

      final currentUserName = await getCurrentUserDisplayName();
      if (currentUserName != null && currentUserName.trim().isNotEmpty) {
        nameMap[currentUserId] = currentUserName.trim();
      }

      return mapSharedBasketRowsWithContributorNames(
        data.map((row) => Map<String, dynamic>.from(row as Map)),
        nameMap,
      );
    } catch (e) {
      debugPrint('HouseholdService.getSharedBasketItems notice: $e');
      rethrow;
    }
  }

  /// Creates a new household in Supabase and relies on the DB trigger for membership
  Future<Household> createHousehold(String name) async {
    final client = _client;
    final userId = await getCurrentUserId();
    final joinCode = generateJoinCode();

    if (client == null) {
      // Offline fallback for unit tests where Supabase is not initialized
      return Household(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        joinCode: joinCode,
        createdBy: userId,
        members: [
          HouseholdMember(
            householdId: 'local',
            userId: userId,
            memberRole: 'owner',
            displayName: 'You (Owner)',
          ),
        ],
      );
    }

    if (userId.startsWith('guest_')) {
      throw Exception('Please sign in to create a household.');
    }

    try {
      // 1. Insert into households table.
      // We intentionally do not use .select() here so PostgREST issues return=minimal.
      // This prevents an RLS 42501 race condition where the SELECT policy checks for
      // membership in household_members before the database AFTER INSERT trigger fires.
      await client.from('households').insert({
        'name': name.trim(),
        'join_code': joinCode,
        'created_by': userId,
      });

      // 2. Fetch the newly inserted household row using the unique join_code
      final householdResponse = await client
          .from('households')
          .select()
          .eq('join_code', joinCode)
          .maybeSingle();

      if (householdResponse == null) {
        throw Exception(
          'Household was created but could not be retrieved from database.',
        );
      }

      final dynamic rawId = householdResponse['id'];
      final householdId = rawId.toString();
      final parsedId = int.tryParse(householdId) ?? rawId;

      // 3. Fetch members. The DB trigger automatically added the creator as 'owner'.
      final membersResponse = await client
          .from('household_members')
          .select()
          .eq('household_id', parsedId);

      final List<dynamic> memberList =
          (membersResponse as List<dynamic>?) ?? [];
      List<HouseholdMember> members = memberList.map((m) {
        final map = m as Map<String, dynamic>;
        final memberUserId = map['user_id']?.toString() ?? '';
        final isSelf = memberUserId == userId;
        final role = map['member_role']?.toString().toLowerCase() == 'owner'
            ? 'Owner'
            : 'Member';
        final defaultDisplayName = isSelf ? 'You ($role)' : role;
        return HouseholdMember.fromJson(map)
            .copyWith(displayName: map['display_name'] ?? defaultDisplayName);
      }).toList();

      if (members.isEmpty) {
        members = [
          HouseholdMember(
            householdId: householdId,
            userId: userId,
            memberRole: 'owner',
            displayName: 'You (Owner)',
          ),
        ];
      }

      return Household.fromJson(householdResponse, members: members);
    } catch (e) {
      debugPrint('HouseholdService.createHousehold error: $e');
      rethrow;
    }
  }

  /// Joins an existing household using a join code
  Future<Household> joinHouseholdByCode(String code) async {
    final client = _client;
    final cleanCode = code.trim().toUpperCase();
    final userId = await getCurrentUserId();

    if (client == null) {
      throw Exception('Database client not available');
    }

    if (userId.startsWith('guest_')) {
      throw Exception('Please sign in to join a household.');
    }

    try {
      // 1. Find household with matching join_code
      final householdResponse = await client
          .from('households')
          .select()
          .eq('join_code', cleanCode)
          .maybeSingle();

      if (householdResponse == null) {
        throw Exception(
          'Invalid join code "$cleanCode". Please verify with your family member.',
        );
      }

      final dynamic rawId = householdResponse['id'];
      final householdId = rawId.toString();
      final parsedId = int.tryParse(householdId) ?? rawId;

      // 2. Check if already a member
      final existingMember = await client
          .from('household_members')
          .select()
          .eq('household_id', parsedId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingMember == null) {
        // 3. Insert into household_members
        await client.from('household_members').insert({
          'household_id': parsedId,
          'user_id': userId,
          'member_role': 'member',
        });
      }

      // 4. Fetch all members
      final membersResponse = await client
          .from('household_members')
          .select()
          .eq('household_id', parsedId);

      final List<dynamic> memberList =
          (membersResponse as List<dynamic>?) ?? [];
      final members = memberList.map((m) {
        final map = m as Map<String, dynamic>;
        final memberUserId = map['user_id']?.toString() ?? '';
        final isSelf = memberUserId == userId;
        final role = map['member_role']?.toString().toLowerCase() == 'owner'
            ? 'Owner'
            : 'Member';
        final defaultDisplayName = isSelf ? 'You ($role)' : role;
        return HouseholdMember.fromJson(map)
            .copyWith(displayName: map['display_name'] ?? defaultDisplayName);
      }).toList();

      return Household.fromJson(householdResponse, members: members);
    } catch (e) {
      debugPrint('HouseholdService.joinHouseholdByCode error: $e');
      rethrow;
    }
  }

  /// Adds a product to the shared household basket, updating quantity if it already exists
  Future<void> addItemToSharedBasket(
    String householdId,
    Product product, {
    int quantity = 1,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('The shared household basket is not available.');
    }
    final userId = requireAuthenticatedUserId();

    try {
      final parsedHouseholdId = int.tryParse(householdId) ?? householdId;

      // 1. Check if product already exists in this household's basket
      final existingItem = await client
          .from('shared_basket_items')
          .select()
          .eq('household_id', parsedHouseholdId)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existingItem != null) {
        // Update quantity
        final currentQty = (existingItem['quantity'] as num).toInt();
        await client
            .from('shared_basket_items')
            .update({'quantity': currentQty + quantity})
            .eq('id', existingItem['id']);
      } else {
        // Insert new item
        await client
            .from('shared_basket_items')
            .insert(
              buildSharedBasketInsertPayload(
                householdId: parsedHouseholdId,
                productId: product.id,
                quantity: quantity,
                authenticatedUserId: userId,
              ),
            );
      }
    } catch (e) {
      debugPrint('HouseholdService.addItemToSharedBasket error: $e');
      rethrow;
    }
  }

  /// Updates quantity of an item in the shared basket
  Future<void> updateItemQuantity(String itemId, int newQuantity) async {
    final client = _client;
    if (client == null) {
      throw StateError('The shared household basket is not available.');
    }

    try {
      if (newQuantity <= 0) {
        await client.from('shared_basket_items').delete().eq('id', itemId);
      } else {
        await client
            .from('shared_basket_items')
            .update({'quantity': newQuantity})
            .eq('id', itemId);
      }
    } catch (e) {
      debugPrint('HouseholdService.updateItemQuantity error: $e');
      rethrow;
    }
  }

  /// Removes an item completely from the shared basket
  Future<void> removeItemFromSharedBasket(String itemId) async {
    final client = _client;
    if (client == null) {
      throw StateError('The shared household basket is not available.');
    }

    try {
      await client.from('shared_basket_items').delete().eq('id', itemId);
    } catch (e) {
      debugPrint('HouseholdService.removeItemFromSharedBasket error: $e');
      rethrow;
    }
  }

  Future<void> removeItemsFromSharedBasket(Iterable<String> itemIds) async {
    final client = _client;
    if (client == null) {
      throw StateError('The shared household basket is not available.');
    }

    final ids = itemIds.where((id) => id.isNotEmpty).toSet();
    try {
      for (final id in ids) {
        await client.from('shared_basket_items').delete().eq('id', id);
      }
    } catch (error) {
      debugPrint('HouseholdService.removeItemsFromSharedBasket error: $error');
      rethrow;
    }
  }
}
