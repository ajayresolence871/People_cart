import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/features/household/models/household.dart';
import 'package:people_cart/features/household/models/shared_basket_item.dart';
import 'package:people_cart/features/household/providers/household_provider.dart';
import 'package:people_cart/features/household/screens/household_screen.dart';
import 'package:people_cart/features/household/services/household_service.dart';
import 'package:people_cart/features/cart/screens/cart_checkout_screen.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:provider/provider.dart';

class _FakeHouseholdService extends HouseholdService {
  String currentUserId = 'ajay-id';
  String currentName = 'Ajay';
  Household? household;
  final List<SharedBasketItem> persistedItems = [];

  @override
  String requireAuthenticatedUserId() => currentUserId;

  @override
  Future<String> getCurrentUserId() async => currentUserId;

  @override
  Future<String?> getCurrentUserDisplayName() async => currentName;

  @override
  Future<Household?> getCurrentUserHousehold() async => household;

  @override
  Future<Household> createHousehold(String name) async {
    household = Household(
      id: 'household-1',
      name: name,
      joinCode: 'PC-1234',
      createdBy: currentUserId,
      members: [
        HouseholdMember(
          householdId: 'household-1',
          userId: currentUserId,
          memberRole: 'owner',
          displayName: currentName,
        ),
      ],
    );
    return household!;
  }

  @override
  Future<List<SharedBasketItem>> getSharedBasketItems(
    String householdId,
  ) async => persistedItems
      .where((item) => item.householdId == householdId)
      .map((item) => item.copyWith())
      .toList();

