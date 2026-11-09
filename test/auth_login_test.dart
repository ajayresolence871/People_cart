import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/providers/budget_provider.dart';
import 'package:people_cart/features/household/providers/household_provider.dart';
import 'package:people_cart/features/address/providers/address_provider.dart';
import 'package:people_cart/features/address/models/address_model.dart';
import 'package:people_cart/features/quick_order/providers/quick_order_provider.dart';
import 'package:people_cart/features/auth/screens/auth_gate.dart';
import 'package:people_cart/features/profile/screens/login_screen.dart';
import 'package:people_cart/features/profile/screens/profile_screen.dart';
import 'package:people_cart/features/navigation/main_navigation_screen.dart';
import 'package:people_cart/features/admin/screens/admin_dashboard_screen.dart';
import 'package:people_cart/features/admin/screens/delivery_partner_placeholder_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('A. UserProfile Model & Role Handling Tests', () {
    test('1. Parses UserProfile correctly with customer role', () {
      final json = {
        'id': 'u-1234',
        'full_name': 'Demo Customer',
        'role': 'customer',
        'created_at': '2026-10-30T10:00:00Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, equals('u-1234'));
      expect(profile.fullName, equals('Demo Customer'));
      expect(profile.role, equals('customer'));
      expect(profile.createdAt, isNotNull);
    });

    test(
      '2. Leaves a missing role unresolved instead of granting customer access',
      () {
        final json = {'id': 'u-5678', 'full_name': 'New User'};

        final profile = UserProfile.fromJson(json);
        expect(profile.id, equals('u-5678'));
        expect(profile.fullName, equals('New User'));
        expect(profile.role, isEmpty);
      },
    );

    test('3. Parses admin role without modifying string', () {
      final json = {
        'id': 'u-9999',
        'full_name': 'Store Admin',
        'role': 'admin',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.role, equals('admin'));
    });

    test('4. Normalizes supported role values', () {
      final profile = UserProfile.fromJson({
        'id': 'u-delivery',
        'role': ' Delivery_Partner ',
      });

      expect(profile.role, equals('delivery_partner'));
    });
  });

  group('B. AuthProvider State & Session Handling Tests', () {
    test('1. Unauthenticated provider reports isAuthenticated = false', () {
      final auth = AuthProvider(isAuthenticatedForTesting: false);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isLoading, isFalse);
      expect(auth.user, isNull);
      expect(auth.profile, isNull);
    });

    test('2. Authenticated provider exposes profile and role', () {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'auth-user-1',
          fullName: 'Manager Demo',
          role: 'customer',
        ),
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isLoading, isFalse);
      expect(auth.role, equals('customer'));
      expect(auth.profile?.fullName, equals('Manager Demo'));
    });

    test('3. Sign out clears authenticated state', () async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'auth-user-1',
          fullName: 'Manager Demo',
          role: 'customer',
        ),
      );

      expect(auth.isAuthenticated, isTrue);
      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.profile, isNull);
    });
  });

  group('C. AuthGate Gating & Navigation Tests', () {
    testWidgets(
      '1. Unauthenticated session displays LoginScreen and blocks shopping app',
      (tester) async {
        final auth = AuthProvider(isAuthenticatedForTesting: false);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const AuthGate(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify that LoginScreen is rendered
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Welcome Back!'), findsOneWidget);

        // Verify that MainNavigationScreen is NOT rendered
        expect(find.byType(MainNavigationScreen), findsNothing);
      },
    );

    testWidgets('2. Authenticated session displays MainNavigationScreen', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'u-1',
          fullName: 'Manager Demo',
          role: 'customer',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (_) => BudgetProvider(autoLoad: false),
              ),
              ChangeNotifierProvider(create: (_) => HouseholdProvider()),
              ChangeNotifierProvider(create: (_) => AddressProvider()),
              ChangeNotifierProvider(create: (_) => QuickOrderProvider()),
            ],
            child: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify shopping app is displayed
      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('3. Admin profile opens the admin dashboard', (tester) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'admin-1',
          fullName: 'Store Admin',
          role: 'admin',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
      expect(find.text('Operations overview'), findsOneWidget);
    });

    testWidgets('4. Delivery partner profile opens assigned orders', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'delivery-1',
          fullName: 'Delivery Partner',
          role: 'delivery_partner',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryPartnerPlaceholderScreen), findsOneWidget);
      expect(find.text('People Cart'), findsOneWidget);
      expect(find.text('Active Deliveries'), findsOneWidget);
    });

    testWidgets('Signing out a delivery partner returns to login', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'delivery-1',
          fullName: 'Delivery Partner',
          role: 'delivery_partner',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryPartnerPlaceholderScreen), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DeliveryPartnerPlaceholderScreen), findsNothing);
      expect(find.text('People Cart'), findsNothing);
    });

    testWidgets(
      '5. Missing profile is shown as an access error, not customer navigation',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          profileMissingForTesting: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const AuthGate(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile not found'), findsOneWidget);
        expect(find.byType(MainNavigationScreen), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Profile load error offers retry and does not route to customer app',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          profileLoadErrorForTesting: 'Network unavailable',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const AuthGate(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile could not be loaded'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(MainNavigationScreen), findsNothing);
      },
    );

    testWidgets(
      '7. Unsupported role does not fall back to customer navigation',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(
            id: 'unknown-1',
            role: 'store_manager',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const AuthGate(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Account access is not configured'), findsOneWidget);
        expect(find.byType(MainNavigationScreen), findsNothing);
      },
    );
  });

  group('D. LoginScreen Form & Validation Widget Tests', () {
    testWidgets(
      '1. Displays email, password, Login button, and Sign Up toggle',
      (tester) async {
        final auth = AuthProvider(isAuthenticatedForTesting: false);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byKey(const ValueKey('auth-submit-button')), findsOneWidget);
        expect(find.text('Welcome Back!'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);
      },
    );

    testWidgets('2. Rejects invalid email without @ symbol', (tester) async {
      final auth = AuthProvider(isAuthenticatedForTesting: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'),
        'invalidemail',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        '123456',
      );

      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit-button')));
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('3. Rejects password shorter than 6 characters', (
      tester,
    ) async {
      final auth = AuthProvider(isAuthenticatedForTesting: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter short password
      await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'),
        'demo@example.com',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');

      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit-button')));
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
    });

    testWidgets(
      '4. Toggling to Sign Up displays Full Name field and Create Account button',
      (tester) async {
        final auth = AuthProvider(isAuthenticatedForTesting: false);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Sign Up toggle
        await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
        await tester.pumpAndSettle();

        expect(find.text('Full Name'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('auth-submit-button')),
          findsOneWidget,
        );
        expect(find.text('Welcome Back!'), findsNothing);
      },
    );
  });

  group('E. ProfileScreen Display & Logout Tests', () {
    testWidgets(
      '1. Displays user name, initials, and role badge from AuthProvider',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(
            id: 'u-admin-1',
            fullName: 'Suresh Kumar',
            role: 'admin',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider(create: (_) => HouseholdProvider()),
                ChangeNotifierProvider(
                  create: (_) => BudgetProvider(autoLoad: false),
                ),
              ],
              child: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Suresh Kumar'), findsOneWidget);
        expect(find.text('SK'), findsOneWidget); // Initials
        expect(find.text('Role: ADMIN'), findsOneWidget); // Role badge
      },
    );

    testWidgets('2. Tapping Log Out shows confirmation dialog', (tester) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'u-1',
          fullName: 'Demo Customer',
          role: 'customer',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider(create: (_) => HouseholdProvider()),
              ChangeNotifierProvider(
                create: (_) => BudgetProvider(autoLoad: false),
              ),
            ],
            child: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Log Out button and tap it
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      final logoutTile = find.widgetWithText(ListTile, 'Log Out');
      expect(logoutTile, findsOneWidget);
      await tester.ensureVisible(logoutTile);
      await tester.pumpAndSettle();
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Are you sure you want to log out of People Cart?'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Log Out'), findsOneWidget);
    });

    testWidgets(
      '3. Confirming Log Out executes signOut and clears addresses cleanly',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(
            id: 'u-1',
            fullName: 'Demo Customer',
            role: 'customer',
          ),
        );
        final address = AddressProvider(autoLoad: false);
        await address.addAddress(
          AddressModel(
            id: 'addr_1',
            tag: 'Home',
            houseNo: '101',
            area: 'Madhapur',
            recipientName: 'Demo Customer',
            phoneNumber: '+91 99999 00000',
          ),
        );
        expect(address.addresses.length, 1);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<AddressProvider>.value(value: address),
                ChangeNotifierProvider(create: (_) => HouseholdProvider()),
                ChangeNotifierProvider(
                  create: (_) => BudgetProvider(autoLoad: false),
                ),
              ],
              child: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -800));
        await tester.pumpAndSettle();

        final logoutTile = find.widgetWithText(ListTile, 'Log Out');
        await tester.tap(logoutTile);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        final confirmBtn = find.widgetWithText(ElevatedButton, 'Log Out');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(auth.isAuthenticated, isFalse);
        expect(address.addresses, isEmpty);
      },
    );

    testWidgets('Logging out from Home Profile returns to LoginScreen', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'u-1',
          fullName: 'Demo Customer',
          role: 'customer',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(
              create: (_) => BudgetProvider(autoLoad: false),
            ),
            ChangeNotifierProvider(create: (_) => HouseholdProvider()),
            ChangeNotifierProvider(
              create: (_) => AddressProvider(autoLoad: false),
            ),
            ChangeNotifierProvider(create: (_) => QuickOrderProvider()),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pumpAndSettle();

      expect(auth.isAuthenticated, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsNothing);
    });
  });
}
