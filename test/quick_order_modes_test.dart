import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/features/household/providers/household_provider.dart';
import 'package:people_cart/features/quick_order/models/quick_order_mode.dart';
import 'package:people_cart/features/quick_order/providers/quick_order_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quick-Order Modes Tests', () {
    late QuickOrderProvider quickOrderProvider;
    late CartProvider personalCart;
    late HouseholdProvider householdProvider;

    late Product milk;
    late Product bread;
    late Product bananas;
    late Product chips;
    late Product outOfStockProduct;
    late List<Product> sampleCatalog;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      quickOrderProvider = QuickOrderProvider();
      personalCart = CartProvider();
      householdProvider = HouseholdProvider(autoLoad: false);

      milk = Product(
        id: 'p_milk',
        name: 'Fresh Full Cream Milk',
        price: 35.0,
        stockQuantity: 10,
        isAvailable: true,
      );
      bread = Product(
        id: 'p_bread',
        name: 'Whole Wheat Brown Bread',
        price: 45.0,
        stockQuantity: 5,
        isAvailable: true,
      );
      bananas = Product(
        id: 'p_banana',
        name: 'Fresh Robusta Bananas',
        price: 40.0,
        stockQuantity: 20,
        isAvailable: true,
      );
      chips = Product(
        id: 'p_chips',
        name: 'Crispy Potato Curly Turns',
        price: 29.0,
        stockQuantity: 15,
        isAvailable: true,
      );
      outOfStockProduct = Product(
        id: 'p_out',
        name: 'Seasonal Mangoes',
        price: 150.0,
        stockQuantity: 0,
        isAvailable: false,
      );

      sampleCatalog = [milk, bread, bananas, chips, outOfStockProduct];
      await quickOrderProvider.loadModes(sampleCatalog);
    });

    test('1. Resolves predefined modes against real catalog products', () {
      expect(quickOrderProvider.predefinedModes.isNotEmpty, true);

      // Verify "Breakfast" mode contains real milk and bread
      final breakfast = quickOrderProvider.predefinedModes.firstWhere((m) => m.name == 'Breakfast');
      expect(breakfast.isPredefined, true);
      expect(breakfast.items.any((i) => i.productId == 'p_milk'), true);
      expect(breakfast.items.any((i) => i.productId == 'p_bread'), true);

      // Verify "Essentials" and "Snacks" exist
      expect(quickOrderProvider.predefinedModes.any((m) => m.name == 'Essentials'), true);
      expect(quickOrderProvider.predefinedModes.any((m) => m.name == 'Snacks'), true);
      expect(quickOrderProvider.predefinedModes.any((m) => m.name == 'Emergency Top-up'), true);
    });

    test('2. Creating and validating a custom mode', () async {
      // Empty name validation failure
      final emptyNameSuccess = await quickOrderProvider.createCustomMode(
        name: '   ',
        items: {milk: 1},
      );
      expect(emptyNameSuccess, false);
      expect(quickOrderProvider.errorMessage, contains('cannot be empty'));

      // Empty items validation failure
      final emptyItemsSuccess = await quickOrderProvider.createCustomMode(
        name: 'My Morning',
        items: {},
      );
      expect(emptyItemsSuccess, false);
      expect(quickOrderProvider.errorMessage, contains('at least one product'));

      // Valid custom mode creation
      final success = await quickOrderProvider.createCustomMode(
        name: 'My Morning Energy',
        items: {milk: 2, bananas: 1},
      );
      expect(success, true);
      expect(quickOrderProvider.customModes.length, 1);
      expect(quickOrderProvider.customModes.first.name, 'My Morning Energy');
      expect(quickOrderProvider.customModes.first.items.length, 2);
    });

    test('3. Duplicate product prevention and quantity editing', () async {
      // Create mode
      await quickOrderProvider.createCustomMode(
        name: 'Pantry Stock',
        items: {milk: 1, bread: 1},
      );
      final createdMode = quickOrderProvider.customModes.first;

      // Update mode with modified quantities and items
      final updateSuccess = await quickOrderProvider.updateCustomMode(
        id: createdMode.id,
        name: 'Pantry Stock Plus',
        items: {milk: 3, chips: 2},
      );
      expect(updateSuccess, true);

      final updated = quickOrderProvider.customModes.first;
      expect(updated.name, 'Pantry Stock Plus');
      expect(updated.items.firstWhere((i) => i.productId == 'p_milk').quantity, 3);
      expect(updated.items.firstWhere((i) => i.productId == 'p_chips').quantity, 2);
    });

    test('4. Adding a mode to an empty cart updates subtotal and quantities', () async {
      expect(personalCart.itemList.isEmpty, true);
      expect(personalCart.subtotal, 0.0);

      // Create a mode with 2 milk (₹35 ea = ₹70) and 1 bread (₹45 ea = ₹45) -> total ₹115
      final mode = QuickOrderMode(
        id: 'm1',
        name: 'Breakfast Combo',
        items: [
          QuickOrderItem(productId: milk.id, quantity: 2, product: milk),
          QuickOrderItem(productId: bread.id, quantity: 1, product: bread),
        ],
      );

      final result = await quickOrderProvider.addAllToCart(mode, personalCart);

      expect(result.success, true);
      expect(result.addedItemCount, 2);
      expect(result.totalUnits, 3);
      expect(personalCart.totalQuantity, 3);
      expect(personalCart.getQuantity(milk.id), 2);
      expect(personalCart.getQuantity(bread.id), 1);
      expect(personalCart.subtotal, 115.0);
    });

    test('5. Adding a mode when some products are already in cart increments quantities without duplicate rows', () async {
      // Pre-populate cart with 1 milk
      personalCart.addItem(milk);
      expect(personalCart.itemList.length, 1);
      expect(personalCart.getQuantity(milk.id), 1);

      // Add mode with 2 milk and 1 bread
      final mode = QuickOrderMode(
        id: 'm1',
        name: 'Breakfast Combo',
        items: [
          QuickOrderItem(productId: milk.id, quantity: 2, product: milk),
          QuickOrderItem(productId: bread.id, quantity: 1, product: bread),
        ],
      );

      await quickOrderProvider.addAllToCart(mode, personalCart);

      // Distinct product count in cart must be exactly 2 (milk and bread), NOT duplicate milk rows
      expect(personalCart.itemList.length, 2);
      expect(personalCart.getQuantity(milk.id), 3); // 1 pre-existing + 2 from mode
      expect(personalCart.getQuantity(bread.id), 1);
      expect(personalCart.totalQuantity, 4);
      expect(personalCart.subtotal, (3 * 35.0) + (1 * 45.0)); // 105 + 45 = 150
    });

    test('6. Unavailable products and stock limits are handled and reported', () async {
      final modeWithUnavailable = QuickOrderMode(
        id: 'm_mixed',
        name: 'Summer Pack',
        items: [
          QuickOrderItem(productId: milk.id, quantity: 1, product: milk),
          QuickOrderItem(productId: outOfStockProduct.id, quantity: 2, product: outOfStockProduct),
        ],
      );

      final result = await quickOrderProvider.addAllToCart(modeWithUnavailable, personalCart);

      expect(result.success, true);
      expect(result.addedItemCount, 1); // Only milk added
      expect(result.unavailableItems.length, 1);
      expect(result.unavailableItems.first, 'Seasonal Mangoes');
      expect(personalCart.containsProduct(outOfStockProduct.id), false);
    });

    test('7. Quick-Order Modes NEVER modify or clear the shared household basket', () async {
      // Setup household
      await householdProvider.createHousehold('My Family');
      expect(householdProvider.sharedItems.isEmpty, true);
      expect(householdProvider.sharedSubtotal, 0.0);

      // Add Quick Order mode
      final mode = QuickOrderMode(
        id: 'm_gym',
        name: 'Gym Pack',
        items: [
          QuickOrderItem(productId: bananas.id, quantity: 3, product: bananas),
        ],
      );

      await quickOrderProvider.addAllToCart(mode, personalCart);

      // Personal cart updated
      expect(personalCart.getQuantity(bananas.id), 3);
      expect(personalCart.subtotal, 120.0);

      // Household shared basket remains strictly untouched
      expect(householdProvider.sharedItems.isEmpty, true);
      expect(householdProvider.sharedSubtotal, 0.0);
      expect(householdProvider.sharedTotalQuantity, 0);
    });

    test('8. Deleting a custom mode removes it without touching the cart', () async {
      await quickOrderProvider.createCustomMode(
        name: 'Temporary Mode',
        items: {chips: 2},
      );
      final created = quickOrderProvider.customModes.first;

      // Add to cart
      await quickOrderProvider.addAllToCart(created, personalCart);
      expect(personalCart.getQuantity(chips.id), 2);

      // Delete custom mode
      await quickOrderProvider.deleteCustomMode(created.id);
      expect(quickOrderProvider.customModes.any((m) => m.id == created.id), false);

      // Cart items remain intact
      expect(personalCart.getQuantity(chips.id), 2);
    });

    test('9. Custom modes persist in SharedPreferences across reloads', () async {
      await quickOrderProvider.createCustomMode(
        name: 'Persisted Collection',
        items: {milk: 2, bread: 1},
      );

      // Create a new provider instance mimicking an app restart
      final newProvider = QuickOrderProvider();
      await newProvider.loadModes(sampleCatalog);

      expect(newProvider.customModes.length, 1);
      expect(newProvider.customModes.first.name, 'Persisted Collection');
      expect(newProvider.customModes.first.items.length, 2);
    });

    test('10. Authenticated users start with clean empty quick orders list (nothing default) and have isolated custom modes', () async {
      final userProvider = QuickOrderProvider();

      // 1. New user logs in: starts with NOTHING default
      await userProvider.loadModes(sampleCatalog, userId: 'user_deva_123');
      expect(userProvider.predefinedModes, isEmpty, reason: 'New user must have no default presets');
      expect(userProvider.customModes, isEmpty, reason: 'New user must have no default custom modes');
      expect(userProvider.allModes, isEmpty, reason: 'New user should create their own');

      // 2. User creates a custom mode
      final created = await userProvider.createCustomMode(
        name: "Deva's Chai Essentials",
        items: {milk: 1, bread: 1},
      );
      expect(created, isTrue);
      expect(userProvider.customModes.length, 1);
      expect(userProvider.allModes.length, 1);

      // 3. User logs out
      userProvider.clearModes();
      expect(userProvider.allModes, isEmpty);

      // 4. Another user logs in (e.g. Ajay): starts clean and does not see Deva's custom mode
      final secondUserProvider = QuickOrderProvider();
      await secondUserProvider.loadModes(sampleCatalog, userId: 'user_ajay_456');
      expect(secondUserProvider.allModes, isEmpty, reason: 'Second user must not see previous user quick orders');
    });
  });
}
