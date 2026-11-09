import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/logout_confirmation_dialog.dart';
import '../../../core/widgets/people_mart_logo.dart';
import '../../../providers/auth_provider.dart';
import '../models/delivery_assignment_data.dart';
import '../providers/delivery_assignment_provider.dart';
import '../services/delivery_assignment_service.dart';
import 'delivery_partner_order_details_screen.dart';

class DeliveryPartnerPlaceholderScreen extends StatelessWidget {
  final DeliveryAssignmentDataSource? dataSource;

  const DeliveryPartnerPlaceholderScreen({super.key, this.dataSource});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final profile = auth?.profile;
    if (auth == null ||
        !auth.isAuthenticated ||
        profile == null ||
        auth.role != 'delivery_partner') {
      return const Scaffold(
        body: Center(
          child: Text(
            'Delivery partner access required.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      key: ValueKey(profile.id),
      create: (_) => DeliveryPartnerOrdersProvider(
        dataSource: dataSource ?? DeliveryAssignmentService(),
      )..load(),
      child: const _DeliveryPartnerOrdersScreen(),
    );
  }
}

class _DeliveryPartnerOrdersScreen extends StatefulWidget {
  const _DeliveryPartnerOrdersScreen();

  @override
  State<_DeliveryPartnerOrdersScreen> createState() =>
      _DeliveryPartnerOrdersScreenState();
}

class _DeliveryPartnerOrdersScreenState
    extends State<_DeliveryPartnerOrdersScreen> {
  int _selectedDestination = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final provider = context.watch<DeliveryPartnerOrdersProvider>();
    final orders = provider.orders;
    final allOrders = orders ?? const <DeliveryManagedOrder>[];
    final activeCount = allOrders.where((order) => order.isActive).length;
    final completedCount = allOrders
        .where((order) => order.status == 'delivered')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDestination == 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const PeopleMartLogoMark(size: 34),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'People Cart',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              )
            else
              Text(
                _selectedDestination == 1
                    ? 'Delivery history'
                    : 'Partner profile',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            if (_selectedDestination == 0)
              const Text(
                'DELIVERY PARTNER',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh deliveries',
            onPressed: provider.isLoading ? null : provider.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (_selectedDestination == 0)
            IconButton(
              tooltip: 'Partner profile',
              onPressed: () => setState(() => _selectedDestination = 2),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: switch (_selectedDestination) {
        1 => _PartnerHistoryTab(
          orders: orders
              ?.where(
                (order) =>
                    order.status == 'delivered' || order.status == 'cancelled',
              )
              .toList(),
          isLoading: provider.isLoading,
          error: provider.error,
          onRefresh: provider.load,
          onRetry: provider.load,
        ),
        2 => _PartnerProfilePage(
          name: auth.profile?.fullName,
          email: auth.user?.email,
          phone: auth.user?.phone,
          partnerId: auth.profile?.id,
          createdAt: auth.profile?.createdAt,
          assignedCount: orders == null ? null : allOrders.length,
          activeCount: orders == null ? null : activeCount,
          completedCount: orders == null ? null : completedCount,
          onSignOut: () => showLogoutConfirmationDialog(context),
          onHistory: () => setState(() => _selectedDestination = 1),
          onRefresh: provider.load,
        ),
        _ => Column(
          children: [
            _PartnerWelcomeCard(
              name: auth.profile?.fullName,
              returnedOrderCount: orders == null ? null : allOrders.length,
              completedCount: orders == null ? null : completedCount,
              activeCount: orders == null ? null : activeCount,
            ),
            const _PartnerPromoBanner(),
            const SizedBox(height: 10),
            const _PartnerSectionHeading(),
            Expanded(
              child: _PartnerOrdersTab(
                orders: orders?.where((order) => order.isActive).toList(),
                isLoading: provider.isLoading,
                error: provider.error,
                emptyMessage: 'No active deliveries assigned to you.',
                onRefresh: provider.load,
                onRetry: provider.load,
                updatingOrderId: provider.updatingOrderId,
                onUpdate: (order, status) =>
                    provider.updateStatus(order.id, status),
              ),
            ),
            if (provider.actionError != null)
              _ActionErrorBanner(message: provider.actionError!),
          ],
        ),
      },
      bottomNavigationBar: _buildPartnerBottomNav(),
    );
  }

  Widget _buildPartnerBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPartnerNavItem(
                index: 0,
                label: 'Home',
                icon: _selectedDestination == 0
                    ? Icons.home_rounded
                    : Icons.home_outlined,
              ),
              _buildPartnerNavItem(
                index: 1,
                label: 'History',
                icon: Icons.history_rounded,
              ),
              _buildPartnerNavItem(
                index: 2,
                label: 'Profile',
                icon: _selectedDestination == 2
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerNavItem({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedDestination == index;
    return InkWell(
      onTap: () => setState(() => _selectedDestination = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEFF2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? AppColors.accentPink
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.accentPink
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerWelcomeCard extends StatelessWidget {
  final String? name;
  final int? returnedOrderCount;
  final int? completedCount;
  final int? activeCount;

  const _PartnerWelcomeCard({
    required this.name,
    required this.returnedOrderCount,
    required this.completedCount,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = name?.trim();
    final greeting = trimmedName == null || trimmedName.isEmpty
        ? 'Welcome'
        : 'Hi, $trimmedName';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your assigned deliveries at a glance',
            style: TextStyle(color: Color(0xFFE9DDF0), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Assigned',
                  value: returnedOrderCount?.toString() ?? '—',
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: 'Completed',
                  value: completedCount?.toString() ?? '—',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: 'Active',
                  value: activeCount?.toString() ?? '—',
                  icon: Icons.delivery_dining_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerPromoBanner extends StatelessWidget {
  const _PartnerPromoBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, Color(0xFF7415A2)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Text(
            'Deliver smarter\nGrow together',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.25,
            ),
          ),
        ),
        Icon(Icons.delivery_dining, color: Color(0xFFFFB94D), size: 48),
        SizedBox(width: 8),
        CircleAvatar(
          radius: 17,
          backgroundColor: Colors.white,
          child: Icon(Icons.arrow_forward, color: AppColors.primary, size: 18),
        ),
      ],
    ),
  );
}

class _PartnerSectionHeading extends StatelessWidget {
  const _PartnerSectionHeading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Active Deliveries',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE9DDF0),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _PartnerOrdersTab extends StatelessWidget {
  final List<DeliveryManagedOrder>? orders;
  final bool isLoading;
  final String? error;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;
  final String? updatingOrderId;
  final Future<bool> Function(DeliveryManagedOrder, String)? onUpdate;

  const _PartnerOrdersTab({
    required this.orders,
    required this.isLoading,
    required this.error,
    this.emptyMessage = 'No active deliveries assigned to you.',
    required this.onRefresh,
    required this.onRetry,
    this.updatingOrderId,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && orders == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPink),
      );
    }

    if (error != null && (orders == null || orders!.isEmpty)) {
      return Center(
        child: _PartnerMessage(
          icon: Icons.error_outline,
          message: error!,
          action: onRetry,
        ),
      );
    }

    final items = orders ?? const <DeliveryManagedOrder>[];
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accentPink,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [_EmptyDeliveries(onRefresh: onRefresh)],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = items[index];
          final isUpdating = updatingOrderId == order.id;
          return _PartnerOrderCard(
            order: order,
            isUpdating: isUpdating,
            onUpdate: onUpdate != null
                ? (status) => onUpdate!(order, status)
                : null,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeliveryPartnerOrderDetailsScreen(
                    order: order,
                    isUpdating: isUpdating,
                    onUpdate: onUpdate != null
                        ? (status) => onUpdate!(order, status)
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PartnerHistoryTab extends StatefulWidget {
  final List<DeliveryManagedOrder>? orders;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;

  const _PartnerHistoryTab({
    required this.orders,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onRetry,
  });

  @override
  State<_PartnerHistoryTab> createState() => _PartnerHistoryTabState();
}

class _PartnerHistoryTabState extends State<_PartnerHistoryTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.orders == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPink),
      );
    }

    if (widget.error != null &&
        (widget.orders == null || widget.orders!.isEmpty)) {
      return Center(
        child: _PartnerMessage(
          icon: Icons.error_outline,
          message: widget.error!,
          action: widget.onRetry,
        ),
      );
    }

    final allItems = widget.orders ?? const <DeliveryManagedOrder>[];
    final items = _filter == 'all'
        ? allItems
        : allItems.where((order) => order.status == _filter).toList();

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  selectedColor: AppColors.accentPink,
                  labelStyle: TextStyle(
                    color: _filter == 'all'
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Delivered'),
                  selected: _filter == 'delivered',
                  selectedColor: AppColors.badgeGreen,
                  labelStyle: TextStyle(
                    color: _filter == 'delivered'
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _filter = 'delivered'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cancelled'),
                  selected: _filter == 'cancelled',
                  selectedColor: Colors.red.shade600,
                  labelStyle: TextStyle(
                    color: _filter == 'cancelled'
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _filter = 'cancelled'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No orders match this filter',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final order in items) ...[
              _PartnerOrderCard(
                order: order,
                isUpdating: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DeliveryPartnerOrderDetailsScreen(order: order),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _PartnerOrderCard extends StatelessWidget {
  final DeliveryManagedOrder order;
  final bool isUpdating;
  final Future<bool> Function(String)? onUpdate;
  final VoidCallback onTap;

  const _PartnerOrderCard({
    required this.order,
    required this.isUpdating,
    this.onUpdate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nextStatus = order.status == 'preparing'
        ? 'out_for_delivery'
        : order.status == 'out_for_delivery'
        ? 'delivered'
        : null;
    final nextLabel = order.status == 'preparing'
        ? 'Pick Up Order'
        : order.status == 'out_for_delivery'
        ? 'Mark Delivered'
        : null;

    final customer = order.customerName ?? 'Customer';
    final address = order.deliveryAddress ?? 'Address unavailable';
    final amountText = order.totalAmount != null
        ? '₹${order.totalAmount!.toStringAsFixed(0)}'
        : '—';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    customer,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    amountText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_orderAge(order.createdAt)} (${_formatDate(order.createdAt)})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${order.itemCount} items',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                  if (order.status == 'placed') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Waiting for store',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ] else if (nextStatus != null && onUpdate != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isUpdating
                            ? null
                            : () => onUpdate!(nextStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nextStatus == 'delivered'
                              ? AppColors.badgeGreen
                              : AppColors.accentPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isUpdating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                nextLabel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerProfilePage extends StatelessWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String? partnerId;
  final DateTime? createdAt;
  final int? assignedCount;
  final int? activeCount;
  final int? completedCount;
  final Future<void> Function() onSignOut;
  final VoidCallback onHistory;
  final Future<void> Function() onRefresh;

  const _PartnerProfilePage({
    required this.name,
    required this.email,
    this.phone,
    this.partnerId,
    this.createdAt,
    required this.assignedCount,
    this.activeCount,
    required this.completedCount,
    required this.onSignOut,
    required this.onHistory,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'Delivery partner';
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    final formattedId = partnerId != null && partnerId!.isNotEmpty
        ? 'P-${partnerId!.substring(0, partnerId!.length < 8 ? partnerId!.length : 8).toUpperCase()}'
        : 'P-RIDER01';

    final memberSince = createdAt != null
        ? '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')}/${createdAt!.year}'
        : 'Active';

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Header Card with Brand Gradient & Details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B0938), Color(0xFF4A154B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFF3EAF8),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials.isEmpty ? 'DP' : initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email ?? 'Email unavailable',
                  style: const TextStyle(
                    color: Color(0xFFE9DDF0),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'DELIVERY PARTNER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.badgeGreenLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 7,
                            color: AppColors.badgeGreen,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: AppColors.badgeGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. Delivery Statistics (3 Cards: Total Orders, Active, Delivered)
          Row(
            children: [
              Expanded(
                child: _ProfileStat(
                  label: 'Total Orders',
                  value: assignedCount?.toString() ?? '—',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.primary,
                  bgColor: const Color(0xFFF3EAF8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileStat(
                  label: 'Active',
                  value: activeCount?.toString() ?? '—',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFF1565C0),
                  bgColor: const Color(0xFFE3F2FD),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileStat(
                  label: 'Delivered',
                  value: completedCount?.toString() ?? '—',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.badgeGreen,
                  bgColor: AppColors.badgeGreenLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Partner Information Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Partner Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email Address',
                  value: email ?? 'Not available',
                ),
                if (phone != null && phone!.trim().isNotEmpty) ...[
                  const Divider(height: 18, color: Color(0xFFF3F0F6)),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: phone!.trim(),
                  ),
                ],
                const Divider(height: 18, color: Color(0xFFF3F0F6)),
                _InfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Partner ID',
                  value: formattedId,
                ),
                const Divider(height: 18, color: Color(0xFFF3F0F6)),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: memberSince,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Actions Section
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.giftBannerBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Delivery History',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'View completed and cancelled orders',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: onHistory,
                  ),
                  const Divider(
                    height: 1,
                    indent: 60,
                    color: Color(0xFFF3F0F6),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF1565C0),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Refresh Data',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Sync latest orders from server',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: onRefresh,
                  ),
                  const Divider(
                    height: 1,
                    indent: 60,
                    color: Color(0xFFF3F0F6),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentPinkSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.accentPink,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Sign out',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.accentPink,
                      ),
                    ),
                    subtitle: const Text(
                      'Log out of your partner account',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.accentPink,
                    ),
                    onTap: onSignOut,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isSuccess = status == 'delivered';
    final isCancelled = status == 'cancelled';
    final background = isSuccess
        ? AppColors.badgeGreenLight
        : isCancelled
        ? const Color(0xFFFFECEC)
        : AppColors.giftBannerBg;
    final foreground = isSuccess
        ? AppColors.badgeGreen
        : isCancelled
        ? Colors.red.shade700
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PartnerMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? action;

  const _PartnerMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (action != null)
              IconButton(
                tooltip: 'Retry',
                onPressed: action,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyDeliveries({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.giftBannerBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: AppColors.primary,
              size: 58,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'No Active Deliveries',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "You're all caught up! Check back later for new orders.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ),
  );
}

class _ActionErrorBanner extends StatelessWidget {
  final String message;

  const _ActionErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFECEC),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Status update failed: $message',
                style: TextStyle(color: Colors.red.shade900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _statusLabel(String status) => switch (status) {
  'placed' => 'Placed',
  'preparing' => 'Preparing',
  'out_for_delivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status.replaceAll('_', ' '),
};

String _formatDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} ${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _orderAge(DateTime? date) {
  if (date == null) return 'Time unavailable';
  final elapsed = DateTime.now().difference(date.toLocal());
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} mins ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} hours ago';
  return '${elapsed.inDays} days ago';
}
