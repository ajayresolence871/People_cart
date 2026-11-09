import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/delivery_assignment_data.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_order_provider.dart';
import '../providers/delivery_assignment_provider.dart';
import '../screens/admin_delivery_assignments_screen.dart';
import '../screens/admin_order_details_screen.dart';
import '../screens/admin_order_management_screen.dart';
import '../screens/delivery_map_screen.dart';
import '../services/admin_order_service.dart';
import '../services/delivery_assignment_service.dart';
import 'admin_order_card.dart';

class AdminManageOrdersSection extends StatelessWidget {
  final AdminDashboardProvider provider;
  final AdminOrderDataSource? orderDataSource;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;

  const AdminManageOrdersSection({
    super.key,
    required this.provider,
    required this.orderDataSource,
    required this.deliveryAssignmentDataSource,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminDeliveryAssignmentProvider(
        dataSource: deliveryAssignmentDataSource ?? DeliveryAssignmentService(),
      )..load(),
      child: _ManageOrdersContent(
        provider: provider,
        orderDataSource: orderDataSource,
        deliveryAssignmentDataSource: deliveryAssignmentDataSource,
      ),
    );
  }
}

class _ManageOrdersContent extends StatefulWidget {
  final AdminDashboardProvider provider;
  final AdminOrderDataSource? orderDataSource;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;

  const _ManageOrdersContent({
    required this.provider,
    required this.orderDataSource,
    required this.deliveryAssignmentDataSource,
  });

  @override
  State<_ManageOrdersContent> createState() => _ManageOrdersContentState();
}

