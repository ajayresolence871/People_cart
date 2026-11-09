import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/features/address/providers/address_provider.dart';
import 'package:people_cart/features/cart/screens/cart_checkout_screen.dart';
import 'package:people_cart/features/household/providers/household_provider.dart';
import 'package:people_cart/features/navigation/main_navigation_screen.dart';
import 'package:people_cart/features/quick_order/providers/quick_order_provider.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Empty Cart Navigation Tests', () {
    testWidgets('1. Tapping Start Shopping on empty cart tab redirects back to HomeScreen without a blank screen', (tester) async {
      final cart = CartProvider();
      final auth = AuthProvider(isAuthenticatedForTesting: true);
      final budget = BudgetProvider(autoLoad: false);
      final household = HouseholdProvider(autoLoad: false);
      final address = AddressProvider(autoLoad: false);
      final quickOrder = QuickOrderProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<CartProvider>.value(value: cart),
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<BudgetProvider>.value(value: budget),
              ChangeNotifierProvider<HouseholdProvider>.value(value: household),
              ChangeNotifierProvider<AddressProvider>.value(value: address),
              ChangeNotifierProvider<QuickOrderProvider>.value(value: quickOrder),
            ],
            child: const MainNavigationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Cart tab in the bottom navigation bar
      final cartNavTab = find.text('Cart');
      expect(cartNavTab, findsOneWidget);
      await tester.tap(cartNavTab);
      await tester.pumpAndSettle();

      // Verify Empty Cart view is displayed
      expect(find.text('Your cart is empty'), findsOneWidget);
      final startShoppingBtn = find.text('Start Shopping');
      expect(startShoppingBtn, findsOneWidget);

      // Tap "Start Shopping"
      await tester.tap(startShoppingBtn);
      await tester.pumpAndSettle();

      // Verify that we are back on HomeScreen and NOT a blank screen
      expect(find.text('Your cart is empty'), findsNothing);
      expect(find.text('Categories'), findsWidgets);
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('2. Standalone CartCheckoutScreen executes onStartShopping callback when provided', (tester) async {
      bool onStartShoppingCalled = false;
      bool onBackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(create: (_) => BudgetProvider(autoLoad: false)),
            ],
            child: CartCheckoutScreen(
              onStartShopping: () => onStartShoppingCalled = true,
              onBack: () => onBackCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);

      // Tap Start Shopping
      await tester.tap(find.text('Start Shopping'));
      await tester.pumpAndSettle();

      expect(onStartShoppingCalled, isTrue);

      // Tap top-left back icon
      final backBtn = find.byIcon(Icons.arrow_back_ios_new);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(onBackCalled, isTrue);
    });
  });
}
