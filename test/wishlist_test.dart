import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/features/wishlist/models/wishlist_entry.dart';
import 'package:people_cart/features/wishlist/providers/wishlist_provider.dart';
import 'package:people_cart/features/wishlist/screens/wishlist_screen.dart';
import 'package:people_cart/features/wishlist/services/wishlist_service.dart';
import 'package:people_cart/features/wishlist/widgets/wishlist_heart_button.dart';
import 'package:people_cart/features/home/screens/home_screen.dart';
import 'package:people_cart/features/profile/screens/profile_screen.dart';
import 'package:people_cart/features/household/providers/household_provider.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/features/quick_order/providers/quick_order_provider.dart';

class _FakeWishlistDataSource implements WishlistDataSource {
  final Map<String, Set<String>> entriesByUser = {};
  int addCount = 0;
  int removeCount = 0;
  Object? loadFailure;
  Object? writeFailure;
  Completer<void>? addGate;

  @override
  Future<List<WishlistEntry>> loadEntries({
    required String expectedUserId,
  }) async {
    if (loadFailure != null) throw loadFailure!;
    return (entriesByUser[expectedUserId] ?? {})
        .map((id) => WishlistEntry(productId: id))
        .toList();
  }

  @override
  Future<void> addProduct(
    String productId, {
    required String expectedUserId,
  }) async {
    addCount++;
    await addGate?.future;
    if (writeFailure != null) throw writeFailure!;
    entriesByUser.putIfAbsent(expectedUserId, () => {}).add(productId);
  }

  @override
  Future<void> removeProduct(
    String productId, {
    required String expectedUserId,
  }) async {
    removeCount++;
    if (writeFailure != null) throw writeFailure!;
    entriesByUser.putIfAbsent(expectedUserId, () => {}).remove(productId);
  }
}

Product _product(
  String id, {
  String name = 'Fresh Apples',
  double price = 42,
  int stock = 4,
  bool available = true,
}) {
  return Product(
    id: id,
    name: name,
    price: price,
    stockQuantity: stock,
    isAvailable: available,
  );
}

