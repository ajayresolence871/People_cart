import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/people_mart_logo.dart';
import '../../../providers/auth_provider.dart';
import '../providers/admin_dashboard_provider.dart';
import 'admin_products_screen.dart';
import 'admin_delivery_assignments_screen.dart';
import 'customer_behavior_screen.dart';
import '../../../core/widgets/logout_confirmation_dialog.dart';
import '../widgets/admin_manage_orders_section.dart';
import '../services/admin_dashboard_service.dart';
import '../services/delivery_assignment_service.dart';
import '../services/admin_order_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  final AdminDashboardDataSource? dataSource;
  final AdminOrderDataSource? orderDataSource;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;

  const AdminDashboardScreen({
    super.key,
    this.dataSource,
    this.orderDataSource,
    this.deliveryAssignmentDataSource,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.profile == null ||
        auth.role != 'admin') {
      return const _AdminAccessDenied();
    }

    return ChangeNotifierProvider(
      create: (_) => AdminDashboardProvider(
        dataSource: dataSource ?? AdminDashboardService(),
      )..loadDashboard(),
      child: _AdminDashboardShell(
        orderDataSource: orderDataSource,
        deliveryAssignmentDataSource: deliveryAssignmentDataSource,
      ),
    );
  }
}

class _AdminDashboardShell extends StatefulWidget {
  final AdminOrderDataSource? orderDataSource;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;

  const _AdminDashboardShell({
    this.orderDataSource,
    this.deliveryAssignmentDataSource,
  });

