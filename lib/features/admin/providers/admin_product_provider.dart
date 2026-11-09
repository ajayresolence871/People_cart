import 'package:flutter/foundation.dart' hide Category;

import '../../../models/category.dart';
import '../../../models/product.dart';
import '../services/admin_product_service.dart';

class AdminProductProvider extends ChangeNotifier {
  final AdminProductDataSource dataSource;

  AdminProductProvider({required this.dataSource});

  List<Product>? products;
  List<Category>? categories;
  bool isLoading = false;
  bool isSaving = false;
  String? loadError;
  String? saveError;
  String? categoryError;

  Future<void> load() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        dataSource.loadProducts(),
        dataSource.loadCategories(),
      ]);
      products = results[0] as List<Product>;
      categories = results[1] as List<Category>;
    } catch (error) {
      loadError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Product> save(Product product) async {
    isSaving = true;
    saveError = null;
    notifyListeners();
    try {
      final saved = product.id.isEmpty
          ? await dataSource.createProduct(product)
          : await dataSource.updateProduct(product);
      await load();
      return saved;
    } catch (error) {
      saveError = error.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<Category> saveCategory(
    String name, {
    String? categoryId,
    String? imageUrl,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Category name is required.');
    }
    final normalizedImageUrl = imageUrl?.trim();
    if (normalizedImageUrl != null && normalizedImageUrl.isNotEmpty) {
      final uri = Uri.tryParse(normalizedImageUrl);
      if (uri == null ||
          uri.scheme.toLowerCase() != 'https' ||
          uri.host.isEmpty) {
        throw ArgumentError('Enter a valid https image URL.');
      }
    }
    final duplicate = (categories ?? const <Category>[]).any(
      (category) =>
          category.id != categoryId &&
          category.name.trim().toLowerCase() == normalizedName.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('A category with this name already exists.');
    }

    isSaving = true;
    categoryError = null;
    notifyListeners();
    try {
      final saved = categoryId == null
          ? await dataSource.createCategory(
              normalizedName,
              imageUrl: normalizedImageUrl,
            )
          : await dataSource.updateCategory(
              categoryId,
              normalizedName,
              imageUrl: normalizedImageUrl,
            );
      try {
        await refreshCategories();
      } catch (error) {
        categoryError =
            'Category saved, but the list could not refresh: $error';
      }
      return saved;
    } catch (error) {
      categoryError = error.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deactivateCategory(String categoryId) async {
    isSaving = true;
    categoryError = null;
    notifyListeners();
    try {
      await dataSource.deactivateCategory(categoryId);
      try {
        await refreshCategories();
      } catch (error) {
        categoryError =
            'Category deactivated, but the list could not refresh: $error';
      }
    } catch (error) {
      categoryError = error.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> refreshCategories() async {
    categories = await dataSource.loadCategories();
    categoryError = null;
    notifyListeners();
  }
}
