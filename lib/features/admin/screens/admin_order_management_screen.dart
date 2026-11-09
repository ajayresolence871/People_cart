import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/delivery_assignment_data.dart';
import '../providers/admin_order_provider.dart';
import '../providers/delivery_assignment_provider.dart';
import '../services/admin_order_service.dart';
import '../services/delivery_assignment_service.dart';
import '../widgets/admin_order_card.dart';
import 'admin_delivery_assignments_screen.dart';
import 'admin_order_details_screen.dart';
import 'delivery_map_screen.dart';

class AdminOrderManagementScreen extends StatelessWidget {
  final AdminOrderDataSource? dataSource;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;
  final String? initialStatus;

  const AdminOrderManagementScreen({
    super.key,
    this.dataSource,
    this.deliveryAssignmentDataSource,
    this.initialStatus,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.profile == null ||
        auth.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Admin access required.')),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AdminOrderProvider(dataSource: dataSource ?? AdminOrderService())
                ..loadOrders(status: initialStatus),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminDeliveryAssignmentProvider(
            dataSource:
                deliveryAssignmentDataSource ?? DeliveryAssignmentService(),
          )..load(),
        ),
      ],
      child: _AdminOrderManagementContent(
        initialStatus: initialStatus,
        deliveryAssignmentDataSource: deliveryAssignmentDataSource,
      ),
    );
  }
}

class _AdminOrderManagementContent extends StatefulWidget {
  final String? initialStatus;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;

  const _AdminOrderManagementContent({
    this.initialStatus,
    this.deliveryAssignmentDataSource,
  });

  @override
  State<_AdminOrderManagementContent> createState() =>
      _AdminOrderManagementContentState();
}