  @override
  State<_AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<_AdminDashboardShell> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _overviewKey = GlobalKey();
  int _selectedDestination = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectDestination(int index) {
    setState(() => _selectedDestination = index);
    if (index != 0) return;
    final targetKey = _overviewKey;
    final targetContext = targetKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<AdminDashboardProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            titleSpacing: useRail ? 20 : 12,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: const PeopleMartLogoMark(size: 34),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'People Cart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: AppColors.accentPink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh dashboard',
                onPressed: dashboard.isLoading ? null : dashboard.loadDashboard,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => showLogoutConfirmationDialog(context),
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  backgroundColor: Colors.white,
                  selectedIndex: _selectedDestination,
                  onDestinationSelected: _selectDestination,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: Text('Inventory'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: Text('Insights'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.delivery_dining_outlined),
                      selectedIcon: Icon(Icons.delivery_dining_rounded),
                      label: Text('Delivery'),
                    ),
                  ],
                ),
              Expanded(
                child: _buildDashboardContent(dashboard, useRail: useRail),
              ),
            ],
          ),
          bottomNavigationBar: useRail ? null : _buildAdminBottomNav(),
        );
      },
    );
  }

  Widget _buildAdminBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedDestination,
      onDestinationSelected: _selectDestination,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFFEFF2),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.accentPink),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon:
              Icon(Icons.inventory_2_rounded, color: AppColors.accentPink),
          label: 'Inventory',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_rounded),
          selectedIcon: Icon(Icons.insights_rounded, color: AppColors.accentPink),
          label: 'Insights',
        ),
        NavigationDestination(
          icon: Icon(Icons.delivery_dining_rounded),
          selectedIcon:
              Icon(Icons.delivery_dining_rounded, color: AppColors.accentPink),
          label: 'Delivery',
        ),
      ],
    );
  }

  Widget _buildDashboardContent(
    AdminDashboardProvider dashboard, {
    required bool useRail,
  }) {
    if (_selectedDestination == 1) {
      return const AdminProductsScreen();
    }
    if (_selectedDestination == 2) {
      return const CustomerBehaviorScreen();
    }
    if (_selectedDestination == 3) {
      return const AdminDeliveryAssignmentsScreen();
    }

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: dashboard.loadDashboard,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(useRail ? 28 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: _overviewKey,
                  child: const _PageHeading(
                    title: 'Operations overview',
                    subtitle: 'A live view of orders and product availability.',
                  ),
                ),
                const SizedBox(height: 20),
                _OrderMetricsSection(provider: dashboard),
                const SizedBox(height: 14),
                _OrderTrendSection(provider: dashboard),
                const SizedBox(height: 18),
                AdminManageOrdersSection(
                  provider: dashboard,
                  orderDataSource: widget.orderDataSource,
                  deliveryAssignmentDataSource:
                      widget.deliveryAssignmentDataSource,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _OrderMetricsSection extends StatelessWidget {
  final AdminDashboardProvider provider;

  const _OrderMetricsSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final metrics = provider.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.isMetricsLoading && metrics == null)
          const _LoadingPanel(label: 'Loading order summary…')
        else if (provider.metricsError != null && metrics == null)
          _ErrorPanel(
            message: provider.metricsError!,
            onRetry: provider.loadDashboard,
          )
        else if (metrics != null) ...[
          if (provider.metricsError != null)
            _InlineError(message: provider.metricsError!),
          if (metrics.totalOrders == 0)
            const _InlineError(
              message: 'No orders are visible to this account. If orders exist in Supabase, check that the admin SELECT policy is applied; RLS can hide rows without returning an error.',
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 4 : 2;
              const spacing = 8.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _MetricCard(
                      label: 'Total orders',
                      value: '${metrics.totalOrders}',
                      icon: Icons.receipt_long_rounded,
                      tint: AppColors.giftBannerBg,
                      subtitle: 'All statuses',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _MetricCard(
                      label: 'Placed today',
                      value: '${metrics.ordersToday}',
                      icon: Icons.today_rounded,
                      tint: AppColors.accentPinkSoft,
                      subtitle: 'Created today',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _MetricCard(
                      label: 'Order value today',
                      value:
                          '₹${metrics.nonCancelledOrderValueToday.toStringAsFixed(0)}',
                      icon: Icons.currency_rupee_rounded,
                      tint: AppColors.badgeGreenLight,
                      subtitle: 'Excludes cancelled; not payment-confirmed',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _MetricCard(
                      label: 'Needs attention',
                      value: '${metrics.ordersByStatus['placed'] ?? 0}',
                      icon: Icons.warning_amber_rounded,
                      tint: AppColors.accentPinkSoft,
                      subtitle: 'Awaiting preparation',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Orders by status',
            icon: Icons.donut_small_rounded,
            child: provider.isMetricsLoading
                ? const LinearProgressIndicator(color: AppColors.accentPink)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metrics.ordersByStatus.entries
                        .map(
                          (entry) => _StatusPill(
                            status: entry.key,
                            count: entry.value,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ],
    );
  }
}

class _OrderTrendSection extends StatelessWidget {
  final AdminDashboardProvider provider;

  const _OrderTrendSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final metrics = provider.metrics;
    return _SectionCard(
      title: '7-day orders trend',
      icon: Icons.bar_chart_rounded,
      trailing: const Text(
        'Last 7 days',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      child: provider.isMetricsLoading && metrics == null
          ? const _LoadingPanel(label: 'Loading order trend…')
          : provider.metricsError != null && metrics == null
          ? _ErrorPanel(
              message: provider.metricsError!,
              onRetry: provider.loadDashboard,
            )
          : metrics == null
          ? const _EmptyPanel(message: 'Order trend is unavailable.')
          : metrics.dailyOrderCounts.isEmpty
          ? const _EmptyPanel(message: 'No seven-day trend data is available.')
          : SizedBox(
              height: 142,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxCount = metrics.dailyOrderCounts.fold<int>(
                    0,
                    (maximum, day) => day.count > maximum ? day.count : maximum,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in metrics.dailyOrderCounts)
                        Expanded(
                          child: Semantics(
                            label:
                                '${_formatWeekday(day.date)}: ${day.count} orders',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        height: maxCount == 0
                                            ? 4
                                            : (70 * day.count / maxCount)
                                                  .clamp(4, 70)
                                                  .toDouble(),
                                        width: constraints.maxWidth / 12,
                                        decoration: BoxDecoration(
                                          color:
                                              day.count == maxCount &&
                                                  maxCount > 0
                                              ? AppColors.accentPink
                                              : AppColors.primary.withValues(
                                                  alpha: 0.8,
                                                ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(6),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${day.count}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _formatWeekday(day.date),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final String? subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final int? count;

  const _StatusPill({required this.status, this.count});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'delivered' => AppColors.badgeGreen,
      'cancelled' => AppColors.textSecondary,
      'out_for_delivery' => AppColors.accentPink,
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count == null
            ? _formatStatus(status)
            : '${_formatStatus(status)}  $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final String label;

  const _LoadingPanel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentPink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;

  const _EmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentPinkSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentPinkSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Could not refresh this section: $message',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
      ),
    );
  }
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accentPink,
                  size: 36,
                ),
                SizedBox(height: 12),
                Text(
                  'Admin access required',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Sign in with an account whose profiles record has the admin role.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatStatus(String status) {
  return status
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}



String _formatWeekday(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[date.weekday - 1];
}
