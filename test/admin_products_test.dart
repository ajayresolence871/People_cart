import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/core/widgets/catalog_image.dart';
import 'package:people_cart/features/admin/models/admin_dashboard_data.dart';
import 'package:people_cart/features/admin/screens/admin_dashboard_screen.dart';
import 'package:people_cart/features/admin/screens/admin_products_screen.dart';
import 'package:people_cart/features/admin/providers/admin_product_provider.dart';
import 'package:people_cart/features/admin/services/admin_dashboard_service.dart';
import 'package:people_cart/features/admin/services/admin_product_service.dart';
import 'package:people_cart/models/category.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';

class _FakeAdminProductDataSource implements AdminProductDataSource {
  final List<Product> products = [];
  final List<Category> categories = [
    Category(id: 'category-1', name: 'Produce'),
  ];
  int createCount = 0;
  int updateCount = 0;
  int categoryCreateCount = 0;
  int categoryUpdateCount = 0;
  String? createdCategoryImageUrl;
  String? updatedCategoryImageUrl;
  Object? failure;

  @override
  Future<List<Product>> loadProducts() async => List.of(products);

  @override
  Future<List<Category>> loadCategories() async => List.of(categories);

  @override
  Future<Category> createCategory(String name, {String? imageUrl}) async {
    if (failure != null) throw failure!;
    categoryCreateCount++;
    createdCategoryImageUrl = imageUrl;
    final category = Category(
      id: 'category-${categories.length + 1}',
      name: name,
      imageUrl: imageUrl,
    );
    categories.add(category);
    return category;
  }

  @override
  Future<Category> updateCategory(
    String id,
    String name, {
    String? imageUrl,
  }) async {
    if (failure != null) throw failure!;
    categoryUpdateCount++;
    updatedCategoryImageUrl = imageUrl;
    final index = categories.indexWhere((category) => category.id == id);
    if (index < 0) throw StateError('Category not found');
    final updated = Category(
      id: id,
      name: name,
      imageUrl: imageUrl,
      isActive: categories[index].isActive,
    );
    categories[index] = updated;
    return updated;
  }

  @override
  Future<void> deactivateCategory(String id) async {
    if (failure != null) throw failure!;
    final index = categories.indexWhere((category) => category.id == id);
    if (index < 0) throw StateError('Category not found');
    final category = categories[index];
    categories[index] = Category(
      id: category.id,
      name: category.name,
      isActive: false,
    );
  }

  @override
  Future<Product> createProduct(Product product) async {
    if (failure != null) throw failure!;
    createCount++;
    final saved = product.copyWith(id: 'product-$createCount');
    products.add(saved);
    return saved;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    if (failure != null) throw failure!;
    updateCount++;
    final index = products.indexWhere((entry) => entry.id == product.id);
    if (index < 0) throw StateError('Product not found');
    products[index] = product;
    return product;
  }
}

class _FakeDashboardDataSource implements AdminDashboardDataSource {
  @override
  Future<AdminOrderMetrics> loadOrderMetrics() async => const AdminOrderMetrics(
    totalOrders: 0,
    ordersToday: 0,
    ordersByStatus: {},
  );

  @override
  Future<List<AdminRecentOrder>> loadRecentOrders() async => [];
}

