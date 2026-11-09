import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wishlist_entry.dart';

abstract class WishlistDataSource {
  Future<List<WishlistEntry>> loadEntries({required String expectedUserId});
  Future<void> addProduct(String productId, {required String expectedUserId});
  Future<void> removeProduct(
    String productId, {
    required String expectedUserId,
  });
}

class WishlistService implements WishlistDataSource {
  final SupabaseClient? _explicitClient;

  WishlistService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase is not initialized.');
    }
  }

  String _verifiedUserId(String expectedUserId) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId != expectedUserId) {
      throw StateError('Sign in to manage your wishlist.');
    }
    return userId;
  }

  @override
  Future<List<WishlistEntry>> loadEntries({
    required String expectedUserId,
  }) async {
    final userId = _verifiedUserId(expectedUserId);
    final rows = await _client
        .from('customer_wishlist')
        .select('product_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) => WishlistEntry.fromJson(row)).toList();
  }

  @override
  Future<void> addProduct(
    String productId, {
    required String expectedUserId,
  }) async {
    if (productId.isEmpty) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Product ID is required.',
      );
    }
    final userId = _verifiedUserId(expectedUserId);
    try {
      await _client.from('customer_wishlist').insert({
        'user_id': userId,
        'product_id': productId,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
      rethrow;
    }
  }

  @override
  Future<void> removeProduct(
    String productId, {
    required String expectedUserId,
  }) async {
    final userId = _verifiedUserId(expectedUserId);
    await _client
        .from('customer_wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }
}
