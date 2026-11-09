import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/features/budget_guardian/utils/budget_dialog_helper.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetDialogHelper Tests', () {
    late CartProvider cart;
    late BudgetProvider budget;
    late Product sampleBanana;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      cart = CartProvider();
      budget = BudgetProvider(autoLoad: false);
      sampleBanana = Product(id: '1', name: 'Fresh Bananas', price: 60.0);
    });

    Widget createTestApp(VoidCallback onAddPressed) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: budget),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: onAddPressed,
                  child: const Text('Add Banana'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('Adds normally when budget is disabled', (tester) async {
      budget.setEnabled(false);

      await tester.pumpWidget(
        createTestApp(() {
          // Inside a build context where button is pressed
        }),
      );

      final buttonFinder = find.text('Add Banana');
      expect(buttonFinder, findsOneWidget);

      await tester.pumpWidget(
        createTestApp(() {
          final element = tester.element(find.byType(ElevatedButton));
          BudgetDialogHelper.checkAndAdd(
            context: element,
            itemPrice: sampleBanana.price,
            onProceed: () => cart.addItem(sampleBanana),
          );
        }),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(cart.totalQuantity, 1);
      expect(cart.subtotal, 60.0);
      expect(find.text('Budget Exceeded'), findsNothing);
    });

    testWidgets('Shows popup when budget is exceeded and clicking No cancels addition', (tester) async {
      budget.setEnabled(true);
      budget.setBudgetAmount(50.0); // Budget is ₹50, item is ₹60

      await tester.pumpWidget(
        createTestApp(() {
          final element = tester.element(find.byType(ElevatedButton));
          BudgetDialogHelper.checkAndAdd(
            context: element,
            itemPrice: sampleBanana.price,
            onProceed: () => cart.addItem(sampleBanana),
          );
        }),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Popup is raised!
      expect(find.text('Budget Exceeded'), findsOneWidget);
      expect(find.text('No, Keep Budget'), findsOneWidget);
      expect(find.text('Yes, Continue'), findsOneWidget);

      // User taps "No"
      await tester.tap(find.text('No, Keep Budget'));
      await tester.pumpAndSettle();

      // Dialog dismissed, budget remains enabled, item NOT added
      expect(budget.isEnabled, true);
      expect(cart.totalQuantity, 0);
      expect(cart.subtotal, 0.0);
    });

    testWidgets('Shows popup when budget is exceeded and clicking Yes removes budget and adds item', (tester) async {
      budget.setEnabled(true);
      budget.setBudgetAmount(50.0);

      await tester.pumpWidget(
        createTestApp(() {
          final element = tester.element(find.byType(ElevatedButton));
          BudgetDialogHelper.checkAndAdd(
            context: element,
            itemPrice: sampleBanana.price,
            onProceed: () => cart.addItem(sampleBanana),
          );
        }),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Popup is raised!
      expect(find.text('Budget Exceeded'), findsOneWidget);

      // User taps "Yes, Continue"
      await tester.tap(find.text('Yes, Continue'));
      await tester.pumpAndSettle();

      // Budget is removed (disabled), item is added!
      expect(budget.isEnabled, false);
      expect(cart.totalQuantity, 1);
      expect(cart.subtotal, 60.0);
    });
  });
}