class _AdminOrderManagementContentState
    extends State<_AdminOrderManagementContent> {
  late String _selectedStatus = widget.initialStatus ?? 'all';
  String _selectedPayment = 'all';
  String _sortOrder = 'newest';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final ordersProvider = context.watch<AdminOrderProvider>();
    final assignments = context.watch<AdminDeliveryAssignmentProvider>();

    final List<DeliveryManagedOrder> allOrders;
    if (ordersProvider.orders != null) {
      allOrders = ordersProvider.orders!.map((adminOrder) {
        final matching = assignments.orders
            ?.where((a) => a.id == adminOrder.id)
            .firstOrNull;
        return DeliveryManagedOrder(
          id: adminOrder.id,
          createdAt: adminOrder.createdAt,
          totalAmount: adminOrder.totalAmount,
          status: adminOrder.status,
          assignedPartnerId: matching?.assignedPartnerId,
          assignedPartnerName: matching?.assignedPartnerName,
          customerName: adminOrder.customerName,
          paymentMethod: adminOrder.paymentMethod,
          paymentStatus: adminOrder.paymentStatus,
          itemCount: adminOrder.items.length,
        );
      }).toList();
    } else {
      allOrders = assignments.orders ?? const <DeliveryManagedOrder>[];
    }

    // Filter by status, payment, and search
    var filtered = allOrders.where((order) {
      // 1. Status Filter
      if (_selectedStatus != 'all') {
        if (order.status.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
      }

      // 2. Payment Method Filter
      if (_selectedPayment != 'all') {
        final method = order.paymentMethod?.toLowerCase() ?? '';
        if (_selectedPayment == 'cod' &&
            !method.contains('cod') &&
            !method.contains('cash')) {
          return false;
        }
        if (_selectedPayment == 'razorpay' &&
            !method.contains('razorpay') &&
            !method.contains('online')) {
          return false;
        }
      }

      // 3. Search Query (Order ID, Customer, Address)
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

    // Sort
    if (_sortOrder == 'newest') {
      filtered.sort(
        (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        ),
      );
    } else if (_sortOrder == 'oldest') {
      filtered.sort(
        (a, b) => (a.createdAt ?? DateTime(2000)).compareTo(
          b.createdAt ?? DateTime(2000),
        ),
      );
    } else if (_sortOrder == 'amount_high') {
      filtered.sort(
        (a, b) => (b.totalAmount ?? 0).compareTo(a.totalAmount ?? 0),
      );
    } else if (_sortOrder == 'amount_low') {
      filtered.sort(
        (a, b) => (a.totalAmount ?? 0).compareTo(b.totalAmount ?? 0),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Orders',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: assignments.isLoading ? null : assignments.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentPink,
        onRefresh: assignments.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            if (ordersProvider.loadError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ordersProvider.loadError!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ordersProvider.loadOrders(
                        status: _selectedStatus == 'all'
                            ? null
                            : _selectedStatus,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            // 1. Search Bar
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: const Color(0xFFEADBEE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by order ID, customer, address...',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Status Filter Tabs (Horizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusPill(
                    label: 'All',
                    isSelected: _selectedStatus == 'all',
                    onTap: () {
                      setState(() => _selectedStatus = 'all');
                      context.read<AdminOrderProvider>().loadOrders(
                        status: 'all' == 'all' ? null : 'all',
                      );
                    },
                  ),
                  _StatusPill(
                    label: 'Placed',
                    isSelected: _selectedStatus == 'placed',
                    onTap: () {
                      setState(() => _selectedStatus = 'placed');
                      context.read<AdminOrderProvider>().loadOrders(
                        status: 'placed' == 'all' ? null : 'placed',
                      );
                    },
                  ),
                  _StatusPill(
                    label: 'Preparing',
                    isSelected: _selectedStatus == 'preparing',
                    onTap: () {
                      setState(() => _selectedStatus = 'preparing');
                      context.read<AdminOrderProvider>().loadOrders(
                        status: 'preparing' == 'all' ? null : 'preparing',
                      );
                    },
                  ),
                  _StatusPill(
                    label: 'Out for Delivery',
                    isSelected: _selectedStatus == 'out_for_delivery',
                    onTap: () {
                      setState(() => _selectedStatus = 'out_for_delivery');
                      context.read<AdminOrderProvider>().loadOrders(
                        status: 'out_for_delivery' == 'all'
                            ? null
                            : 'out_for_delivery',
                      );
                    },
                  ),
                  _StatusPill(
                    label: 'Delivered',
                    isSelected: _selectedStatus == 'delivered',
                    onTap: () {
                      setState(() => _selectedStatus = 'delivered');
                      context.read<AdminOrderProvider>().loadOrders(
                        status: 'delivered' == 'all' ? null : 'delivered',
                      );
                    },
                  ),
                  _StatusPill(
                    label: 'Cancelled',
                    isSelected: _selectedStatus == 'cancelled',
                    onTap: () {
                      setState(() => _selectedStatus = 'cancelled');
                      context.read<AdminOrderProvider>().loadOrders(
                        status: 'cancelled' == 'all' ? null : 'cancelled',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Payment Filter & Sort Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Payment filter dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEADBEE)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPayment,
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Payment: All'),
                          ),
                          DropdownMenuItem(value: 'cod', child: Text('COD')),
                          DropdownMenuItem(
                            value: 'razorpay',
                            child: Text('Razorpay'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPayment = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Sort dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEADBEE)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortOrder,
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('Oldest'),
                          ),
                          DropdownMenuItem(
                            value: 'amount_high',
                            child: Text('Amount: High'),
                          ),
                          DropdownMenuItem(
                            value: 'amount_low',
                            child: Text('Amount: Low'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _sortOrder = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Order Count
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'order' : 'orders'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4. Loading or Empty or Cards
            if (assignments.isLoading && allOrders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AppColors.accentPink),
                ),
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Orders Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No orders match "$_searchQuery".'
                          : 'No orders found for this filter.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedStatus = 'all';
                          _selectedPayment = 'all';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPinkSoft,
                        foregroundColor: AppColors.accentPink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Clear Filters',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map((order) {
                return AdminOrderCard(
                  order: order,
                  isUpdating: assignments.updatingOrderIds.contains(order.id),
                  onViewDetails: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangeNotifierProvider<AuthProvider>.value(
                              value: context.read<AuthProvider>(),
                              child:
                                  ChangeNotifierProvider<
                                    AdminOrderProvider
                                  >.value(
                                    value: context.read<AdminOrderProvider>(),
                                    child: AdminOrderDetailsScreen(
                                      orderId: order.id,
                                      deliveryAssignmentDataSource:
                                          widget.deliveryAssignmentDataSource,
                                    ),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
