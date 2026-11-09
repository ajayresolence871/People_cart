import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/models/cart_item.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/features/home/widgets/steal_deals_section.dart';
import 'package:people_cart/services/order_service.dart';

void main() {
  group('Catalog Integrity & Steal Deals Tests', () {
    final List<Product> sampleLiveProducts = [
      Product(
        id: '1',
        name: 'Fresh Bananas Robusta',
        description: '1 kg',
        price: 40.0,
        stockQuantity: 10,
        isAvailable: true,
      ),
      Product(
        id: '2',
        name: 'Farm Fresh Tomatoes Hybrid',
        description: '500 g',
        price: 18.0,
        stockQuantity: 15,
        isAvailable: true,
      ),
      Product(
        id: '3',
        name: 'Crunchy Corn Nacho Chips',
        description: '75 g',
        price: 10.0,
        stockQuantity: 8,
        isAvailable: true,
      ),
    ];

    testWidgets(
      'Steal Deals displays only real catalog products and no synthetic deal_* IDs',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<CartProvider>(
                create: (_) => CartProvider(),
                child: SingleChildScrollView(
                  child: StealDealsSection(baseProducts: sampleLiveProducts),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify "Steal Deals" header
        expect(find.text('Steal Deals'), findsOneWidget);

        // Verify that no synthetic deal_* items exist
        expect(find.text("Let's Try Curly Turns"), findsNothing);
        expect(find.text('Farmley Smokey BBQ Party Mix...'), findsNothing);

        // Verify real products are displayed with their original database prices
        expect(find.text('Fresh Bananas Robusta'), findsOneWidget);
        expect(find.text('₹40'), findsWidgets);
      },
    );

    testWidgets(
      'Steal Deals price store filter displays items within price threshold without mutating prices',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<CartProvider>(
                create: (_) => CartProvider(),
                child: SingleChildScrollView(
                  child: StealDealsSection(baseProducts: sampleLiveProducts),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "₹9 Store" (threshold <= 10.0)
        final nineStoreTab = find.text('₹9');
        expect(nineStoreTab, findsOneWidget);
        await tester.tap(nineStoreTab);
        await tester.pumpAndSettle();

        // Only ₹10 item should be visible; ₹40 item should not be in the list
        expect(find.text('Crunchy Corn Nacho Chips'), findsOneWidget);
        expect(find.text('Fresh Bananas Robusta'), findsNothing);
      },
    );

    testWidgets('Steal Deals renders honest empty state when no items match', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<CartProvider>(
              create: (_) => CartProvider(),
              child: const SingleChildScrollView(
                child: StealDealsSection(baseProducts: []),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No products matching this deal filter in the current catalog.',
        ),
        findsOneWidget,
      );
    });
  });

  group('OrderService Checkout Integrity Tests', () {
    test(
      'Rejects order if any item has a synthetic ID (prod_* or deal_*)',
      () async {
        final orderService = OrderService();
        final syntheticCartItem = CartItem(
          product: Product(
            id: 'prod_coconut',
            name: 'Synthetic Coconut',
            description: '1 pc',
            price: 49.0,
          ),
          quantity: 1,
        );

        final result = await orderService.placeOrder(
          items: [syntheticCartItem],
          totalAmount: 49.0,
          deliveryAddressId: 'address-test',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('not a valid catalog product'));
      },
    );

    test('Rejects order when items list is empty', () async {
      final orderService = OrderService();
      final result = await orderService.placeOrder(
        items: [],
        totalAmount: 0.0,
        deliveryAddressId: 'address-test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Cannot place an empty order'));
    });

    test(
      'Accepts valid catalog products in simulated/offline test environment',
      () async {
        final orderService = OrderService();
        final validItem = CartItem(
          product: Product(
            id: '1',
            name: 'Fresh Bananas Robusta',
            description: '1 kg',
            price: 40.0,
          ),
          quantity: 2,
        );

        final result = await orderService.placeOrder(
          items: [validItem],
          totalAmount: 80.0,
          deliveryAddressId: 'address-test',
        );

        expect(result.isSuccess, isTrue);
        expect(result.orderId, startsWith('PC-'));
      },
    );
  });
}