  @override
  Future<void> addItemToSharedBasket(
    String householdId,
    Product product, {
    int quantity = 1,
  }) async {
    final existing = persistedItems.where(
      (item) => item.householdId == householdId && item.productId == product.id,
    );
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
      return;
    }
    persistedItems.add(
      SharedBasketItem(
        id: 'db-${product.id}',
        householdId: householdId,
        productId: product.id,
        product: product,
        quantity: quantity,
        addedBy: requireAuthenticatedUserId(),
        addedByName: currentName,
      ),
    );
  }

  @override
  Future<void> updateItemQuantity(String itemId, int newQuantity) async {
    final item = persistedItems.firstWhere((item) => item.id == itemId);
    if (newQuantity <= 0) {
      persistedItems.remove(item);
    } else {
      item.quantity = newQuantity;
    }
  }

  @override
  Future<void> removeItemFromSharedBasket(String itemId) async {
    persistedItems.removeWhere((item) => item.id == itemId);
  }

  @override
  Future<void> removeItemsFromSharedBasket(Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    persistedItems.removeWhere((item) => ids.contains(item.id));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HouseholdProvider & Basket Isolation Tests', () {
    late HouseholdProvider householdProvider;
    late CartProvider personalCart;
    late Product sampleApple;
    late Product sampleMilk;
    late _FakeHouseholdService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Initialize with autoLoad: false so no network/Supabase call is made in unit tests
      service = _FakeHouseholdService();
      householdProvider = HouseholdProvider(service: service, autoLoad: false);
      personalCart = CartProvider();

      sampleApple = Product(id: 'p1', name: 'Shimla Apples', price: 120.0);
      sampleMilk = Product(id: 'p2', name: 'Full Cream Milk', price: 35.0);
    });

    test('Initial tab is 0 (For me & family) and state is clean', () {
      expect(householdProvider.selectedTabIndex, 0);
      expect(householdProvider.hasHousehold, false);
      expect(householdProvider.sharedItems.isEmpty, true);
      expect(householdProvider.sharedSubtotal, 0.0);
      expect(householdProvider.sharedTotalQuantity, 0);
    });

    test('Tab switching works smoothly between For me & family and Myself', () {
      expect(householdProvider.selectedTabIndex, 0);

      // Switch to Myself tab (tab index 1)
      householdProvider.setTabIndex(1);
      expect(householdProvider.selectedTabIndex, 1);

      // Switch back to For me & family tab (tab index 0)
      householdProvider.setTabIndex(0);
      expect(householdProvider.selectedTabIndex, 0);
    });

    test('Creating a household assigns name, join code, and owner', () async {
      final success = await householdProvider.createHousehold('Sharma Family');
      expect(success, true);
      expect(householdProvider.hasHousehold, true);
      expect(householdProvider.household!.name, 'Sharma Family');
      expect(householdProvider.household!.joinCode.startsWith('PC-'), true);
      expect(householdProvider.household!.members.isNotEmpty, true);
    });

    test('Adding shared products calculates subtotal and quantity independently from personal cart', () async {
      await householdProvider.createHousehold('Reddy Family');

      // Add item to shared household basket
      await householdProvider.addSharedProduct(sampleApple, quantity: 2);
      expect(householdProvider.sharedItems.length, 1);
      expect(householdProvider.sharedTotalQuantity, 2);
      expect(householdProvider.sharedSubtotal, 240.0);

      // Verify that personal cart has NOT been touched (strict isolation)
      expect(personalCart.itemList.isEmpty, true);
      expect(personalCart.totalQuantity, 0);
      expect(personalCart.subtotal, 0.0);

      // Add different item to personal cart
      personalCart.addItem(sampleMilk);
      expect(personalCart.totalQuantity, 1);
      expect(personalCart.subtotal, 35.0);

      // Verify shared household basket remains unchanged
      expect(householdProvider.sharedTotalQuantity, 2);
      expect(householdProvider.sharedSubtotal, 240.0);
    });

    test('Shared basket item increment and decrement work correctly', () async {
      await householdProvider.createHousehold('Test Household');
      await householdProvider.addSharedProduct(sampleMilk, quantity: 1);

      final item = householdProvider.sharedItems.first;
      expect(item.quantity, 1);
      expect(householdProvider.sharedSubtotal, 35.0);

      // Increment
      await householdProvider.incrementItem(item);
      var refreshedItem = householdProvider.sharedItems.single;
      expect(refreshedItem.quantity, 2);
      expect(householdProvider.sharedSubtotal, 70.0);

      // Decrement
      await householdProvider.decrementItem(refreshedItem);
      refreshedItem = householdProvider.sharedItems.single;
      expect(refreshedItem.quantity, 1);
      expect(householdProvider.sharedSubtotal, 35.0);

      // Decrementing from 1 removes the item
      await householdProvider.decrementItem(refreshedItem);
      expect(householdProvider.sharedItems.isEmpty, true);
      expect(householdProvider.sharedSubtotal, 0.0);
    });

    test('Search filter on shared items works correctly', () async {
      await householdProvider.createHousehold('Search Household');
      await householdProvider.addSharedProduct(sampleApple);
      await householdProvider.addSharedProduct(sampleMilk);

      expect(householdProvider.filteredSharedItems.length, 2);

      // Filter for 'apple'
      householdProvider.setSearchQuery('apple');
      expect(householdProvider.filteredSharedItems.length, 1);
      expect(
        householdProvider.filteredSharedItems.first.product.name,
        'Shimla Apples',
      );

      // Filter for non-existing query
      householdProvider.setSearchQuery('bread');
      expect(householdProvider.filteredSharedItems.isEmpty, true);

      // Clear search
      householdProvider.setSearchQuery('');
      expect(householdProvider.filteredSharedItems.length, 2);
    });

    test('SharedBasketItem line total calculates price * quantity', () {
      final sharedItem = SharedBasketItem(
        id: 'sb1',
        householdId: 'h1',
        productId: 'p1',
        product: sampleApple,
        quantity: 3,
        addedByName: 'Mom',
      );

      expect(sharedItem.totalPrice, 360.0);
      expect(sharedItem.addedByName, 'Mom');
    });

    test('basket JSON maps contributor ID and resolved display name', () {
      final item = SharedBasketItem.fromJson({
        'id': 'basket-1',
        'household_id': 'household-1',
        'product_id': 'bread-1',
        'quantity': 1,
        'added_by': 'ajay-id',
        'added_by_name': 'Ajay Reddy',
        'products': {'id': 'bread-1', 'name': 'Brown Bread', 'price': 45},
      });

      expect(item.addedBy, 'ajay-id');
      expect(item.addedByName, 'Ajay Reddy');
      expect(item.toJson()['added_by'], 'ajay-id');
      expect(item.toJson()['added_by_name'], 'Ajay Reddy');
    });

    test('new basket insert payload uses authenticated contributor ID', () {
      final payload = buildSharedBasketInsertPayload(
        householdId: 7,
        productId: 'bread-1',
        quantity: 1,
        authenticatedUserId: 'auth-user-id',
      );

      expect(payload['added_by'], 'auth-user-id');
      expect(payload['product_id'], 'bread-1');
      expect(payload, isNot(contains('added_by_name')));
    });

    test(
      'mapped household rows prefer display_name before generic fallback',
      () {
        final item = SharedBasketItem.fromJson({
          'id': 'basket-1',
          'household_id': 'household-1',
          'product_id': 'bread-1',
          'quantity': 1,
          'added_by': 'ajay-id',
          'display_name': 'Ajay',
          'products': {'id': 'bread-1', 'name': 'Brown Bread', 'price': 45},
        });

        expect(item.addedByName, 'Ajay');
      },
    );

    test('batch profile names map to the matching basket rows', () {
      final items = mapSharedBasketRowsWithContributorNames(
        [
          {
            'id': 'basket-bread',
            'household_id': 'household-1',
            'product_id': 'bread',
            'added_by': 'ajay-id',
            'quantity': 1,
            'products': {'id': 'bread', 'name': 'Brown Bread', 'price': 45},
          },
          {
            'id': 'basket-milk',
            'household_id': 'household-1',
            'product_id': 'milk',
            'added_by': 'priya-id',
            'quantity': 1,
            'products': {'id': 'milk', 'name': 'Full Cream Milk', 'price': 35},
          },
        ],
        {'ajay-id': 'Ajay', 'priya-id': 'Priya'},
      );

      expect(items[0].addedByName, 'Ajay');
      expect(items[1].addedByName, 'Priya');
    });

    test(
      'Shared basket contributor attribution persists after quantity changes',
      () async {
        await householdProvider.createHousehold('Ajay Family');
        final bread = Product(id: 'bread_1', name: 'Brown Bread', price: 45.0);
        await householdProvider.addSharedProduct(bread);
        final item = householdProvider.sharedItems.single;

        service.currentUserId = 'priya-id';
        await householdProvider.incrementItem(item);
        final updatedItem = householdProvider.sharedItems.single;
        expect(updatedItem.quantity, 2);
        expect(updatedItem.addedByName, 'Ajay');
        expect(updatedItem.addedBy, 'ajay-id');
      },
    );

    test(
      'two authenticated members retain original product contributors',
      () async {
        await householdProvider.createHousehold('Ajay Family');

        await householdProvider.addSharedProduct(
          Product(id: 'bread-1', name: 'Brown Bread', price: 45),
        );
        expect(householdProvider.sharedItems.single.addedBy, 'ajay-id');
        expect(householdProvider.sharedItems.single.addedByName, 'Ajay');

        service
          ..currentUserId = 'priya-id'
          ..currentName = 'Priya';
        await householdProvider.addSharedProduct(sampleMilk);
        await householdProvider.loadHouseholdData();

        final basketByProduct = {
          for (final item in householdProvider.sharedItems)
            item.productId: item,
        };
        expect(basketByProduct['bread-1']?.addedBy, 'ajay-id');
        expect(basketByProduct['bread-1']?.addedByName, 'Ajay');
        expect(basketByProduct['p2']?.addedBy, 'priya-id');
        expect(basketByProduct['p2']?.addedByName, 'Priya');

        await householdProvider.incrementItem(basketByProduct['bread-1']!);
        final breadAfterQuantityChange = householdProvider.sharedItems
            .singleWhere((item) => item.productId == 'bread-1');
        expect(breadAfterQuantityChange.quantity, 2);
        expect(breadAfterQuantityChange.addedBy, 'ajay-id');
        expect(breadAfterQuantityChange.addedByName, 'Ajay');

        final secondAccount = HouseholdProvider(
          service: service,
          autoLoad: false,
        );
        await secondAccount.loadHouseholdData();
        expect(
          secondAccount.sharedItems
              .singleWhere((item) => item.productId == 'bread-1')
              .addedByName,
          'Ajay',
        );
        secondAccount.dispose();
      },
    );

    test(
      'successful checkout cleanup removes only the captured shared rows',
      () async {
        await householdProvider.createHousehold('Ajay Family');
        await householdProvider.addSharedProduct(sampleApple);
        await householdProvider.addSharedProduct(sampleMilk);
        final appleId = householdProvider.sharedItems
            .singleWhere((item) => item.productId == sampleApple.id)
            .id;

        await householdProvider.removeItemsAfterCheckout([appleId]);

        expect(householdProvider.sharedItems, hasLength(1));
        expect(householdProvider.sharedItems.single.productId, sampleMilk.id);
      },
    );

    testWidgets('household basket badge renders resolved contributor name', (
      tester,
    ) async {
      await householdProvider.createHousehold('Ajay Family');
      await householdProvider.addSharedProduct(
        Product(id: 'bread-1', name: 'Brown Bread', price: 45),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<HouseholdProvider>.value(
          value: householdProvider,
          child: const MaterialApp(home: HouseholdScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Added by Ajay'), findsOneWidget);
    });

    testWidgets(
      'Review Basket opens group checkout without changing personal cart',
      (tester) async {
        await householdProvider.createHousehold('Ajay Family');
        await householdProvider.addSharedProduct(sampleApple, quantity: 2);
        personalCart.addItem(sampleMilk);
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<HouseholdProvider>.value(
                value: householdProvider,
              ),
              ChangeNotifierProvider<CartProvider>.value(value: personalCart),
              ChangeNotifierProvider<BudgetProvider>(
                create: (_) => BudgetProvider(autoLoad: false),
              ),
            ],
            child: const MaterialApp(home: HouseholdScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Review Basket'));
        await tester.tap(find.text('Review Basket'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue to Group Checkout'));
        await tester.pumpAndSettle();

        expect(find.byType(CartCheckoutScreen), findsOneWidget);
        final groupCart = Provider.of<CartProvider>(
          tester.element(find.byType(CartCheckoutScreen)),
          listen: false,
        );
        expect(groupCart.itemList, hasLength(1));
        expect(groupCart.itemList.single.product.id, sampleApple.id);
        expect(groupCart.itemList.single.quantity, 2);
        expect(personalCart.itemList, hasLength(1));
        expect(personalCart.itemList.single.product.id, sampleMilk.id);

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      },
    );

    test('Household model serialization and member count', () {
      final member = HouseholdMember(
        householdId: 'h100',
        userId: 'u1',
        memberRole: 'owner',
        displayName: 'Ajay',
      );

      final hh = Household(
        id: 'h100',
        name: 'The Villa',
        joinCode: 'PC-VILL',
        createdBy: 'u1',
        members: [member],
      );

      expect(hh.memberCount, 1);
      expect(hh.name, 'The Villa');
      expect(hh.joinCode, 'PC-VILL');
      expect(member.isOwner, true);
    });
  });
}
