import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetProvider Tests', () {
    late BudgetProvider budget;
    late CartProvider cart;
    late Product sampleBanana;
    late Product sampleMilk;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      budget = BudgetProvider(autoLoad: false);
      cart = CartProvider();
      sampleBanana = Product(id: '1', name: 'Fresh Bananas', price: 40.0);
      sampleMilk = Product(id: '2', name: 'Full Cream Milk', price: 35.0);
    });

    test('1. Default state is disabled with default amount 500', () {
      expect(budget.isEnabled, false);
      expect(budget.budgetAmount, 500.0);
    });

    test('2. Enabling and disabling changes isEnabled flag', () {
      budget.setEnabled(true);
      expect(budget.isEnabled, true);

      budget.toggleEnabled();
      expect(budget.isEnabled, false);

      budget.toggleEnabled();
      expect(budget.isEnabled, true);
    });

    test('3. Selecting each preset budget updates budget amount', () {
      for (final preset in BudgetProvider.presetBudgets) {
        final success = budget.setBudgetAmount(preset);
        expect(success, true);
        expect(budget.budgetAmount, preset);
      }
    });

    test('4. Setting a valid custom budget updates budget amount', () {
      final success = budget.setBudgetAmount(750.0);
      expect(success, true);
      expect(budget.budgetAmount, 750.0);
    });

    test('5. Rejecting zero, negative, or invalid budget values', () {
      expect(budget.setBudgetAmount(0.0), false);
      expect(budget.setBudgetAmount(-100.0), false);
      expect(budget.setBudgetAmount(double.nan), false);
      expect(budget.setBudgetAmount(double.infinity), false);
      // Preserves original amount
      expect(budget.budgetAmount, 500.0);
    });

    test('6. Calculating remaining budget correctly', () {
      budget.setBudgetAmount(100.0);
      // Empty cart (subtotal = 0)
      expect(budget.remainingBudget(0.0), 100.0);

      // Subtotal = 40 (remaining = 60)
      expect(budget.remainingBudget(40.0), 60.0);

      // Subtotal = 100 (remaining = 0)
      expect(budget.remainingBudget(100.0), 0.0);

      // Subtotal = 120 (remaining = 0, does not go negative)
      expect(budget.remainingBudget(120.0), 0.0);
    });

    test('7. Calculating over-budget amount correctly', () {
      budget.setBudgetAmount(100.0);

      // Within budget: overAmount is 0
      expect(budget.overBudgetAmount(50.0), 0.0);
      expect(budget.isOverBudget(50.0), false);

      // Exactly at budget: overAmount is 0
      expect(budget.overBudgetAmount(100.0), 0.0);
      expect(budget.isBudgetReached(100.0), true);
      expect(budget.isOverBudget(100.0), false);

      // Over budget: overAmount is 30
      expect(budget.overBudgetAmount(130.0), 30.0);
      expect(budget.isOverBudget(130.0), true);
    });

    test('8. Detecting the 80% warning threshold', () {
      budget.setBudgetAmount(100.0);

      // 70% used -> not near limit
      expect(budget.isNearLimit(70.0), false);

      // 80% used -> near limit
      expect(budget.isNearLimit(80.0), true);

      // 95% used -> near limit
      expect(budget.isNearLimit(95.0), true);

      // 100% used -> near limit
      expect(budget.isNearLimit(100.0), true);

      // 105% used -> over budget, not near limit
      expect(budget.isNearLimit(105.0), false);
    });

    test('9. Handling empty cart safely without division by zero', () {
      budget.setBudgetAmount(500.0);
      expect(budget.budgetUsage(0.0), 0.0);
      expect(budget.remainingBudget(0.0), 500.0);
      expect(budget.overBudgetAmount(0.0), 0.0);
      expect(budget.isOverBudget(0.0), false);
      expect(budget.isNearLimit(0.0), false);
    });

    test('10. Recalculating dynamically as cart quantities change', () {
      budget.setBudgetAmount(100.0);
      budget.setEnabled(true);

      // Step 1: Add Banana (₹40)
      cart.addItem(sampleBanana);
      expect(budget.remainingBudget(cart.subtotal), 60.0);
      expect(budget.isNearLimit(cart.subtotal), false);

      // Step 2: Add Milk (₹35) -> total = ₹75
      cart.addItem(sampleMilk);
      expect(budget.remainingBudget(cart.subtotal), 25.0);
      expect(budget.isNearLimit(cart.subtotal), false);

      // Step 3: Add second Milk (₹35) -> total = ₹110 -> Over budget!
      cart.addItem(sampleMilk);
      expect(cart.subtotal, 110.0);
      expect(budget.isOverBudget(cart.subtotal), true);
      expect(budget.overBudgetAmount(cart.subtotal), 10.0);
      expect(budget.remainingBudget(cart.subtotal), 0.0);

      // Step 4: Remove Milk -> total = ₹75 -> back within budget!
      cart.removeSingleItem(sampleMilk.id);
      expect(cart.subtotal, 75.0);
      expect(budget.isOverBudget(cart.subtotal), false);
      expect(budget.remainingBudget(cart.subtotal), 25.0);
    });

    test('11. Preserving budget amount across toggling and restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final providerA = BudgetProvider(autoLoad: false);

      providerA.setEnabled(true);
      providerA.setBudgetAmount(1000.0);

      // Disable temporarily
      providerA.setEnabled(false);
      // Preserves valid amount
      expect(providerA.budgetAmount, 1000.0);

      // Re-enable
      providerA.setEnabled(true);
      expect(providerA.budgetAmount, 1000.0);
    });

    test('12. Toggling Budget Guardian never changes cart contents', () {
      cart.addItem(sampleBanana);
      cart.addItem(sampleMilk);
      expect(cart.totalQuantity, 2);
      expect(cart.subtotal, 75.0);

      budget.setEnabled(true);
      budget.setBudgetAmount(50.0); // Now cart is over budget
      expect(budget.isOverBudget(cart.subtotal), true);

      // Cart still has exactly the same items
      expect(cart.totalQuantity, 2);
      expect(cart.subtotal, 75.0);

      // Disabling doesn't affect cart either
      budget.setEnabled(false);
      expect(cart.totalQuantity, 2);
      expect(cart.subtotal, 75.0);
    });
  });
}
