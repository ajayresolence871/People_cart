import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:people_cart/features/address/models/address_model.dart';
import 'package:people_cart/features/address/providers/address_provider.dart';
import 'package:people_cart/features/address/services/address_service.dart';
import 'package:people_cart/features/address/screens/add_address_screen.dart';
import 'package:people_cart/features/cart/screens/cart_checkout_screen.dart';
import 'package:people_cart/features/cart/screens/order_success_screen.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/services/order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'test-user-id';
  final product = Product(
    id: '1',
    name: 'Apples',
    price: 20,
    stockQuantity: 10,
    isAvailable: true,
  );

  Future<_Harness> pumpCheckout(
    WidgetTester tester, {
    required _FakeAddressDataSource addressSource,
    required OrderService orderService,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final addressProvider = AddressProvider(
      autoLoad: false,
      dataSource: addressSource,
    );
    await addressProvider.loadAddressesForUser(userId);
    final authProvider = AuthProvider(isAuthenticatedForTesting: true);
    final cartProvider = CartProvider()..addItem(product);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<AddressProvider>.value(value: addressProvider),
          ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
        ],
        child: MaterialApp(
          home: CartCheckoutScreen(orderService: orderService),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(
      addressProvider: addressProvider,
      cartProvider: cartProvider,
    );
  }

  OrderService serviceWithRpc(
    Future<dynamic> Function(String, {Map<String, dynamic>? params}) rpc,
  ) {
    return OrderService(isAuthenticated: true, rpcCaller: rpc);
  }

  testWidgets('missing address prompts customer to add one during checkout', (
    tester,
  ) async {
    var rpcCalls = 0;
    await pumpCheckout(
      tester,
      addressSource: _FakeAddressDataSource(),
      orderService: serviceWithRpc((name, {params}) async {
        rpcCalls++;
        return {'success': true, 'order_id': 1};
      }),
    );

    expect(
      find.text('Please select a delivery address to continue.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Pay Cash/UPI'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Please select a delivery address to continue.'),
      findsNWidgets(2),
    );
    expect(rpcCalls, 0);

    await tester.tap(find.text('Add address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AddAddressScreen), findsOneWidget);
    expect(rpcCalls, 0);
  });

  testWidgets('incomplete selected address blocks checkout', (tester) async {
    var rpcCalls = 0;
    final invalid = _address(id: 'bad-address', houseNo: '');
    final harness = await pumpCheckout(
      tester,
      addressSource: _FakeAddressDataSource(addresses: [invalid]),
      orderService: serviceWithRpc((name, {params}) async {
        rpcCalls++;
        return {'success': true, 'order_id': 1};
      }),
    );

    expect(harness.addressProvider.selectedAddress, isNotNull);
    expect(harness.addressProvider.hasValidSelectedAddressFor(userId), isFalse);
    await tester.tap(find.text('Pay Cash/UPI'));
    await tester.pumpAndSettle();

    expect(rpcCalls, 0);
    expect(
      find.text('Please select a delivery address to continue.'),
      findsWidgets,
    );
  });

  testWidgets('address-loading failure blocks checkout and can be retried', (
    tester,
  ) async {
    var rpcCalls = 0;
    final source = _FakeAddressDataSource(error: StateError('offline'));
    final harness = await pumpCheckout(
      tester,
      addressSource: source,
      orderService: serviceWithRpc((name, {params}) async {
        rpcCalls++;
        return {'success': true, 'order_id': 1};
      }),
    );

    expect(harness.addressProvider.loadError, isNotNull);
    await tester.tap(find.text('Pay Cash/UPI'));
    await tester.pumpAndSettle();

    expect(rpcCalls, 0);
    expect(
      find.text(
        'Could not load your delivery addresses. Retry before checkout.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('valid selected address is passed to the secure RPC', (
    tester,
  ) async {
    Map<String, dynamic>? sentParameters;
    final harness = await pumpCheckout(
      tester,
      addressSource: _FakeAddressDataSource(
        addresses: [
          _address(id: 'home-address'),
          AddressModel(
            id: 'valid-address',
            tag: 'Work',
            houseNo: '20 Side Street',
            area: 'Uptown',
            recipientName: 'Test Customer',
            phoneNumber: '1234567890',
          ),
        ],
      ),
      orderService: serviceWithRpc((name, {params}) async {
        sentParameters = params;
        return {'success': true, 'order_id': 42};
      }),
    );

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 Side Street, Uptown'));
    await tester.pumpAndSettle();
    expect(harness.addressProvider.selectedAddress?.id, 'valid-address');

    await tester.tap(find.text('Pay Cash/UPI'));
    await tester.pumpAndSettle();

    expect(sentParameters?['p_delivery_address_id'], 'valid-address');
    expect(find.byType(OrderSuccessScreen), findsOneWidget);
  });

  testWidgets('checkout success keeps its root route for logout routing', (
    tester,
  ) async {
    await pumpCheckout(
      tester,
      addressSource: _FakeAddressDataSource(
        addresses: [_address(id: 'valid-address')],
      ),
      orderService: serviceWithRpc(
        (name, {params}) async => {'success': true, 'order_id': 44},
      ),
    );

    await tester.tap(find.text('Pay Cash/UPI'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderSuccessScreen), findsOneWidget);

    await tester.tap(find.text('Continue Shopping'));
    await tester.pumpAndSettle();

    expect(find.byType(CartCheckoutScreen), findsOneWidget);
    expect(find.byType(OrderSuccessScreen), findsNothing);
  });

  testWidgets('repeated taps do not submit checkout twice', (tester) async {
    var rpcCalls = 0;
    final response = Completer<dynamic>();
    await pumpCheckout(
      tester,
      addressSource: _FakeAddressDataSource(
        addresses: [_address(id: 'valid-address')],
      ),
      orderService: serviceWithRpc((name, {params}) {
        rpcCalls++;
        return response.future;
      }),
    );

    await tester.tap(find.text('Pay Cash/UPI'));
    await tester.pump();
    await tester.tap(find.text('Pay Online'));
    await tester.pump();
    expect(rpcCalls, 1);

    response.complete({'success': true, 'order_id': 43});
    await tester.pumpAndSettle();
    expect(find.byType(OrderSuccessScreen), findsOneWidget);
  });

  testWidgets('order success avoids unsupported delivery claims', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OrderSuccessScreen(
          orderId: '42',
          totalAmount: 80,
          itemCount: 2,
          paymentMethod: 'razorpay',
        ),
      ),
    );

    expect(
      find.text('Your order status is available from Home.'),
      findsOneWidget,
    );
    expect(find.text('Arriving in 10 minutes'), findsNothing);
    expect(find.text('Delivery partner assigned to your order'), findsNothing);
    expect(find.text('Razorpay (Test Mode)'), findsOneWidget);
    expect(find.text('₹80.00'), findsOneWidget);
  });
}

AddressModel _address({required String id, String houseNo = '10 Main Street'}) {
  return AddressModel(
    id: id,
    tag: 'Home',
    houseNo: houseNo,
    area: 'Downtown',
    recipientName: 'Test Customer',
    phoneNumber: '1234567890',
  );
}

class _Harness {
  final AddressProvider addressProvider;
  final CartProvider cartProvider;

  const _Harness({required this.addressProvider, required this.cartProvider});
}

class _FakeAddressDataSource implements AddressDataSource {
  final List<AddressModel> _addresses;
  final Object? error;

  _FakeAddressDataSource({List<AddressModel> addresses = const [], this.error})
    : _addresses = [...addresses];

  @override
  Future<List<AddressModel>> loadAddresses({
    required String expectedUserId,
  }) async {
    if (error != null) throw error!;
    return [..._addresses];
  }

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
  }) async {
    _addresses.removeWhere((address) => address.id == addressId);
  }
}
