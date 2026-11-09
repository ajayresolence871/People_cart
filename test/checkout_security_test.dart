import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/models/cart_item.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/features/cart/screens/cart_checkout_screen.dart';
import 'package:people_cart/features/cart/screens/order_success_screen.dart';
import 'package:people_cart/features/profile/screens/login_screen.dart';
import 'package:people_cart/features/product_detail/screens/product_detail_screen.dart';
import 'package:people_cart/services/order_service.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/features/address/models/address_model.dart';
import 'package:people_cart/features/address/providers/address_provider.dart';
import 'package:people_cart/features/address/services/address_service.dart';
import 'package:people_cart/core/widgets/catalog_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('A. Mocked Client & RPC Checkout Authorization Tests', () {
    final liveProduct = Product(
      id: '1',
      name: 'Fresh Bananas Robusta',
      description: '1 kg',
      price: 40.0,
      stockQuantity: 10,
      isAvailable: true,
    );

    test('1. Unauthenticated request is rejected immediately with authentication-required error', () async {
      bool rpcInvoked = false;
      final orderService = OrderService(
        isAuthenticated: false,
        rpcCaller: (fn, {params}) async {
          rpcInvoked = true;
          return {'success': true, 'order_id': 999};
        },
      );

      final item = CartItem(product: liveProduct, quantity: 1);
      final result = await orderService.placeOrder(
        items: [item],
        totalAmount: 40.0,
        deliveryAddressId: 'address-test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.orderId, isEmpty);
      expect(result.errorMessage, contains('Authentication required'));
      expect(
        rpcInvoked,
        isFalse,
        reason: 'Unauthenticated requests must never reach the RPC',
      );
    });

    test('2. Authenticated COD checkout routes through cash-only RPC without p_user_id', () async {
      String? capturedFunctionName;
      Map<String, dynamic>? capturedParams;

      final orderService = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async {
          capturedFunctionName = fn;
          capturedParams = params;
          return {
            'success': true,
            'order_id': 101,
            'subtotal': 80.0,
            'delivery_fee': 0.0,
            'total_amount': 80.0,
            'status': 'placed',
          };
        },
      );

      final item = CartItem(product: liveProduct, quantity: 2);
      final result = await orderService.placeOrder(
        items: [item],
        totalAmount: 80.0,
        deliveryAddressId: 'address-test',
        paymentMethod: 'cash_on_delivery',
      );

      expect(result.isSuccess, isTrue);
      expect(result.orderId, equals('101'));
      expect(result.totalAmount, equals(80.0));
      expect(capturedFunctionName, equals('create_order_cash_secure'));
      expect(capturedParams, isNotNull);

      // Verify that p_items is sent with integer product_id and quantity
      final itemsParam = capturedParams!['p_items'] as List;
      expect(itemsParam.first, equals({'product_id': 1, 'quantity': 2}));

      // Security requirement: Client MUST NOT transmit p_user_id
      expect(capturedParams!.containsKey('p_user_id'), isFalse);
      expect(capturedParams!['p_delivery_address_id'], 'address-test');
      expect(capturedParams!.containsKey('p_payment_method'), isFalse);
    });

    test(
      'simulated online payment cannot create an order through the COD service',
      () async {
        var rpcInvoked = false;
        final service = OrderService(
          isAuthenticated: true,
          rpcCaller: (fn, {params}) async {
            rpcInvoked = true;
            return {'success': true, 'order_id': 77};
          },
        );
        final result = await service.placeOrder(
          items: [CartItem(product: liveProduct, quantity: 1)],
          totalAmount: 40,
          deliveryAddressId: 'address-test',
          paymentMethod: 'online_simulated',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('verified Razorpay checkout'));
        expect(rpcInvoked, isFalse);
      },
    );

    test('Empty address ID is rejected before the RPC is called', () async {
      var rpcInvoked = false;
      final service = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async {
          rpcInvoked = true;
          return {'success': true, 'order_id': 1};
        },
      );
      final result = await service.placeOrder(
        items: [CartItem(product: liveProduct, quantity: 1)],
        totalAmount: 40,
        deliveryAddressId: '',
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.errorMessage,
        'Please select a delivery address to continue.',
      );
      expect(rpcInvoked, isFalse);
    });

    test('3. RPC exception returns failure and does NOT fall back to direct unvalidated inserts', () async {
      int rpcCallCount = 0;

      final orderService = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async {
          rpcCallCount++;
          throw const PostgrestException(
            message: 'Insufficient stock for "Fresh Bananas Robusta". Requested: 5, Available: 2',
            code: 'P0001',
          );
        },
      );

      final item = CartItem(product: liveProduct, quantity: 5);
      final result = await orderService.placeOrder(
        items: [item],
        totalAmount: 200.0,
        deliveryAddressId: 'address-test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.orderId, isEmpty);
      expect(result.errorMessage, contains('Insufficient stock'));
      expect(rpcCallCount, equals(1));
    });

    test('4. Malformed or unsuccessful RPC response is treated as checkout failure', () async {
      // 4a. Response is null
      final serviceNull = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async => null,
      );
      final item = CartItem(product: liveProduct, quantity: 1);
      final resultNull = await serviceNull.placeOrder(
        items: [item],
        totalAmount: 40.0,
        deliveryAddressId: 'address-test',
      );
      expect(resultNull.isSuccess, isFalse);
      expect(
        resultNull.errorMessage,
        contains('Server did not return a valid order confirmation'),
      );

      // 4b. Response has success: false
      final serviceFailure = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async => {
          'success': false,
          'error': 'Product is currently unavailable',
        },
      );
      final resultFailure = await serviceFailure.placeOrder(
        items: [item],
        totalAmount: 40.0,
        deliveryAddressId: 'address-test',
      );
      expect(resultFailure.isSuccess, isFalse);
      expect(
        resultFailure.errorMessage,
        equals('Product is currently unavailable'),
      );

      // 4c. Response has missing order_id
      final serviceNoId = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async => {'success': true, 'order_id': null},
      );
      final resultNoId = await serviceNoId.placeOrder(
        items: [item],
        totalAmount: 40.0,
        deliveryAddressId: 'address-test',
      );
      expect(resultNoId.isSuccess, isFalse);
    });

    test(
      '5. Empty carts and synthetic product IDs are rejected before RPC call',
      () async {
        bool rpcInvoked = false;
        final orderService = OrderService(
          isAuthenticated: true,
          rpcCaller: (fn, {params}) async {
            rpcInvoked = true;
            return {'success': true, 'order_id': 99};
          },
        );

        // Empty cart
        final resultEmpty = await orderService.placeOrder(
          items: [],
          totalAmount: 0.0,
          deliveryAddressId: 'address-test',
        );
        expect(resultEmpty.isSuccess, isFalse);
        expect(
          resultEmpty.errorMessage,
          contains('Cannot place an empty order'),
        );
        expect(rpcInvoked, isFalse);

        // Synthetic product ID (prod_*)
        final syntheticItem = CartItem(
          product: Product(id: 'prod_banana', name: 'Fake Banana', price: 20.0),
          quantity: 1,
        );
        final resultSynthetic = await orderService.placeOrder(
          items: [syntheticItem],
          totalAmount: 20.0,
          deliveryAddressId: 'address-test',
        );
        expect(resultSynthetic.isSuccess, isFalse);
        expect(
          resultSynthetic.errorMessage,
          contains('not a valid catalog product'),
        );
        expect(rpcInvoked, isFalse);
      },
    );

    test('6. Duplicate product IDs are aggregated client-side and checked against combined stock', () async {
      Map<String, dynamic>? sentParams;

      final orderService = OrderService(
        isAuthenticated: true,
        rpcCaller: (fn, {params}) async {
          sentParams = params;
          final items = params?['p_items'] as List;
          final item = items.first as Map<String, dynamic>;
          final totalRequested = item['quantity'] as int;

          // Available stock for product 1 is 10; combined requested is 12
          if (totalRequested > 10) {
            throw const PostgrestException(
              message: 'Insufficient stock for "Fresh Bananas Robusta". Requested: 12, Available: 10',
              code: 'P0001',
            );
          }
          return {'success': true, 'order_id': 102};
        },
      );

      // Two separate cart items for product ID 1 (quantity 6 each, total = 12)
      final item1 = CartItem(product: liveProduct, quantity: 6);
      final item2 = CartItem(product: liveProduct, quantity: 6);

      final result = await orderService.placeOrder(
        items: [item1, item2],
        totalAmount: 480.0,
        deliveryAddressId: 'address-test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Insufficient stock'));
      expect(result.errorMessage, contains('Requested: 12, Available: 10'));

      // Verify that the payload sent to RPC was aggregated into a single entry with quantity 12
      final sentItems = sentParams!['p_items'] as List;
      expect(sentItems.length, equals(1));
      expect(sentItems.first, equals({'product_id': 1, 'quantity': 12}));
    });

    test(
      '7. Invalid or non-positive product ID / quantity is rejected safely',
      () async {
        bool rpcInvoked = false;
        final orderService = OrderService(
          isAuthenticated: true,
          rpcCaller: (fn, {params}) async {
            rpcInvoked = true;
            return {'success': true, 'order_id': 103};
          },
        );

        // Zero quantity
        final zeroQtyItem = CartItem(product: liveProduct, quantity: 0);
        final resultZero = await orderService.placeOrder(
          items: [zeroQtyItem],
          totalAmount: 0.0,
          deliveryAddressId: 'address-test',
        );
        expect(resultZero.isSuccess, isFalse);
        expect(resultZero.errorMessage, contains('Invalid quantity 0'));
        expect(rpcInvoked, isFalse);

        // Non-integer product ID
        final invalidIdProduct = Product(
          id: 'non_numeric_id',
          name: 'Faulty Item',
          price: 10.0,
        );
        final invalidItem = CartItem(product: invalidIdProduct, quantity: 1);
        final resultInvalid = await orderService.placeOrder(
          items: [invalidItem],
          totalAmount: 10.0,
          deliveryAddressId: 'address-test',
        );
        expect(resultInvalid.isSuccess, isFalse);
        expect(resultInvalid.errorMessage, contains('invalid product ID'));
        expect(rpcInvoked, isFalse);
      },
    );

    test(
      '8. Live checkout failures NEVER generate simulated fallback IDs',
      () async {
        final connectedService = OrderService(
          isAuthenticated: true,
          rpcCaller: (fn, {params}) async {
            throw Exception('Connection refused by Supabase backend');
          },
        );

        final item = CartItem(product: liveProduct, quantity: 1);
        final result = await connectedService.placeOrder(
          items: [item],
          totalAmount: 40.0,
          deliveryAddressId: 'address-test',
        );

        expect(result.isSuccess, isFalse);
        expect(result.orderId, isEmpty);
        expect(result.orderId.startsWith('PC-'), isFalse);
        expect(result.errorMessage, contains('Connection refused'));
      },
    );
  });

  group('B. UI Checkout Flow & Cart Preservation Widget Tests', () {
    final liveProduct = Product(
      id: '1',
      name: 'Fresh Bananas Robusta',
      description: '1 kg',
      price: 40.0,
      stockQuantity: 10,
      isAvailable: true,
    );

    testWidgets(
      'cart product image uses catalog URL and opens product details',
      (tester) async {
        const imageUrl = 'https://example.com/fresh-bananas.jpg';
        final product = liveProduct.copyWith(imageUrl: imageUrl);
        final cartProvider = CartProvider()..addItem(product);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
                ChangeNotifierProvider<BudgetProvider>(
                  create: (_) => BudgetProvider(autoLoad: false),
                ),
              ],
              child: const CartCheckoutScreen(),
            ),
          ),
        );
        await tester.pump();

        final catalogImage = tester.widget<CatalogImage>(
          find.byType(CatalogImage).first,
        );
        expect(catalogImage.imageUrl, imageUrl);

        await tester.ensureVisible(find.text('Fresh Bananas Robusta'));
        await tester.tap(find.text('Fresh Bananas Robusta'));
        await tester.pumpAndSettle();

        expect(find.byType(ProductDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      '1. Unauthenticated customer is redirected to LoginScreen when tapping Pay button, cart preserved',
      (tester) async {
        final unauthenticatedOrderService = OrderService(
          isAuthenticated: false,
          rpcCaller: (fn, {params}) async => {'success': true, 'order_id': 99},
        );

        final cartProvider = CartProvider();
        cartProvider.addItem(liveProduct);
        expect(cartProvider.itemList.length, equals(1));
        expect(cartProvider.totalQuantity, equals(1));
        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
                ChangeNotifierProvider<BudgetProvider>(
                  create: (_) => BudgetProvider(),
                ),
              ],
              child: CartCheckoutScreen(
                orderService: unauthenticatedOrderService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Pay Cash/UPI" button
        final payButton = find.text('Pay Cash/UPI');
        expect(payButton, findsOneWidget);
        await tester.tap(payButton);
        await tester.pumpAndSettle();

        // Verify that LoginScreen is presented
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Sign in to People Cart'), findsOneWidget);

        // Verify cart items were NOT cleared while on LoginScreen
        expect(cartProvider.itemList.length, equals(1));

        // Dismiss login screen by tapping close button
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Verify returned to CartCheckoutScreen with cart items still preserved
        expect(find.byType(CartCheckoutScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(cartProvider.itemList.length, equals(1));
        expect(find.byType(OrderSuccessScreen), findsNothing);
      },
    );

    testWidgets(
      '2. Failed checkout preserves the cart and displays error message in UI',
      (tester) async {
        final failingOrderService = OrderService(
          isAuthenticated: true,
          rpcCaller: (fn, {params}) async {
            throw const PostgrestException(
              message: 'Insufficient stock for "Fresh Bananas Robusta". Requested: 2, Available: 0',
              code: 'P0001',
            );
          },
        );

        final cartProvider = CartProvider();
        cartProvider.addItem(liveProduct);
        expect(cartProvider.itemList.length, equals(1));
        expect(cartProvider.totalQuantity, equals(1));
        SharedPreferences.setMockInitialValues({});
        final addressProvider = AddressProvider(
          autoLoad: false,
          dataSource: _FakeAddressDataSource([
            AddressModel(
              id: 'address-1',
              tag: 'Home',
              houseNo: '10 Main Street',
              area: 'Downtown',
              recipientName: 'Test Customer',
              phoneNumber: '1234567890',
            ),
          ]),
        );
        await addressProvider.loadAddressesForUser('test-user-id');

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
                ChangeNotifierProvider<BudgetProvider>(
                  create: (_) => BudgetProvider(),
                ),
                ChangeNotifierProvider<AuthProvider>(
                  create: (_) => AuthProvider(isAuthenticatedForTesting: true),
                ),
                ChangeNotifierProvider<AddressProvider>.value(
                  value: addressProvider,
                ),
              ],
              child: CartCheckoutScreen(orderService: failingOrderService),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find "Pay Cash/UPI" button
        final payButton = find.text('Pay Cash/UPI');
        expect(payButton, findsOneWidget);

        await tester.tap(payButton);
        await tester.pump(); // Start async action

        // Settle SnackBar animations
        await tester.pumpAndSettle();

        // Verify that error SnackBar is shown
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Insufficient stock'), findsOneWidget);

        // Verify cart items were NOT cleared
        expect(cartProvider.itemList.length, equals(1));
        expect(cartProvider.totalQuantity, equals(1));

        // Verify that OrderSuccessScreen was NEVER reached
        expect(find.byType(OrderSuccessScreen), findsNothing);
      },
    );
  });
}

class _FakeAddressDataSource implements AddressDataSource {
  final List<AddressModel> _addresses;

  _FakeAddressDataSource(List<AddressModel> addresses)
    : _addresses = [...addresses];

  @override
  Future<List<AddressModel>> loadAddresses({
    required String expectedUserId,
  }) async => [..._addresses];

  @override
  Future<AddressModel> saveAddress(
    AddressModel address, {
    required String expectedUserId,
  }) async {
    _addresses.add(address);
    return address;
  }

  @override
  Future<void> deleteAddress(
    String addressId, {
    required String expectedUserId,
  }) async {}
}