void main() {
  group('WishlistProvider', () {
    test(
      'loads saved IDs and current product data for its authenticated user',
      () async {
        final source = _FakeWishlistDataSource()
          ..entriesByUser['customer-a'] = {'apple'};
        final provider = WishlistProvider(
          userId: 'customer-a',
          dataSource: source,
          loadProductsByIds: (ids) async => [
            if (ids.contains('apple')) _product('apple', price: 57),
          ],
          autoLoad: false,
        );

        await provider.load();

        expect(provider.hasLoaded, isTrue);
        expect(provider.productIds, {'apple'});
        expect(provider.products.single.price, 57);
        expect(provider.error, isNull);
      },
    );

    test(
      'toggle adds and removes a product without duplicate requests',
      () async {
        final source = _FakeWishlistDataSource()..addGate = Completer<void>();
        final provider = WishlistProvider(
          userId: 'customer-a',
          dataSource: source,
          loadProductsByIds: (_) async => [],
          autoLoad: false,
        );
        await provider.load();

        final firstToggle = provider.toggleProduct(
          'apple',
          product: _product('apple'),
        );
        expect(provider.contains('apple'), isTrue);
        expect(await provider.toggleProduct('apple'), isFalse);
        expect(source.addCount, 1);

        source.addGate!.complete();
        expect(await firstToggle, isTrue);
        expect(await provider.toggleProduct('apple'), isTrue);
        expect(provider.contains('apple'), isFalse);
        expect(source.removeCount, 1);
      },
    );

    test(
      'failed toggle rolls back optimistic state and exposes the error',
      () async {
        final source = _FakeWishlistDataSource()
          ..writeFailure = StateError('permission denied');
        final provider = WishlistProvider(
          userId: 'customer-a',
          dataSource: source,
          loadProductsByIds: (_) async => [],
          autoLoad: false,
        );
        await provider.load();

        expect(await provider.toggleProduct('apple'), isFalse);
        expect(provider.contains('apple'), isFalse);
        expect(provider.error, contains('permission denied'));
      },
    );

    test(
      'load exposes errors and an empty successful load stays empty',
      () async {
        final failingSource = _FakeWishlistDataSource()
          ..loadFailure = StateError('offline');
        final failed = WishlistProvider(
          userId: 'customer-a',
          dataSource: failingSource,
          loadProductsByIds: (_) async => [],
          autoLoad: false,
        );
        await failed.load();
        expect(failed.error, contains('offline'));
        expect(failed.hasLoaded, isFalse);

        final empty = WishlistProvider(
          userId: 'customer-a',
          dataSource: _FakeWishlistDataSource(),
          loadProductsByIds: (_) async => [],
          autoLoad: false,
        );
        await empty.load();
        expect(empty.hasLoaded, isTrue);
        expect(empty.products, isEmpty);
        expect(empty.error, isNull);
      },
    );

    test(
      'wishlist data remains isolated between customer provider instances',
      () async {
        final source = _FakeWishlistDataSource()
          ..entriesByUser['customer-a'] = {'apple'}
          ..entriesByUser['customer-b'] = {'pear'};
        final a = WishlistProvider(
          userId: 'customer-a',
          dataSource: source,
          loadProductsByIds: (ids) async =>
              ids.map((id) => _product(id)).toList(),
          autoLoad: false,
        );
        final b = WishlistProvider(
          userId: 'customer-b',
          dataSource: source,
          loadProductsByIds: (ids) async =>
              ids.map((id) => _product(id)).toList(),
          autoLoad: false,
        );

        await a.load();
        await b.load();
        expect(a.productIds, {'apple'});
        expect(b.productIds, {'pear'});
        expect(a.productIds.intersection(b.productIds), isEmpty);
      },
    );

    test(
      'sign-out clears the authenticated customer wishlist immediately',
      () async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(
            id: 'customer-a',
            role: 'customer',
          ),
        );
        final source = _FakeWishlistDataSource()
          ..entriesByUser['customer-a'] = {'apple'};
        final provider = WishlistProvider(
          authProvider: auth,
          dataSource: source,
          loadProductsByIds: (ids) async =>
              ids.map((id) => _product(id)).toList(),
          autoLoad: false,
        );
        await provider.load();

        await auth.signOut();

        expect(provider.userId, isNull);
        expect(provider.productIds, isEmpty);
        expect(provider.products, isEmpty);
        provider.dispose();
      },
    );

    test(
      'failed removal restores the saved product in the screen state',
      () async {
        final source = _FakeWishlistDataSource()
          ..entriesByUser['customer-a'] = {'apple'}
          ..writeFailure = StateError('network unavailable');
        final apple = _product('apple');
        final provider = WishlistProvider(
          userId: 'customer-a',
          dataSource: source,
          loadProductsByIds: (_) async => [apple],
          autoLoad: false,
        );
        await provider.load();

        expect(await provider.toggleProduct('apple', product: apple), isFalse);
        expect(provider.contains('apple'), isTrue);
        expect(provider.products.single.id, 'apple');
        expect(provider.error, contains('network unavailable'));
      },
    );
  });

  testWidgets(
    'wishlist displays current prices and blocks unavailable products',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _FakeWishlistDataSource()
        ..entriesByUser['customer-a'] = {'apple', 'pear', 'banana'};
      final products = {
        'apple': _product('apple', price: 57),
        'pear': _product('pear', stock: 0),
        'banana': _product('banana', stock: 10, available: false),
      };
      final wishlist = WishlistProvider(
        userId: 'customer-a',
        dataSource: source,
        loadProductsByIds: (ids) async =>
            ids.map((id) => products[id]).whereType<Product>().toList(),
        autoLoad: false,
      );
      await wishlist.load();
      final cart = CartProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WishlistProvider>.value(value: wishlist),
            ChangeNotifierProvider<CartProvider>.value(value: cart),
          ],
          child: const MaterialApp(home: WishlistScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹57.00'), findsOneWidget);
      expect(find.text('Out of stock'), findsNWidgets(2));
      expect(find.text('Unavailable'), findsNWidgets(2));
      expect(find.text('Add to Cart'), findsOneWidget);

      final unavailableButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Out of stock'),
      );
      expect(unavailableButton.onPressed, isNull);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Unavailable'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Cart'));
      await tester.pump();
      expect(cart.getQuantity('apple'), 1);
      expect(cart.getQuantity('pear'), 0);
    },
  );

  testWidgets('heart reflects a successful wishlist toggle', (tester) async {
    final provider = WishlistProvider(
      userId: 'customer-a',
      dataSource: _FakeWishlistDataSource(),
      loadProductsByIds: (_) async => [],
      autoLoad: false,
    );
    await provider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<WishlistProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: WishlistHeartButton(product: _product('apple'))),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('wishlist screen shows its empty and retryable error states', (
    tester,
  ) async {
    final source = _FakeWishlistDataSource();
    final provider = WishlistProvider(
      userId: 'customer-a',
      dataSource: source,
      loadProductsByIds: (_) async => [],
      autoLoad: false,
    );
    await provider.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WishlistProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => CartProvider()),
        ],
        child: const MaterialApp(home: WishlistScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your wishlist is empty'), findsOneWidget);

    source.loadFailure = StateError('network unavailable');
    await provider.load(force: true);
    await tester.pumpAndSettle();
    expect(find.text('Wishlist could not be loaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('home Wishlist shortcut opens the shared Wishlist screen', (
    tester,
  ) async {
    final provider = WishlistProvider(
      userId: 'customer-a',
      dataSource: _FakeWishlistDataSource(),
      loadProductsByIds: (_) async => [],
      autoLoad: false,
    );
    await provider.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WishlistProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => QuickOrderProvider()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('My Wishlist'), findsOneWidget);
  });

  testWidgets('profile Wishlist shortcut opens the same Wishlist screen', (
    tester,
  ) async {
    final provider = WishlistProvider(
      userId: 'customer-a',
      dataSource: _FakeWishlistDataSource(),
      loadProductsByIds: (_) async => [],
      autoLoad: false,
    );
    await provider.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WishlistProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(
                id: 'customer-a',
                role: 'customer',
              ),
            ),
          ),
          ChangeNotifierProvider(create: (_) => HouseholdProvider()),
          ChangeNotifierProvider(
            create: (_) => BudgetProvider(autoLoad: false),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final wishlistItem = find.widgetWithText(ListTile, 'My Wishlist');
    await tester.scrollUntilVisible(wishlistItem, 200);
    await tester.tap(wishlistItem);
    await tester.pumpAndSettle();

    expect(find.text('My Wishlist'), findsOneWidget);
    expect(find.byType(WishlistScreen), findsOneWidget);
  });
}
