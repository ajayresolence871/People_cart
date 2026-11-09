import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/people_mart_logo.dart';
import '../../../providers/auth_provider.dart';
import '../../address/providers/address_provider.dart';
import '../../navigation/main_navigation_screen.dart';
import '../../profile/screens/login_screen.dart';
import '../../quick_order/providers/quick_order_provider.dart';
import '../../household/providers/household_provider.dart';
import '../../home/providers/customer_order_tracking_provider.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../admin/screens/delivery_partner_placeholder_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _syncedUserId;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider?>(context);
    final addressProvider = Provider.of<AddressProvider?>(
      context,
      listen: false,
    );

    if (auth == null) {
      return const _AuthAccessMessage(
        title: 'Unable to verify your account',
        message: 'Authentication is not available. Please restart the app and try again.',
      );
    }

    // 1. Loading ONLY during initial cold start / session restoration
    if (auth.isInitializing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PeopleMartLogo(width: 240, height: 130),
              const SizedBox(height: 6),
              const Text(
                '10-Minute Grocery Delivery',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Synchronize customer-only data when customer authentication transitions.
    final isCustomer =
        auth.isAuthenticated &&
        !auth.isProfileLoading &&
        auth.profile != null &&
        auth.role == 'customer';
    if (isCustomer) {
      final currentUserId = auth.user?.id ?? auth.profile?.id;
      if (currentUserId != null && currentUserId != _syncedUserId) {
        _syncedUserId = currentUserId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            addressProvider?.loadAddressesForUser(
              currentUserId,
              defaultName: auth.profile?.fullName,
            );
            final household = Provider.of<HouseholdProvider?>(
              context,
              listen: false,
            );
            household?.loadHouseholdData();
          }
        });
      }
    } else {
      if (_syncedUserId != null) {
        _syncedUserId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            addressProvider?.clearAddresses();
            final quickOrder = Provider.of<QuickOrderProvider?>(
              context,
              listen: false,
            );
            quickOrder?.clearModes();
            final household = Provider.of<HouseholdProvider?>(
              context,
              listen: false,
            );
            household?.clearHousehold();
            final tracking = Provider.of<CustomerOrderTrackingProvider?>(
              context,
              listen: false,
            );
            tracking?.refresh(userId: null);
          }
        });
      }
    }

    // 2. Unauthenticated: show LoginScreen (Guest access is prohibited)
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.isProfileLoading) {
      return _buildLoadingScreen();
    }

    if (auth.profileLoadError != null) {
      return _AuthAccessMessage(
        title: 'Profile could not be loaded',
        message: auth.profileLoadError!,
        actionLabel: 'Retry',
        onAction: auth.retryProfileLoad,
      );
    }

    if (auth.isProfileMissing || auth.profile == null) {
      return _AuthAccessMessage(
        title: 'Profile not found',
        message: 'This signed-in account does not have a People Cart profile. Contact support or try again.',
        actionLabel: 'Retry',
        onAction: auth.retryProfileLoad,
      );
    }

    switch (auth.role) {
      case 'customer':
        return const MainNavigationScreen();
      case 'admin':
        return const AdminDashboardScreen();
      case 'delivery_partner':
        return const DeliveryPartnerPlaceholderScreen();
      default:
        return _AuthAccessMessage(
          title: 'Account access is not configured',
          message:
              'The profile role "${auth.role.isEmpty ? 'missing' : auth.role}" is not supported. Contact an administrator.',
        );
    }
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accentPink),
      ),
    );
  }
}

class _AuthAccessMessage extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AuthAccessMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accentPink,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (actionLabel != null || auth?.isAuthenticated == true) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (actionLabel != null)
                        FilledButton(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: Text(actionLabel!),
                        ),
                      if (auth?.isAuthenticated == true)
                        TextButton(
                          onPressed: auth!.signOut,
                          child: const Text('Sign out'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
