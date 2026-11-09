import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/features/household/providers/household_provider.dart';
import 'package:people_cart/features/quick_order/providers/quick_order_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CartProvider cart;
  late Product productZeroStock;
  late Product productStockOne;
  late Product productStockFive;
  late Product productUnavailable;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cart = CartProvider();

    productZeroStock = Product(
      id: 'p_zero',
      name: 'Zero Stock Milk',
      price: 30.0,
      stockQuantity: 0,
      isAvailable: true,
    );

    productStockOne = Product(
      id: 'p_one',
      name: 'Rare Saffron',
      price: 150.0,
      stockQuantity: 1,
      isAvailable: true,
    );

    productStockFive = Product(
      id: 'p_five',
      name: 'Farm Apples',
      price: 40.0,
      stockQuantity: 5,
      isAvailable: true,
    );

    productUnavailable = Product(
      id: 'p_unavail',
      name: 'Seasonal Mangoes',
      price: 80.0,
      stockQuantity: 10,
      isAvailable: false,
    );
  });

  group('Centralized Cart Stock Limits & Quantity Tests', () {
    test('1. Zero stock product cannot be added to cart', () {
      expect(cart.isOutOfStock(productZeroStock), isTrue);
      expect(cart.canIncrement(productZeroStock), isFalse);

      final result = cart.addItem(productZeroStock);
      expect(result.status, equals(CartOperationStatus.outOfStock));
      expect(result.currentQuantity, equals(0));
      expect(cart.getQuantity(productZeroStock.id), equals(0));
      expect(cart.containsProduct(productZeroStock.id), isFalse);
      expect(cart.totalQuantity, equals(0));
      expect(cart.subtotal, equals(0.0));
    });

    test('2. Unavailable product cannot be added even if stockQuantity > 0', () {
      expect(cart.isOutOfStock(productUnavailable), isTrue);
      expect(cart.canIncrement(productUnavailable), isFalse);

      final result = cart.addItem(productUnavailable);
      expect(result.status, equals(CartOperationStatus.outOfStock));
      expect(cart.containsProduct(productUnavailable.id), isFalse);
    });

    test('3. Stock of one can be added once, second attempt is blocked', () {
      expect(cart.canIncrement(productStockOne), isTrue);

      // First addition succeeds
      final res1 = cart.addItem(productStockOne);
      expect(res1.status, equals(CartOperationStatus.success));
      expect(res1.currentQuantity, equals(1));
      expect(cart.getQuantity(productStockOne.id), equals(1));
      expect(cart.canIncrement(productStockOne), isFalse);

      // Second addition is blocked
      final res2 = cart.addItem(productStockOne);
      expect(res2.status, equals(CartOperationStatus.maxStockReached));
      expect(res2.message, contains('Only 1 in stock'));
      expect(cart.getQuantity(productStockOne.id), equals(1));
      expect(cart.totalQuantity, equals(1));
      expect(cart.subtotal, equals(150.0));
    });

    test('4. Maximum stock limit caps additions and disables increment', () {
      // Add up to 5 items
      for (int i = 1; i <= 5; i++) {
        expect(cart.canIncrement(productStockFive), isTrue);
        final res = cart.addItem(productStockFive);
        expect(res.status, equals(CartOperationStatus.success));
        expect(res.currentQuantity, equals(i));
      }

      // Quantity is now at max (5)
      expect(cart.getQuantity(productStockFive.id), equals(5));
      expect(cart.canIncrement(productStockFive), isFalse);
      expect(cart.getRemainingStock(productStockFive), equals(0));

      // 6th addition must be rejected
      final overflow = cart.addItem(productStockFive);
      expect(overflow.status, equals(CartOperationStatus.maxStockReached));
      expect(overflow.message, contains('Only 5 in stock'));
      expect(cart.getQuantity(productStockFive.id), equals(5));
      expect(cart.totalQuantity, equals(5));
      expect(cart.subtotal, equals(200.0)); // 5 * 40
    });

    test('5. Repeated additions from different screens update existing entry without duplicate rows', () {
      // Screen 1: Home adds product
      cart.addItem(productStockFive);
      expect(cart.distinctItemCount, equals(1));
      expect(cart.getQuantity(productStockFive.id), equals(1));

      // Screen 2: Search screen adds same product
      cart.addItem(productStockFive);
      expect(cart.distinctItemCount, equals(1));
      expect(cart.getQuantity(productStockFive.id), equals(2));

      // Screen 3: Category screen adds same product
      cart.addItem(productStockFive);
      expect(cart.distinctItemCount, equals(1));
      expect(cart.getQuantity(productStockFive.id), equals(3));

      // Verify list has only 1 CartItem entry
      expect(cart.itemList.length, equals(1));
      expect(cart.itemList.first.product.id, equals(productStockFive.id));
      expect(cart.itemList.first.quantity, equals(3));
      expect(cart.subtotal, equals(120.0));
    });

    test('6. Decrementing quantity from 1 removes product from cart completely', () {
      cart.addItem(productStockFive);
      expect(cart.getQuantity(productStockFive.id), equals(1));
      expect(cart.containsProduct(productStockFive.id), isTrue);

      final result = cart.decrementQuantity(productStockFive);
      expect(result.status, equals(CartOperationStatus.removed));
      expect(result.currentQuantity, equals(0));
      expect(cart.getQuantity(productStockFive.id), equals(0));
      expect(cart.containsProduct(productStockFive.id), isFalse);
      expect(cart.distinctItemCount, equals(0));
      expect(cart.itemList.isEmpty, isTrue);
      expect(cart.totalQuantity, equals(0));
      expect(cart.subtotal, equals(0.0));
    });

    test('7. Subtotal and totalQuantity update immediately and accurately', () {
      expect(cart.subtotal, equals(0.0));
      expect(cart.totalQuantity, equals(0));

      cart.addItem(productStockFive); // +40
      expect(cart.subtotal, equals(40.0));
      expect(cart.totalQuantity, equals(1));

      cart.addItem(productStockOne); // +150
      expect(cart.subtotal, equals(190.0));
      expect(cart.totalQuantity, equals(2));

      cart.incrementQuantity(productStockFive); // +40
      expect(cart.subtotal, equals(230.0));
      expect(cart.totalQuantity, equals(3));

      cart.decrementQuantity(productStockFive); // -40
      expect(cart.subtotal, equals(190.0));
      expect(cart.totalQuantity, equals(2));

      cart.decrementQuantity(productStockOne); // -150 (removed)
      expect(cart.subtotal, equals(40.0));
      expect(cart.totalQuantity, equals(1));
    });

    test('8. Batch adding caps products at available stock', () {
      final added = cart.addBatchProducts({
        productZeroStock: 2,   // should be skipped (0 in stock)
        productStockOne: 3,    // should be capped to 1
        productStockFive: 10,  // should be capped to 5
      });

      expect(added.containsKey(productZeroStock), isFalse);
      expect(added[productStockOne], equals(1));
      expect(added[productStockFive], equals(5));

      expect(cart.getQuantity(productStockOne.id), equals(1));
      expect(cart.getQuantity(productStockFive.id), equals(5));
      expect(cart.totalQuantity, equals(6));
    });

    test('9. Stale stock validation adjusts cart items when catalog changes', () {
      cart.addItem(productStockFive); // qty = 1
      cart.addItem(productStockFive); // qty = 2
      cart.addItem(productStockFive); // qty = 3

      expect(cart.getQuantity(productStockFive.id), equals(3));

      // Simulate updated catalog where stock dropped to 2
      final updatedCatalog = [
        productStockFive.copyWith(stockQuantity: 2),
      ];

      final notices = cart.validateCartAgainstStock(updatedCatalog);
      expect(notices.isNotEmpty, isTrue);
      expect(notices.first, contains('adjusted from 3 to 2'));
      expect(cart.getQuantity(productStockFive.id), equals(2));
    });

    test('10. Personal cart changes NEVER modify the shared household basket', () {
      final household = HouseholdProvider();
      final initialBasketCount = household.sharedItems.length;

      // Personal cart operations
      cart.addItem(productStockFive);
      cart.addItem(productStockOne);
      cart.decrementQuantity(productStockFive);
      cart.clearCart();

      // Household basket is completely untouched
      expect(household.sharedItems.length, equals(initialBasketCount));
    });

    test('11. Quick Order preset deletion and restoration', () async {
      final quickOrder = QuickOrderProvider();
      final catalog = [
        Product(id: 'prod_milk', name: 'Milk', price: 30.0, stockQuantity: 20),
        Product(id: 'prod_bread', name: 'Bread', price: 40.0, stockQuantity: 20),
        Product(id: 'prod_banana', name: 'Banana', price: 40.0, stockQuantity: 20),
        Product(id: 'prod_eggs', name: 'Eggs', price: 50.0, stockQuantity: 20),
      ];

      await quickOrder.loadModes(catalog);
      final initialCount = quickOrder.predefinedModes.length;
      expect(initialCount, greaterThan(0));

      final firstPresetId = quickOrder.predefinedModes.first.id;

      // Delete/hide preset
      await quickOrder.deletePresetMode(firstPresetId);
      expect(quickOrder.predefinedModes.length, equals(initialCount - 1));
      expect(quickOrder.predefinedModes.any((m) => m.id == firstPresetId), isFalse);
      expect(quickOrder.hasHiddenPresets, isTrue);

      // Restore default presets
      await quickOrder.restoreDefaultPresets();
      expect(quickOrder.predefinedModes.length, equals(initialCount));
      expect(quickOrder.predefinedModes.any((m) => m.id == firstPresetId), isTrue);
      expect(quickOrder.hasHiddenPresets, isFalse);
    });
  });
}
