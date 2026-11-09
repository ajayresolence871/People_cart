import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/category.dart';
import '../../../models/product.dart';

abstract class AdminProductDataSource {
  Future<List<Product>> loadProducts();
  Future<List<Category>> loadCategories();
  Future<Category> createCategory(String name, {String? imageUrl});
  Future<Category> updateCategory(String id, String name, {String? imageUrl});
  Future<void> deactivateCategory(String id);
  Future<Product> createProduct(Product product);
  Future<Product> updateProduct(Product product);
}

class AdminProductService implements AdminProductDataSource {
  static const _categoryColumns = 'id, name, image_url, created_at, is_active';

  final SupabaseClient? _explicitClient;

  AdminProductService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'Supabase is not initialized. Product management is unavailable.',
      );
    }
  }

  @override
  Future<List<Product>> loadProducts() async {
    final rows = await _client
        .from('products')
        .select(
          'id, name, description, price, image_url, category_id, stock_quantity, is_available, created_at',
        )
        .order('name', ascending: true);
    return rows.map((row) => Product.fromJson(row)).toList();
  }

  @override
  Future<List<Category>> loadCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select(_categoryColumns)
          .order('name', ascending: true);
      return rows.map((row) => Category.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      if (error.code != '42703' || !error.message.contains('is_active')) {
        rethrow;
      }
      try {
        final rows = await _client
            .from('categories')
            .select('id, name, image_url')
            .order('name', ascending: true);
        return rows.map((row) => Category.fromJson(row)).toList();
      } on PostgrestException catch (fallbackError) {
        if (fallbackError.code != '42703' ||
            !fallbackError.message.contains('image_url')) {
          rethrow;
        }
        final rows = await _client
            .from('categories')
            .select('id, name')
            .order('name', ascending: true);
        return rows.map((row) => Category.fromJson(row)).toList();
      }
    }
  }

  String _validatedCategoryName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Category name is required.');
    }
    return normalized;
  }

  String? _validatedCategoryImageUrl(String? imageUrl) {
    final normalized = imageUrl?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      throw ArgumentError('Enter a valid https image URL.');
    }
    return normalized;
  }

  @override
  Future<Category> createCategory(String name, {String? imageUrl}) async {
    final row = await _client
        .from('categories')
        .insert({
          'name': _validatedCategoryName(name),
          'image_url': _validatedCategoryImageUrl(imageUrl),
        })
        .select(_categoryColumns)
        .single();
    return Category.fromJson(row);
  }

  @override
  Future<Category> updateCategory(
    String id,
    String name, {
    String? imageUrl,
  }) async {
    if (id.isEmpty) throw ArgumentError('Category ID is required.');
    final row = await _client
        .from('categories')
        .update({
          'name': _validatedCategoryName(name),
          'image_url': _validatedCategoryImageUrl(imageUrl),
        })
        .eq('id', id)
        .select(_categoryColumns)
        .single();
    return Category.fromJson(row);
  }

  @override
  Future<void> deactivateCategory(String id) async {
    if (id.isEmpty) throw ArgumentError('Category ID is required.');
    try {
      await _client
          .from('categories')
          .update({'is_active': false})
          .eq('id', id)
          .select('id')
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '42703' && error.message.contains('is_active')) {
        throw StateError(
          'Category deactivation requires the reviewed category migration to be applied first.',
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _productValues(Product product) {
    if (product.name.trim().isEmpty) {
      throw ArgumentError.value(
        product.name,
        'name',
        'Product name is required.',
      );
    }
    if (!product.price.isFinite || product.price <= 0) {
      throw ArgumentError.value(
        product.price,
        'price',
        'Price must be greater than zero.',
      );
    }
    if (product.stockQuantity < 0) {
      throw ArgumentError.value(
        product.stockQuantity,
        'stockQuantity',
        'Stock cannot be negative.',
      );
    }
    if (product.categoryId == null || product.categoryId!.isEmpty) {
      throw ArgumentError('Select a category.');
    }

    return {
      'name': product.name.trim(),
      'description': product.description?.trim().isEmpty == true
          ? null
          : product.description?.trim(),
      'price': product.price,
      'image_url': product.imageUrl?.trim().isEmpty == true
          ? null
          : product.imageUrl?.trim(),
      'category_id': product.categoryId,
      'stock_quantity': product.stockQuantity,
      'is_available': product.isAvailable,
    };
  }

  @override
  Future<Product> createProduct(Product product) async {
    final row = await _client
        .from('products')
        .insert(_productValues(product))
        .select(
          'id, name, description, price, image_url, category_id, stock_quantity, is_available, created_at',
        )
        .single();
    return Product.fromJson(row);
  }

  @override
  Future<Product> updateProduct(Product product) async {
    if (product.id.isEmpty) {
      throw ArgumentError.value(product.id, 'id', 'Product ID is required.');
    }
    final row = await _client
        .from('products')
        .update(_productValues(product))
        .eq('id', product.id)
        .select(
          'id, name, description, price, image_url, category_id, stock_quantity, is_available, created_at',
        )
        .single();
    return Product.fromJson(row);
  }
}
