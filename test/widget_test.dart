import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/main.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/providers/budget_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(
                id: 'smoke-customer',
                role: 'customer',
              ),
            ),
          ),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
            create: (_) => BudgetProvider(autoLoad: false),
          ),
        ],
        child: const PeopleCartApp(),
      ),
    );

    // Verify bottom navigation items exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
  });
}
