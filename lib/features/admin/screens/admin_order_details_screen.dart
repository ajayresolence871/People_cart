import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/admin_order_data.dart';
import '../models/delivery_assignment_data.dart';
import '../providers/admin_order_provider.dart';
import '../services/delivery_assignment_service.dart';
import '../widgets/order_payment_summary.dart';
import 'admin_delivery_assignments_screen.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final DeliveryAssignmentDataSource? deliveryAssignmentDataSource;

  const AdminOrderDetailsScreen({
    super.key,
    required this.orderId,
    this.deliveryAssignmentDataSource,
  });

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  DeliveryManagedOrder? _deliveryAssignment;
  List<DeliveryPartner> _availablePartners = [];
  bool _isAssigningPartner = false;
  String? _assignmentError;

  DeliveryAssignmentDataSource get _assignmentService =>
      widget.deliveryAssignmentDataSource ?? DeliveryAssignmentService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminOrderProvider>().loadOrderDetails(widget.orderId);
        _loadAssignment();
      }
    });
  }

  Future<void> _loadAssignment() async {
    try {
      final orders = await _assignmentService.loadOrders();
      final matching = orders.where((o) => o.id == widget.orderId).toList();
      final partners = await _assignmentService.loadPartners();
      final order = matching.isNotEmpty ? matching.first : null;
      final assignedPartnerId = order?.assignedPartnerId;
      final partner = assignedPartnerId == null
          ? null
          : partners.where((p) => p.id == assignedPartnerId).firstOrNull;
      if (mounted) {
        setState(() {
          _deliveryAssignment = order?.copyWith(
            assignedPartnerName:
                order.assignedPartnerName?.trim().isNotEmpty == true
                ? order.assignedPartnerName
                : partner?.displayName,
          );
          _availablePartners = partners;
          _assignmentError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _assignmentError = error.toString());
      }
    }
  }

  Future<void> _assignPartner() async {
    final partners = _availablePartners;
    final partnerId = await showDialog<String>(
      context: context,
      builder: (_) => DeliveryPartnerSelectionDialog(
        partners: partners,
        initialPartnerId: _deliveryAssignment?.assignedPartnerId,
      ),
    );
    if (partnerId == null || !mounted) return;

    setState(() => _isAssigningPartner = true);
    try {
      await _assignmentService.assignOrder(widget.orderId, partnerId);
      await _loadAssignment();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery partner updated successfully.'),
          backgroundColor: AppColors.badgeGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not assign partner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAssigningPartner = false);
    }
  }

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
    final provider = context.watch<AdminOrderProvider>();
    final order =
        (provider.orderDetailsId == widget.orderId &&
            provider.orderDetails != null)
        ? provider.orderDetails
        : (provider.orders?.where((o) => o.id == widget.orderId).firstOrNull ??
              provider.orderDetails);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh order',
            onPressed: provider.isDetailsLoading
                ? null
                : () {
                    provider.loadOrderDetails(widget.orderId);
                    _loadAssignment();
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: order == null
          ? _DetailsMessage(
              loading: provider.isDetailsLoading,
              error: provider.detailsError,
              onRetry: () {
                provider.loadOrderDetails(widget.orderId);
                _loadAssignment();
              },
            )
          : RefreshIndicator(
              color: AppColors.accentPink,
              onRefresh: () async {
                await provider.loadOrderDetails(widget.orderId);
                await _loadAssignment();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                children: [
                  // 1. Order Summary Card
                  _OrderSummaryCard(order: order),

                  const SizedBox(height: 12),

                  // 2. Admin Status Actions
                  _StatusActions(
                    order: order,
                    isUpdating: provider.isUpdating,
                    onSelect: (status) =>
                        _updateStatus(context, provider, order, status),
                  ),

                  const SizedBox(height: 12),

                  // 3. Ordered Products Card
                  _ItemsCard(order: order),

                  const SizedBox(height: 12),

                  // 4. Order Lifecycle Timeline Card
                  _OrderTimelineCard(status: order.status),

                  const SizedBox(height: 12),

                  // 5. Customer Details & Delivery Address Card
                  _CustomerDetailsCard(
                    customerName: order.customerName,
                    deliveryAddress: _deliveryAssignment?.deliveryAddress,
                  ),

                  const SizedBox(height: 12),

                  // 6. Delivery Partner Assignment Card
                  _DeliveryAssignmentCard(
                    assignment: _deliveryAssignment,
                    isAssigning: _isAssigningPartner,
                    onAssign: _availablePartners.isEmpty
                        ? null
                        : _assignPartner,
                    error: _assignmentError,
                  ),

                  const SizedBox(height: 12),

                  // 7. Payment Breakdown Card
                  _OrderPaymentCard(order: order),

                  if (provider.detailsError != null)
                    _InlineOrderError(message: provider.detailsError!),
                  if (provider.updateError != null)
                    _InlineOrderError(message: provider.updateError!),
                  if (provider.isUpdating)
                    const LinearProgressIndicator(color: AppColors.accentPink),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    AdminOrderProvider provider,
    AdminManagedOrder order,
    String nextStatus,
  ) async {
    if (nextStatus == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Cancel this order?'),
          content: Text(
            'Order #${order.id} will be marked as cancelled. This does not restore stock automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPink,
              ),
              child: const Text('Confirm cancellation'),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) return;
    }

    try {
      await provider.updateStatus(order.id, nextStatus);
      await _loadAssignment();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked ${AdminOrderStatus.label(nextStatus)}.'),
          backgroundColor: AppColors.badgeGreen,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update order status: $error'),
          backgroundColor: AppColors.accentPink,
        ),
      );
    }
  }
}

