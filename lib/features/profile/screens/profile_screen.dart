import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../address/providers/address_provider.dart';
import '../../address/widgets/address_selector_bottom_sheet.dart';
import '../../household/providers/household_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../quick_order/providers/quick_order_provider.dart';
import 'order_history_screen.dart';
import '../services/order_history_service.dart';
import '../../wishlist/screens/wishlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _orderCount = 0;
  double _totalSavings = 0.0;
  bool _hasLoadedStats = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedStats) {
      _hasLoadedStats = true;
      _loadUserStats();
    }
  }

  Future<void> _loadUserStats() async {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userId = auth?.user?.id ?? auth?.profile?.id;
    if (userId != null) {
      final orders = await OrderHistoryService().getOrders(userId: userId);
      if (mounted) {
        setState(() {
          _orderCount = orders.length;
          _totalSavings = _orderCount * 40.0;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _orderCount = 0;
          _totalSavings = 0.0;
        });
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of People Cart?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              AuthProvider? authProvider;
              try {
                authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
              } catch (_) {}

              AddressProvider? addressProvider;
              try {
                addressProvider = Provider.of<AddressProvider>(
                  context,
                  listen: false,
                );
              } catch (_) {}

              QuickOrderProvider? quickOrderProvider;
              try {
                quickOrderProvider = Provider.of<QuickOrderProvider>(
                  context,
                  listen: false,
                );
              } catch (_) {}

              // 1. Dismiss confirmation dialog
              Navigator.pop(dialogCtx);

              // 2. Clear user data from memory immediately
              addressProvider?.clearAddresses();
              quickOrderProvider?.clearModes();

              // 3. Trigger authentication sign out
              if (authProvider != null) {
                await authProvider.signOut();
              } else {
                try {
                  await Supabase.instance.client.auth.signOut().timeout(
                    const Duration(seconds: 2),
                    onTimeout: () {},
                  );
                } catch (_) {}
              }

              // Return to the root AuthGate so its signed-out state shows LoginScreen.
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showReferralDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.accentPink,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Refer & Earn Free Gift',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share your code with friends and family. Both of you unlock a Free Gift and ₹100 discount on the next delivery!',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.giftBannerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5D5EE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PEOPLE2026',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(text: 'PEOPLE2026'),
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Referral code "PEOPLE2026" copied to clipboard!',
                          ),
                          backgroundColor: AppColors.badgeGreen,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                      size: 14,
                      color: AppColors.accentPink,
                    ),
                    label: const Text(
                      'Copy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentPink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _showCouponsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Coupons & Offers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FDF9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.badgeGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.percent_rounded,
                    color: AppColors.badgeGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OFFERSAVE50',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: AppColors.badgeGreen,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Get ₹50 flat discount on orders above ₹680',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.badgeGreenLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: AppColors.badgeGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final authProvider = Provider.of<AuthProvider?>(context);

    final userFullName =
        authProvider?.profile?.fullName ??
        (authProvider?.user?.userMetadata?['full_name'] as String?) ??
        (authProvider?.user?.email?.split('@').first) ??
        'Ajay Reddy';
    final userEmail = authProvider?.user?.email ?? 'ajay@example.com';
    final userRole = (authProvider?.role ?? 'customer').toUpperCase();

    // Generate up to 2 uppercase initials
    String initials = 'PC';
    if (userFullName.trim().isNotEmpty) {
      final parts = userFullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0]
            .substring(0, parts[0].length >= 2 ? 2 : 1)
            .toUpperCase();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile & Account',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar circle
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF5E1B73)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userFullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentPinkSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 12,
                              color: AppColors.accentPink,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Role: $userRole',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Quick Stat Row (Dynamically populated from real user data)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Past Orders',
                  value: _orderCount == 1 ? '1 Order' : '$_orderCount Orders',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'Total Savings',
                  value: '₹${_totalSavings.toStringAsFixed(0)} Saved',
                  icon: Icons.savings_rounded,
                  color: AppColors.badgeGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'Household',
                  value: householdProvider.hasHousehold ? 'Active' : 'Solo',
                  icon: Icons.groups_rounded,
                  color: AppColors.accentPink,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Section 1: Orders & Addresses
          _buildMenuSection(
            title: 'ORDERS & DELIVERIES',
            items: [
              _MenuItem(
                icon: Icons.shopping_bag_outlined,
                title: 'My Orders & Invoices',
                subtitle: 'Track live orders, reorder past items & receipts',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderHistoryScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.favorite_border_rounded,
                title: 'My Wishlist',
                subtitle: 'View and shop your saved products',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishlistScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.location_on_outlined,
                title: 'Delivery Addresses',
                subtitle: 'Manage saved home, work and family addresses',
                onTap: () => AddressSelectorBottomSheet.show(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section 2: Smart Features
          _buildMenuSection(
            title: 'SMART SHOPPING ASSISTANTS',
            items: [
              _MenuItem(
                icon: Icons.shield_outlined,
                title: 'Budget Guardian',
                subtitle: budgetProvider.isEnabled
                    ? 'Active • Budget set to ₹${budgetProvider.budgetAmount.toStringAsFixed(0)}'
                    : 'Disabled • Turn ON inside cart to track limits',
                badgeText: budgetProvider.isEnabled ? 'ON' : 'OFF',
                badgeColor: budgetProvider.isEnabled
                    ? AppColors.badgeGreen
                    : AppColors.textMuted,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Budget Guardian is available inside your Cart page!',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.family_restroom_rounded,
                title: 'Household Shared Basket',
                subtitle: householdProvider.hasHousehold
                    ? '${householdProvider.household!.name} (${householdProvider.household!.memberCount} members)'
                    : 'Create or join a family basket to shop together',
                badgeText: householdProvider.hasHousehold
                    ? 'CONNECTED'
                    : 'INVITE',
                badgeColor: householdProvider.hasHousehold
                    ? AppColors.primary
                    : AppColors.accentPink,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open the Household tab from the bottom navigation!',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section 3: Promotions & Rewards
          _buildMenuSection(
            title: 'OFFERS & REWARDS',
            items: [
              _MenuItem(
                icon: Icons.card_giftcard_rounded,
                title: 'Refer & Earn Free Gift',
                subtitle: 'Invite friends using code PEOPLE2026',
                onTap: () => _showReferralDialog(context),
              ),
              _MenuItem(
                icon: Icons.local_offer_outlined,
                title: 'Available Coupons & Discounts',
                subtitle: 'View active promo codes like OFFERSAVE50',
                onTap: () => _showCouponsDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section 4: Support & About
          _buildMenuSection(
            title: 'HELP & SUPPORT',
            items: [
              _MenuItem(
                icon: Icons.headset_mic_outlined,
                title: '24x7 Customer Support',
                subtitle: 'Chat with support agent or request refund',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Support is always active! Reach us at support@peoplecart.com',
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About People Cart',
                subtitle: 'Version 1.0.0 (Zepto Quick-Commerce Prototype)',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'People Cart',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Zepto-inspired quick grocery delivery application built with Flutter, Provider, and Supabase.',
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section 5: Account Actions & Logout
          _buildMenuSection(
            title: 'ACCOUNT ACTIONS',
            items: [
              _MenuItem(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                subtitle: 'Sign out of your People Cart session',
                badgeText: 'EXIT',
                badgeColor: Colors.red.shade700,
                onTap: () => _showLogoutDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                for (int index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 1, indent: 56),
                  Builder(
                    builder: (context) {
                      final item = items[index];
                      return ListTile(
                        onTap: item.onTap,
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (item.badgeText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      item.badgeColor?.withValues(
                                        alpha: 0.12,
                                      ) ??
                                      AppColors.giftBannerBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.badgeText!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: item.badgeColor ?? AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });
}
