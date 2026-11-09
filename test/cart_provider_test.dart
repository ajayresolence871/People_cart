import 'package:flutter_test/flutter_test.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/cart_provider.dart';

void main() {
  group('CartProvider Tests', () {
    late CartProvider cart;
    late Product sampleBanana;
    late Product sampleMilk;

    setUp(() {
      cart = CartProvider();
      sampleBanana = Product(
        id: '1',
        name: 'Fresh Bananas',
        price: 40.0,
      );
      sampleMilk = Product(
        id: '2',
        name: 'Full Cream Milk',
        price: 35.0,
      );
    });

    test('Initial cart is empty', () {
      expect(cart.totalQuantity, 0);
      expect(cart.subtotal, 0.0);
      expect(cart.isFreeDeliveryUnlocked, false);
      expect(cart.freeDeliveryProgress, 0.0);
    });

    test('Adding products increases quantity and subtotal', () {
      cart.addItem(sampleBanana);
      expect(cart.getQuantity('1'), 1);
      expect(cart.totalQuantity, 1);
      expect(cart.subtotal, 40.0);

      // Add another banana
      cart.addItem(sampleBanana);
      expect(cart.getQuantity('1'), 2);
      expect(cart.totalQuantity, 2);
      expect(cart.subtotal, 80.0);
    });

    test('Free delivery unlock threshold works correctly at ₹49', () {
      // Free delivery threshold is ₹49
      cart.addItem(sampleBanana); // ₹40
      expect(cart.isFreeDeliveryUnlocked, false);
      expect(cart.amountNeededForFreeDelivery, 9.0);

      cart.addItem(sampleMilk); // ₹40 + ₹35 = ₹75 >= ₹49
      expect(cart.isFreeDeliveryUnlocked, true);
      expect(cart.amountNeededForFreeDelivery, 0.0);
      expect(cart.freeDeliveryProgress, 1.0);
    });

    test('Removing single item decreases quantity or removes product', () {
      cart.addItem(sampleBanana);
      cart.addItem(sampleBanana);
      expect(cart.getQuantity('1'), 2);

      cart.removeSingleItem('1');
      expect(cart.getQuantity('1'), 1);

      cart.removeSingleItem('1');
      expect(cart.getQuantity('1'), 0);
      expect(cart.containsProduct('1'), false);
    });
  });
}
