import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/screens/auth_gate.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/budget_provider.dart';
import 'features/household/providers/household_provider.dart';
import 'features/address/providers/address_provider.dart';
import 'features/quick_order/providers/quick_order_provider.dart';
import 'features/wishlist/providers/wishlist_provider.dart';
import 'features/home/providers/customer_order_tracking_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with verified project credentials
  await Supabase.initialize(
    url: 'https://shkcpgzecfwpxstgbssy.supabase.co',
    publishableKey: 'sb_publishable_myxJ6mhXUY7o2jQqq1xknQ_BtfoHeAN',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              WishlistProvider(authProvider: context.read<AuthProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => HouseholdProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider(autoLoad: false)),
        ChangeNotifierProvider(create: (_) => QuickOrderProvider()),
        ChangeNotifierProvider(create: (_) => CustomerOrderTrackingProvider()),
      ],
      child: const PeopleCartApp(),
    ),
  );
}

class PeopleCartApp extends StatelessWidget {
  final Widget? home;
  const PeopleCartApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'People Cart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accentPink,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: home ?? const AuthGate(),
    );
  }
}
