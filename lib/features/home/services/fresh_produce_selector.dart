import '../../../models/category.dart';
import '../../../models/product.dart';

List<Category> freshProduceCategories(Iterable<Category> categories) {
  return categories.where((category) {
    final name = category.name.toLowerCase();
    return name.contains('fruit') ||
        name.contains('vegetable') ||
        name.contains('produce');
  }).toList();
}

List<Product> selectFreshProduce({
  required Iterable<Category> categories,
  required Iterable<Product> products,
  String? categoryId,
  String query = '',
}) {
  final freshCategories = freshProduceCategories(categories);
  final freshCategoryIds = freshCategories
      .map((category) => category.id)
      .toSet();
  final hasFreshCategories = freshCategoryIds.isNotEmpty;
  final normalizedQuery = query.trim().toLowerCase();
  final selected = products.where((product) {
    final isFresh = hasFreshCategories
        ? freshCategoryIds.contains(product.categoryId)
        : _isFreshProductName(product.name);
    final matchesCategory =
        categoryId == null || product.categoryId == categoryId;
    final matchesQuery =
        normalizedQuery.isEmpty ||
        product.name.toLowerCase().contains(normalizedQuery);
    return isFresh && matchesCategory && matchesQuery;
  }).toList()..sort((a, b) => b.discountAmount.compareTo(a.discountAmount));
  return selected;
}

bool _isFreshProductName(String name) {
  final normalized = name.toLowerCase();
  return normalized.contains('fruit') ||
      normalized.contains('vegetable') ||
      normalized.contains('banana') ||
      normalized.contains('apple') ||
      normalized.contains('orange') ||
      normalized.contains('tomato') ||
      normalized.contains('potato') ||
      normalized.contains('coconut');
}
