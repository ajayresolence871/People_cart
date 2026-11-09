import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/features/categories/screens/categories_screen.dart';
import 'package:people_cart/features/categories/screens/category_products_screen.dart';
import 'package:people_cart/models/category.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/services/product_service.dart';

class _FakeCatalogDataSource implements ProductCatalogDataSource {
  final categories = [
    Category(id: 'dynamic-1', name: 'Seasonal Specials'),
    Category(id: 'inactive-1', name: 'Archived Goods', isActive: false),
  ];
  final products = [
    Product(
      id: 'product-dynamic',
      name: 'Mystery Basket',
      price: 99,
      stockQuantity: 3,
      categoryId: 'dynamic-1',
    ),
    Product(
      id: 'product-other',
      name: 'Bananas',
      price: 40,
      stockQuantity: 5,
      categoryId: 'other-category',
    ),
  ];
  String? requestedCategoryId;

  @override
  Future<List<Category>> getCategories() async => categories;

  @override
  Future<List<Product>> getProducts({String? categoryId}) async {
    requestedCategoryId = categoryId;
    if (categoryId == null) return products;
    return products
        .where((product) => product.categoryId == categoryId)
        .toList();
  }

  @override
  Future<List<Product>> getProductsByIds(Iterable<String> productIds) async =>
      products.where((product) => productIds.contains(product.id)).toList();
}

void main() {
  testWidgets('customer categories display active Supabase categories only', (
    tester,
  ) async {
    final source = _FakeCatalogDataSource();
    await tester.pumpWidget(
      MaterialApp(home: CategoriesScreen(dataSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seasonal Specials'), findsOneWidget);
    expect(find.text('Archived Goods'), findsNothing);
  });

  testWidgets('category products query and display exact category ID matches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakeCatalogDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
          child: CategoryProductsScreen(
            category: source.categories.first,
            dataSource: source,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.requestedCategoryId, 'dynamic-1');
    expect(find.text('Mystery Basket'), findsOneWidget);
    expect(find.text('Bananas'), findsNothing);
  });

  testWidgets('category product cards fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakeCatalogDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
          child: CategoryProductsScreen(
            category: source.categories.first,
            dataSource: source,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mystery Basket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
