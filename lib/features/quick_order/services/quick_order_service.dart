import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/product.dart';
import '../models/quick_order_mode.dart';

class QuickOrderService {
  static const String _storageKey = 'pc_custom_quick_order_modes';
  static const String _guestUserKey = 'pc_household_guest_uid';

  final SupabaseClient? _explicitClient;

  QuickOrderService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Obtains current active user ID (Supabase Auth user or persistent guest ID)
  Future<String> getCurrentUserId() async {
    final client = _client;
    if (client != null && client.auth.currentUser != null) {
      return client.auth.currentUser!.id;
    }

    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString(_guestUserKey);
    if (guestId == null) {
      guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_guestUserKey, guestId);
    }
    return guestId;
  }

  /// Loads custom quick order modes from persistent storage (and Supabase if online)
  Future<List<QuickOrderMode>> loadCustomModes(List<Product> catalog, {String? userId}) async {
    List<QuickOrderMode> modes = [];
    final activeUserId = userId ?? _client?.auth.currentUser?.id;
    final activeKey = activeUserId != null ? '${_storageKey}_$activeUserId' : _storageKey;

    // 1. Load from local SharedPreferences (guaranteed persistent across restarts)
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(activeKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        modes = decoded
            .map((item) => QuickOrderMode.fromJson(item as Map<String, dynamic>, catalog: catalog))
            .toList();
      }
    } catch (e) {
      debugPrint('QuickOrderService.loadCustomModes local read error: $e');
    }

    // 2. Attempt Supabase fetch if client is available
    final client = _client;
    if (client != null && activeUserId != null) {
      try {
        final response = await client
            .from('quick_order_modes')
            .select('*, quick_order_mode_items(*)')
            .eq('user_id', activeUserId)
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          final remoteModes = response.map((row) {
            final rawItems = row['quick_order_mode_items'] as List<dynamic>? ?? [];
            final items = rawItems.map((itemRow) {
              final pid = itemRow['product_id']?.toString() ?? '';
              Product? matched;
              try {
                matched = catalog.firstWhere((p) => p.id == pid);
              } catch (_) {
                matched = null;
              }
              return QuickOrderItem(
                productId: pid,
                quantity: (itemRow['quantity'] as num?)?.toInt() ?? 1,
                product: matched,
              );
            }).toList();

            return QuickOrderMode(
              id: row['id']?.toString() ?? '',
              name: row['name'] ?? 'Collection',
              iconName: row['icon_name'] ?? 'custom',
              tagline: row['tagline'] ?? 'Custom collection',
              isPredefined: false,
              items: items,
              createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at']) : null,
              updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at']) : null,
            );
          }).toList();

          if (remoteModes.isNotEmpty) {
            modes = remoteModes;
            await _saveToLocal(modes, userId: activeUserId);
          }
        }
      } catch (e) {
        debugPrint('QuickOrderService.loadCustomModes remote fetch notice (using local storage): $e');
      }
    }

    return modes;
  }

  /// Saves or updates a custom mode
  Future<void> saveCustomMode(QuickOrderMode mode, List<QuickOrderMode> currentModes, {String? userId}) async {
    final activeUserId = userId ?? _client?.auth.currentUser?.id;
    // Update local list
    final updatedList = List<QuickOrderMode>.from(currentModes);
    final index = updatedList.indexWhere((m) => m.id == mode.id);
    if (index >= 0) {
      updatedList[index] = mode;
    } else {
      updatedList.insert(0, mode);
    }

    await _saveToLocal(updatedList, userId: activeUserId);

    // Sync to Supabase if available
    final client = _client;
    if (client != null && activeUserId != null) {
      try {
        // Upsert mode
        await client.from('quick_order_modes').upsert({
          'id': mode.id,
          'user_id': activeUserId,
          'name': mode.name,
          'icon_name': mode.iconName,
          'tagline': mode.tagline,
          'is_predefined': false,
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Delete old items and insert updated items
        await client.from('quick_order_mode_items').delete().eq('mode_id', mode.id);

        if (mode.items.isNotEmpty) {
          final itemsToInsert = mode.items.map((i) {
            return {
              'id': '${mode.id}_${i.productId}',
              'mode_id': mode.id,
              'product_id': i.productId,
              'quantity': i.quantity,
            };
          }).toList();

          await client.from('quick_order_mode_items').insert(itemsToInsert);
        }
      } catch (e) {
        debugPrint('QuickOrderService.saveCustomMode Supabase sync notice: $e');
      }
    }
  }

  /// Deletes a custom mode
  Future<void> deleteCustomMode(String modeId, List<QuickOrderMode> currentModes, {String? userId}) async {
    final activeUserId = userId ?? _client?.auth.currentUser?.id;
    final updatedList = List<QuickOrderMode>.from(currentModes)..removeWhere((m) => m.id == modeId);
    await _saveToLocal(updatedList, userId: activeUserId);

    final client = _client;
    if (client != null) {
      try {
        await client.from('quick_order_modes').delete().eq('id', modeId);
      } catch (e) {
        debugPrint('QuickOrderService.deleteCustomMode Supabase delete notice: $e');
      }
    }
  }

  Future<void> _saveToLocal(List<QuickOrderMode> modes, {String? userId}) async {
    try {
      final activeUserId = userId ?? _client?.auth.currentUser?.id;
      final activeKey = activeUserId != null ? '${_storageKey}_$activeUserId' : _storageKey;
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(modes.map((m) => m.toJson()).toList());
      await prefs.setString(activeKey, encoded);
    } catch (e) {
      debugPrint('QuickOrderService._saveToLocal error: $e');
    }
  }
}