// ==========================================
// ORDER SUMMARY CARD
// ==========================================
class _OrderSummaryCard extends StatelessWidget {
  final AdminManagedOrder order;

  const _OrderSummaryCard({required this.order});

  @override
  Widget build(BuildContext context) => _OrderDetailsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Order #${order.id}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            _DetailsStatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _formatOrderDate(order.createdAt),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Divider(height: 20, color: Color(0xFFF3EDF7)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              order.totalAmount == null
                  ? '—'
                  : '₹${order.totalAmount!.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ==========================================
// ORDER TIMELINE CARD
// ==========================================
class _OrderTimelineCard extends StatelessWidget {
  final String status;

  const _OrderTimelineCard({required this.status});

  int _currentStep(String s) {
    switch (s.toLowerCase()) {
      case 'placed':
        return 0;
      case 'preparing':
        return 1;
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = status.toLowerCase() == 'cancelled';
    final step = _currentStep(status);

    return _OrderDetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Order Lifecycle',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFC62828),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order was cancelled and marked void.',
                      style: TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _TimelineStep(
              title: 'Order Placed',
              subtitle: 'Customer submitted order',
              isCompleted: step >= 0,
              isCurrent: step == 0,
              isLast: false,
            ),
            _TimelineStep(
              title: 'Store Packing',
              subtitle: 'Store packing grocery items',
              isCompleted: step >= 1,
              isCurrent: step == 1,
              isLast: false,
            ),
            _TimelineStep(
              title: 'Out for Delivery',
              subtitle: 'Partner picked up delivery box',
              isCompleted: step >= 2,
              isCurrent: step == 2,
              isLast: false,
            ),
            _TimelineStep(
              title: 'Delivered',
              subtitle: 'Package handed to customer',
              isCompleted: step >= 3,
              isCurrent: step == 3,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isCompleted
        ? (isCurrent ? AppColors.accentPink : AppColors.badgeGreen)
        : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted
                    ? dotColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
              ),
              child: isCompleted
                  ? Center(child: Icon(Icons.check, size: 12, color: dotColor))
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isCompleted
                    ? AppColors.badgeGreen.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w500,
                    color: isCompleted
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// CUSTOMER DETAILS CARD
// ==========================================
class _CustomerDetailsCard extends StatelessWidget {
  final String? customerName;
  final String? deliveryAddress;

  const _CustomerDetailsCard({
    required this.customerName,
    required this.deliveryAddress,
  });

  @override
  Widget build(BuildContext context) => _OrderDetailsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Customer & Delivery Details',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Customer Name:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                customerName?.trim().isNotEmpty == true
                    ? customerName!
                    : 'Customer Details on File',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 16, color: Color(0xFFF3EDF7)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Address:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                deliveryAddress?.trim().isNotEmpty == true
                    ? deliveryAddress!
                    : 'Saved delivery address',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ==========================================
// DELIVERY PARTNER ASSIGNMENT CARD
// ==========================================
class _DeliveryAssignmentCard extends StatelessWidget {
  final DeliveryManagedOrder? assignment;
  final bool isAssigning;
  final VoidCallback? onAssign;
  final String? error;

  const _DeliveryAssignmentCard({
    required this.assignment,
    required this.isAssigning,
    required this.onAssign,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final partnerName = assignment?.assignedPartnerName?.trim();
    final hasPartner =
        assignment?.assignedPartnerId != null &&
        assignment!.assignedPartnerId!.isNotEmpty;
    final partnerLabel = partnerName?.isNotEmpty == true
        ? partnerName!
        : hasPartner
        ? DeliveryPartner(id: assignment!.assignedPartnerId!).displayName
        : null;

    return _OrderDetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sports_motorsports_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Delivery Assignment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onAssign != null)
                TextButton.icon(
                  onPressed: isAssigning ? null : onAssign,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  icon: Icon(
                    hasPartner ? Icons.swap_horiz_rounded : Icons.add_rounded,
                    size: 16,
                  ),
                  label: Text(
                    hasPartner ? 'Reassign' : 'Assign Partner',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasPartner
                  ? const Color(0xFFF0FFF4)
                  : const Color(0xFFFAF7FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPartner
                    ? const Color(0xFFC8E6C9)
                    : const Color(0xFFEADBEE),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasPartner
                      ? Icons.delivery_dining_rounded
                      : Icons.person_search_rounded,
                  color: hasPartner
                      ? AppColors.badgeGreen
                      : AppColors.textMuted,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPartner
                            ? partnerLabel!
                            : 'No Delivery Partner Assigned',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: hasPartner
                              ? AppColors.badgeGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        hasPartner
                            ? 'Assigned partner'
                            : 'Tap assign to allocate order to a rider',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Could not load delivery assignment: $error',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
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

// ==========================================
// PAYMENT DETAILS CARD
// ==========================================
class _OrderPaymentCard extends StatelessWidget {
  final AdminManagedOrder order;

  const _OrderPaymentCard({required this.order});

  @override
  Widget build(BuildContext context) => _OrderDetailsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.payment_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text(
              'Payment Details',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OrderPaymentSummary(
          paymentMethod: order.paymentMethod,
          paymentStatus: order.paymentStatus,
        ),
        const Divider(height: 20, color: Color(0xFFF3EDF7)),
        _OrderPriceRow(
          label: 'Items Subtotal',
          value: order.totalAmount == null
              ? '—'
              : '₹${order.totalAmount!.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 6),
        const _OrderPriceRow(
          label: 'Delivery Fee',
          value: 'FREE',
          valueColor: AppColors.badgeGreen,
        ),
        const SizedBox(height: 8),
        _OrderPriceRow(
          label: 'Final Total',
          value: order.totalAmount == null
              ? '—'
              : '₹${order.totalAmount!.toStringAsFixed(2)}',
          emphasized: true,
        ),
      ],
    ),
  );
}

// ==========================================
// ORDERED ITEMS CARD
// ==========================================
class _ItemsCard extends StatelessWidget {
  final AdminManagedOrder order;

  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) => _OrderDetailsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ordered Products (${order.items.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (order.items.isEmpty)
          const Text(
            'No saved order items are available.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.giftBannerBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.imageUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.shopping_bag_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (item.productId == null) ...[
                          const SizedBox(height: 2),
                          const Text(
                            'Historical item snapshot',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} × ${item.unitPrice == null ? '₹--' : '₹${item.unitPrice!.toStringAsFixed(2)}'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.lineTotal == null
                        ? '—'
                        : '₹${item.lineTotal!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// ==========================================
// ADMIN STATUS ACTIONS CARD
// ==========================================
class _StatusActions extends StatelessWidget {
  final AdminManagedOrder order;
  final bool isUpdating;
  final ValueChanged<String> onSelect;

  const _StatusActions({
    required this.order,
    required this.isUpdating,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final nextStatuses = AdminOrderStatus.nextFor(order.status);
    if (nextStatuses.isEmpty) return const SizedBox.shrink();
    return _OrderDetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Actions',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final status in nextStatuses)
                status == 'cancelled'
                    ? OutlinedButton.icon(
                        onPressed: isUpdating ? null : () => onSelect(status),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: Text(AdminOrderStatus.label(status)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: isUpdating ? null : () => onSelect(status),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(AdminOrderStatus.label(status)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  final Widget child;

  const _OrderDetailsCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEADBEE), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _OrderPriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  const _OrderPriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
          fontSize: emphasized ? 14 : 12,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color:
              valueColor ??
              (emphasized ? AppColors.primary : AppColors.textPrimary),
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          fontSize: emphasized ? 16 : 13,
        ),
      ),
    ],
  );
}

class _DetailsStatusBadge extends StatelessWidget {
  final String status;

  const _DetailsStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'delivered' => AppColors.badgeGreen,
      'cancelled' => Colors.red.shade700,
      'out_for_delivery' => const Color(0xFF1565C0),
      'preparing' => const Color(0xFFE65100),
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Text(
            AdminOrderStatus.label(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsMessage extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const _DetailsMessage({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const CircularProgressIndicator(color: AppColors.accentPink)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 38, color: Colors.red),
                const SizedBox(height: 10),
                Text(
                  error ?? 'Order details could not be loaded.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
    ),
  );
}

class _InlineOrderError extends StatelessWidget {
  final String message;

  const _InlineOrderError({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      message,
      style: const TextStyle(color: Colors.red, fontSize: 12),
    ),
  );
}

String _formatOrderDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