class _ManageOrdersContentState extends State<_ManageOrdersContent> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openOrderManagementScreen(BuildContext context, {String? status}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AuthProvider>.value(
          value: context.read<AuthProvider>(),
          child: AdminOrderManagementScreen(
            dataSource: widget.orderDataSource,
            initialStatus: status,
          ),
        ),
      ),
    );
  }

  Future<void> _assignPartner(
    BuildContext context,
    AdminDeliveryAssignmentProvider assignments,
    DeliveryManagedOrder order,
  ) async {
    final partners = assignments.partners ?? const <DeliveryPartner>[];
    final partnerId = await showDialog<String>(
      context: context,
      builder: (_) => DeliveryPartnerSelectionDialog(
        partners: partners,
        initialPartnerId: order.assignedPartnerId,
      ),
    );
    if (partnerId == null || !context.mounted) return;

    final succeeded = await assignments.assign(order.id, partnerId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? assignments.actionMessage ?? 'Delivery assignment saved.'
              : assignments.actionError ?? 'Assignment failed.',
        ),
        backgroundColor: succeeded ? AppColors.badgeGreen : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignments = context.watch<AdminDeliveryAssignmentProvider>();
    AdminOrderProvider? ordersProvider;
    try {
      ordersProvider = context.watch<AdminOrderProvider>();
    } catch (_) {}

    final List<DeliveryManagedOrder> allOrders;
    if (assignments.orders != null && assignments.orders!.isNotEmpty) {
      allOrders = assignments.orders!;
    } else if (ordersProvider?.orders != null &&
        ordersProvider!.orders!.isNotEmpty) {
      allOrders = ordersProvider.orders!
          .map(
            (o) => DeliveryManagedOrder(
              id: o.id,
              createdAt: o.createdAt,
              totalAmount: o.totalAmount,
              status: o.status,
              assignedPartnerId: null,
              customerName: o.customerName,
              paymentMethod: o.paymentMethod,
              paymentStatus: o.paymentStatus,
              itemCount: o.items.length,
            ),
          )
          .toList();
    } else if (widget.provider.recentOrders != null &&
        widget.provider.recentOrders!.isNotEmpty) {
      allOrders = widget.provider.recentOrders!
          .map(
            (o) => DeliveryManagedOrder(
              id: o.id,
              createdAt: o.createdAt,
              totalAmount: o.totalAmount,
              status: o.status,
              assignedPartnerId: null,
            ),
          )
          .toList();
    } else {
      allOrders = const <DeliveryManagedOrder>[];
    }

    // Compute live stats from actual Supabase orders
    final totalCount = allOrders.length;
    final newCount = allOrders.where((o) => o.status == 'placed').length;
    final preparingCount = allOrders
        .where((o) => o.status == 'preparing')
        .length;
    final outForDeliveryCount = allOrders
        .where((o) => o.status == 'out_for_delivery')
        .length;
    final deliveredCount = allOrders
        .where((o) => o.status == 'delivered')
        .length;
    final cancelledCount = allOrders
        .where((o) => o.status == 'cancelled')
        .length;

    // Filter orders by status and search query
    final filteredOrders = allOrders.where((order) {
      // 1. Status Filter
      if (_selectedFilter != 'all') {
        if (order.status.toLowerCase() != _selectedFilter.toLowerCase()) {
          return false;
        }
      }
      // 2. Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesId = order.id.toLowerCase().contains(query);
        final matchesCustomer =
            order.customerName?.toLowerCase().contains(query) ?? false;
        final matchesAddress =
            order.deliveryAddress?.toLowerCase().contains(query) ?? false;
        if (!matchesId && !matchesCustomer && !matchesAddress) return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBEE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Manage Orders + Live Orders badge + View All
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.giftBannerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        const SizedBox(
                          width: 0,
                          height: 0,
                          child: Text(
                            'Recent orders',
                            style: TextStyle(fontSize: 0),
                          ),
                        ),
                        const Text(
                          'Manage Orders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Monitor and manage customer orders.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openOrderManagementScreen(context),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.accentPink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. 6 Order Statistics Cards (Wrap or 2-row grid)
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _OrderStatCard(
                    title: 'All Orders',
                    count: totalCount,
                    icon: Icons.shopping_bag_outlined,
                    bgColor: const Color(0xFFFAF7FD),
                    iconColor: AppColors.primary,
                    width: itemWidth,
                    onTap: () => _openOrderManagementScreen(context),
                  ),
                  _OrderStatCard(
                    title: 'New',
                    count: newCount,
                    icon: Icons.access_time_rounded,
                    bgColor: const Color(0xFFFFF0F3),
                    iconColor: AppColors.accentPink,
                    width: itemWidth,
                    onTap: () =>
                        _openOrderManagementScreen(context, status: 'placed'),
                  ),
                  _OrderStatCard(
                    title: 'Preparing',
                    count: preparingCount,
                    icon: Icons.settings_outlined,
                    bgColor: const Color(0xFFF0F5FF),
                    iconColor: const Color(0xFF1565C0),
                    width: itemWidth,
                    onTap: () => _openOrderManagementScreen(
                      context,
                      status: 'preparing',
                    ),
                  ),
                  _OrderStatCard(
                    title: 'Out for Delivery',
                    count: outForDeliveryCount,
                    icon: Icons.delivery_dining_outlined,
                    bgColor: const Color(0xFFF0FFF4),
                    iconColor: const Color(0xFF0C8340),
                    width: itemWidth,
                    onTap: () => _openOrderManagementScreen(
                      context,
                      status: 'out_for_delivery',
                    ),
                  ),
                  _OrderStatCard(
                    title: 'Delivered',
                    count: deliveredCount,
                    icon: Icons.check_circle_outline_rounded,
                    bgColor: const Color(0xFFF0FFF4),
                    iconColor: const Color(0xFF0C8340),
                    width: itemWidth,
                    onTap: () => _openOrderManagementScreen(
                      context,
                      status: 'delivered',
                    ),
                  ),
                  _OrderStatCard(
                    title: 'Cancelled',
                    count: cancelledCount,
                    icon: Icons.cancel_outlined,
                    bgColor: const Color(0xFFFFF0F0),
                    iconColor: const Color(0xFFC62828),
                    width: itemWidth,
                    onTap: () => _openOrderManagementScreen(
                      context,
                      status: 'cancelled',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // 3. Search Field
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F5F9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEADBEE)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search by order ID or customer...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'all',
                  onTap: () => setState(() => _selectedFilter = 'all'),
                ),
                _StatusFilterChip(
                  label: 'Placed',
                  isSelected: _selectedFilter == 'placed',
                  onTap: () => setState(() => _selectedFilter = 'placed'),
                ),
                _StatusFilterChip(
                  label: 'Preparing',
                  isSelected: _selectedFilter == 'preparing',
                  onTap: () => setState(() => _selectedFilter = 'preparing'),
                ),
                _StatusFilterChip(
                  label: 'Out for Delivery',
                  isSelected: _selectedFilter == 'out_for_delivery',
                  onTap: () =>
                      setState(() => _selectedFilter = 'out_for_delivery'),
                ),
                _StatusFilterChip(
                  label: 'Delivered',
                  isSelected: _selectedFilter == 'delivered',
                  onTap: () => setState(() => _selectedFilter = 'delivered'),
                ),
                _StatusFilterChip(
                  label: 'Cancelled',
                  isSelected: _selectedFilter == 'cancelled',
                  onTap: () => setState(() => _selectedFilter = 'cancelled'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Order Cards List
          if (assignments.isLoading && allOrders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28.0),
                child: CircularProgressIndicator(color: AppColors.accentPink),
              ),
            )
          else if (filteredOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No orders match "$_searchQuery"'
                          : _selectedFilter == 'all'
                          ? 'No recent orders are visible. If orders exist in Supabase, verify the admin SELECT policy.'
                          : 'No orders with status "$_selectedFilter"',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredOrders.take(6).map((order) {
              final matchingPartner = (assignments.partners ?? [])
                  .where((p) => p.id == order.assignedPartnerId)
                  .firstOrNull;
              final effectiveOrder =
                  order.assignedPartnerName?.trim().isNotEmpty == true
                  ? order
                  : order.copyWith(
                      assignedPartnerName: matchingPartner?.displayName,
                    );
              return AdminOrderCard(
                order: effectiveOrder,
                isUpdating: assignments.updatingOrderIds.contains(order.id),
                onViewDetails: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => MultiProvider(
                        providers: [
                          ChangeNotifierProvider<AuthProvider>.value(
                            value: context.read<AuthProvider>(),
                          ),
                          ChangeNotifierProvider<AdminOrderProvider>(
                            create: (_) => AdminOrderProvider(
                              dataSource:
                                  widget.orderDataSource ?? AdminOrderService(),
                            )..loadOrders(),
                          ),
                        ],
                        child: AdminOrderDetailsScreen(
                          orderId: order.id,
                          deliveryAssignmentDataSource:
                              widget.deliveryAssignmentDataSource,
                        ),
                      ),
                    ),
                  );
                },
                onAssignPartner: () =>
                    _assignPartner(context, assignments, order),
                onTrackOrder: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => DeliveryMapScreen(order: order),
                    ),
                  );
                },
              );
            }),

          // 6. View All Footer Button
          if (filteredOrders.length > 6 || allOrders.length > 6) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _openOrderManagementScreen(
                  context,
                  status: _selectedFilter == 'all' ? null : _selectedFilter,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  'View all ${filteredOrders.length} orders',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderStatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final double width;
  final VoidCallback onTap;

  const _OrderStatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFEADBEE),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
