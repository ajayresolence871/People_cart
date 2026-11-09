import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/product.dart';

abstract class ProductCatalogDataSource {
  Future<List<Category>> getCategories();
  Future<List<Product>> getProducts({String? categoryId});

  Future<List<Product>> getProductsByIds(Iterable<String> productIds) async =>
      const [];
}

class ProductService implements ProductCatalogDataSource {
  final SupabaseClient? _explicitClient;

  ProductService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetches all categories ordered by name or creation
  @override
  Future<List<Category>> getCategories() async {
    final client = _client;
    if (client == null) {
      // In test environment or offline without Supabase initialized
      return [];
    }

    try {
      final response = await client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Category.fromJson(json)).toList();
    } on PostgrestException catch (error) {
      if (error.code != '42703' || !error.message.contains('is_active')) {
        debugPrint('ProductService.getCategories error: $error');
        rethrow;
      }

      // Older deployments have no category status column, so all stored
      // categories are treated as active until the category migration lands.
      final response = await client
          .from('categories')
          .select()
          .order('name', ascending: true);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Category.fromJson(json)).toList();
    } catch (error) {
      debugPrint('ProductService.getCategories error: $error');
      rethrow;
    }
  }

  /// Fetches products, optionally filtered by category
  @override
  Future<List<Product>> getProducts({String? categoryId}) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    try {
      var query = client
          .from('products')
          .select(
            'id, name, description, price, image_url, category_id, stock_quantity, is_available, created_at',
          );

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.order('name', ascending: true);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ProductService.getProducts error: $e');
      rethrow;
    }
  }

  /// Fetches current catalog data for a set of product IDs.
  @override
  Future<List<Product>> getProductsByIds(Iterable<String> productIds) async {
    final ids = productIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return [];

    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('products')
          .select(
            'id, name, description, price, image_url, category_id, stock_quantity, is_available, created_at',
          )
          .inFilter('id', ids);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ProductService.getProductsByIds error: $e');
      rethrow;
    }
  }

  /// Search products by query term
  Future<List<Product>> searchProducts(String query) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    try {
      final response = await client
          .from('products')
          .select()
          .ilike('name', '%$query%')
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ProductService.searchProducts error: $e');
      return [];
    }
  }
}