void main() {
  Future<void> pumpAdminProducts(
    WidgetTester tester,
    _FakeAdminProductDataSource source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: AuthProvider(
            isAuthenticatedForTesting: true,
            initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
          ),
          child: Scaffold(body: AdminProductsScreen(dataSource: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Admin product inventory', () {
    testWidgets('blocks inventory access for non-admin profiles', (
      tester,
    ) async {
      final source = _FakeAdminProductDataSource();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(
                id: 'customer-2',
                role: 'customer',
              ),
            ),
            child: AdminProductsScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin access required.'), findsOneWidget);
      expect(find.text('Add product'), findsNothing);
      expect(source.createCount, 0);
    });

    testWidgets('renders honest empty state and category filters', (
      tester,
    ) async {
      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);

      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('No products are in the catalog yet.'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Available'), findsWidgets);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('Add product'), findsOneWidget);
    });

    testWidgets('category management uses compact actions and active states', (
      tester,
    ) async {
      final source = _FakeAdminProductDataSource()
        ..categories.add(
          Category(id: 'category-2', name: 'Bakery', isActive: false),
        );
      await pumpAdminProducts(tester, source);

      await tester.tap(find.byKey(const ValueKey('inventory-tab-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 active · 1 inactive'), findsOneWidget);
      expect(find.text('Produce'), findsOneWidget);
      expect(find.text('Bakery'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.byTooltip('Rename Produce'), findsOneWidget);
      expect(find.byTooltip('Deactivate Produce'), findsOneWidget);
      expect(find.byTooltip('Rename Bakery'), findsOneWidget);
      expect(find.byTooltip('Deactivate Bakery'), findsNothing);
    });

    testWidgets('category images can be saved, previewed, and edited', (
      tester,
    ) async {
      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.tap(find.byKey(const ValueKey('inventory-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Bakery',
      );
      await tester.enterText(
        find.byKey(const ValueKey('category-image-url')),
        'https://example.com/bakery.jpg',
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogImage), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(source.createdCategoryImageUrl, 'https://example.com/bakery.jpg');
      expect(find.byType(CatalogImage), findsOneWidget);

      await tester.tap(find.byTooltip('Rename Bakery'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('category-image-url')),
            )
            .controller!
            .text,
        'https://example.com/bakery.jpg',
      );
      await tester.enterText(
        find.byKey(const ValueKey('category-image-url')),
        'https://example.com/bakery-new.jpg',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        source.updatedCategoryImageUrl,
        'https://example.com/bakery-new.jpg',
      );
    });

    testWidgets('category image field rejects non-https URLs', (tester) async {
      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.tap(find.byKey(const ValueKey('inventory-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Bakery',
      );
      await tester.enterText(
        find.byKey(const ValueKey('category-image-url')),
        r'C:\images\bakery.jpg',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(source.categoryCreateCount, 0);
      expect(find.text('Enter a valid https image URL.'), findsOneWidget);
    });

    testWidgets('product form adapts to a phone-sized dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.ensureVisible(find.text('Add product'));
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFFF3EAF3));
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Add product'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('product-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-price')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-stock')), findsOneWidget);
      expect(find.text('Create product'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('summary counts and cards filter the loaded product list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource()
        ..products.addAll([
          Product(id: '1', name: 'Regular stock', price: 10, stockQuantity: 8),
          Product(id: '2', name: 'Low stock', price: 10, stockQuantity: 3),
          Product(id: '3', name: 'Zero stock', price: 10, stockQuantity: 0),
          Product(
            id: '4',
            name: 'Unavailable low stock',
            price: 10,
            stockQuantity: 2,
            isAvailable: false,
          ),
          Product(
            id: '5',
            name: 'Unavailable and empty',
            price: 10,
            stockQuantity: 0,
            isAvailable: false,
          ),
        ]);
      await pumpAdminProducts(tester, source);

      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Total products'), findsOneWidget);
      expect(find.text('Available'), findsWidgets);
      expect(find.text('Low stock'), findsWidgets);
      expect(find.text('Out of stock'), findsWidgets);

      await tester.tap(find.text('Low stock').first);
      await tester.pumpAndSettle();
      expect(find.text('Low stock', skipOffstage: false), findsWidgets);
      expect(find.text('Regular stock'), findsNothing);
      expect(find.text('Low stock', skipOffstage: false), findsWidgets);
      expect(find.text('Unavailable low stock'), findsOneWidget);

      await tester.tap(find.text('Out of stock').first);
      await tester.pumpAndSettle();
      expect(find.text('Zero stock'), findsOneWidget);
      expect(find.text('Unavailable and empty'), findsOneWidget);
      expect(find.text('Unavailable · Out of stock'), findsOneWidget);

      await tester.tap(find.text('Total products'));
      await tester.pumpAndSettle();
      expect(find.text('Regular stock'), findsOneWidget);
      expect(find.text('Unavailable and empty'), findsOneWidget);
    });

    testWidgets(
      'creates a product with validated fields and refreshes the list',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final source = _FakeAdminProductDataSource();
        await pumpAdminProducts(tester, source);
        await tester.tap(find.text('Add product'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('product-name')),
          'Fresh Apple',
        );
        await tester.enterText(
          find.byKey(const ValueKey('product-price')),
          '42.50',
        );
        await tester.enterText(
          find.byKey(const ValueKey('product-stock')),
          '4',
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Produce').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create product'));
        await tester.pumpAndSettle();

        expect(source.createCount, 1);
        expect(source.products.single.name, 'Fresh Apple');
        expect(source.products.single.price, 42.5);
        expect(source.products.single.stockQuantity, 4);
        expect(find.text('Fresh Apple'), findsOneWidget);
        expect(find.text('Product created.'), findsOneWidget);
      },
    );

    testWidgets('rejects negative stock and invalid price without saving', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('product-name')),
        'Fresh Apple',
      );
      await tester.enterText(find.byKey(const ValueKey('product-price')), '-1');
      await tester.enterText(find.byKey(const ValueKey('product-stock')), '-2');
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produce').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create product'));
      await tester.pumpAndSettle();

      expect(source.createCount, 0);
      expect(find.text('Enter a price greater than zero.'), findsOneWidget);
      expect(
        find.text('Enter a whole number of zero or more.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects a local file path as an image URL', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('product-name')),
        'Fresh Apple',
      );
      await tester.enterText(
        find.byKey(const ValueKey('product-price')),
        '42.50',
      );
      await tester.enterText(find.byKey(const ValueKey('product-stock')), '4');
      await tester.enterText(
        find.byKey(const ValueKey('product-image-url')),
        r'C:\images\apple.png',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produce').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create product'));
      await tester.pumpAndSettle();

      expect(source.createCount, 0);
      expect(find.text('Enter a valid https image URL.'), findsOneWidget);
    });

    testWidgets('edits an existing product and refreshes the inventory', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource();
      source.products.add(
        Product(
          id: 'existing-1',
          name: 'Fresh Apple',
          price: 20,
          stockQuantity: 2,
          categoryId: 'category-1',
          isAvailable: true,
        ),
      );
      await pumpAdminProducts(tester, source);
      await tester.tap(find.byTooltip('Edit Fresh Apple'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('product-price')), '25');
      await tester.enterText(find.byKey(const ValueKey('product-stock')), '0');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(source.updateCount, 1);
      expect(source.products.single.price, 25);
      expect(source.products.single.stockQuantity, 0);
      expect(find.text('Product updated.'), findsOneWidget);
    });

    testWidgets('shows database write failures and does not report success', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource()
        ..failure = StateError('new row violates row-level security policy');
      await pumpAdminProducts(tester, source);
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('product-name')),
        'Fresh Apple',
      );
      await tester.enterText(
        find.byKey(const ValueKey('product-price')),
        '42.50',
      );
      await tester.enterText(find.byKey(const ValueKey('product-stock')), '4');
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produce').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create product'));
      await tester.pumpAndSettle();

      expect(source.createCount, 0);
      expect(find.textContaining('row-level security policy'), findsOneWidget);
      expect(find.text('Product created.'), findsNothing);
    });

    test(
      'validates, renames, and deactivates categories with refreshes',
      () async {
        final source = _FakeAdminProductDataSource();
        final provider = AdminProductProvider(dataSource: source);
        await provider.load();

        await expectLater(
          provider.saveCategory('   '),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          provider.saveCategory('  pRODUCE  '),
          throwsA(isA<ArgumentError>()),
        );
        expect(source.categoryCreateCount, 0);

        final created = await provider.saveCategory('  Pantry  ');
        expect(created.name, 'Pantry');
        expect(
          provider.categories!.any((category) => category.name == 'Pantry'),
          isTrue,
        );

        await provider.saveCategory('Fresh Produce', categoryId: 'category-1');
        expect(
          provider.categories!
              .singleWhere((category) => category.id == 'category-1')
              .name,
          'Fresh Produce',
        );
        await provider.deactivateCategory('category-1');
        expect(
          provider.categories!
              .singleWhere((category) => category.id == 'category-1')
              .isActive,
          isFalse,
        );
      },
    );

    testWidgets('new categories refresh the product creation dropdown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.tap(find.byKey(const ValueKey('inventory-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Pet Supplies',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Pet Supplies'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inventory-tab-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('Pet Supplies'), findsOneWidget);
    });

    testWidgets('shows duplicate category names without creating them', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = _FakeAdminProductDataSource();
      await pumpAdminProducts(tester, source);
      await tester.tap(find.byKey(const ValueKey('inventory-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '  pRODUCE ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(source.categoryCreateCount, 0);
      expect(
        find.textContaining('category with this name already exists'),
        findsOneWidget,
      );
    });

    test(
      'available and out-of-stock boundaries are represented from stock fields',
      () {
        final available = Product(
          id: '1',
          name: 'In stock',
          price: 10,
          stockQuantity: 1,
          isAvailable: true,
        );
        final depleted = Product(
          id: '2',
          name: 'Depleted',
          price: 10,
          stockQuantity: 0,
          isAvailable: true,
        );
        final unavailable = Product(
          id: '3',
          name: 'Disabled',
          price: 10,
          stockQuantity: 7,
          isAvailable: false,
        );

        expect(available.isInStock, isTrue);
        expect(available.isOutOfStock, isFalse);
        expect(depleted.isInStock, isFalse);
        expect(depleted.isOutOfStock, isTrue);
        expect(unavailable.isInStock, isFalse);
        expect(unavailable.isOutOfStock, isTrue);
      },
    );

    testWidgets('admin navigation includes a unified inventory destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: AdminDashboardScreen(dataSource: _FakeDashboardDataSource()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();

      expect(find.text('Inventory'), findsWidgets);
      expect(find.text('Stock'), findsNothing);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Manage categories'), findsNothing);

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.destinations, hasLength(4));
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(navigationBar.selectedIndex, 1);

      await tester.tap(find.byKey(const ValueKey('inventory-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('Inventory'), findsWidgets);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await tester.tap(find.byKey(const ValueKey('inventory-tab-0')));
      await tester.pumpAndSettle();
      expect(find.text('Add product'), findsOneWidget);
    });
  });
}
