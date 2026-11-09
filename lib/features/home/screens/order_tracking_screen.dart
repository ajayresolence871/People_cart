import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/customer_order_tracking.dart';
import '../providers/customer_order_tracking_provider.dart';
import '../widgets/customer_order_cancellation_action.dart';
import '../widgets/customer_order_tracking_card.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String userId;
  final CustomerOrderTrackingProvider provider;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.userId,
    required this.provider,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<CustomerOrderTracking?> _orderFuture;
  String? _statusOverride;

  @override
  void initState() {
    super.initState();
    _orderFuture = _loadOrder();
  }

  Future<CustomerOrderTracking?> _loadOrder() {
    return widget.provider.loadOrderDetails(
      orderId: widget.orderId,
      userId: widget.userId,
    );
  }

  Future<void> _retry() async {
    setState(() {
      _statusOverride = null;
      _orderFuture = _loadOrder();
    });
    await _orderFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<CustomerOrderTracking?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPink),
            );
          }
          if (snapshot.hasError) {
            return _MessageState(
              message:
                  'Could not load this order. Check your connection and retry.',
              actionLabel: 'Retry',
              onAction: _retry,
            );
          }
          final order = snapshot.data;
          if (order == null) {
            return const _MessageState(
              message: 'This order is not available for your account.',
            );
          }
          final displayOrder = _statusOverride == null
              ? order
              : order.copyWith(status: _statusOverride);
          return RefreshIndicator(
            color: AppColors.accentPink,
            onRefresh: _retry,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CustomerOrderTrackingCard(
                  order: displayOrder,
                  onTrackOrder: () {},
                  showTrackButton: false,
                ),
                CustomerOrderCancellationAction(
                  orderId: displayOrder.id,
                  status: displayOrder.status,
                  userId: widget.userId,
                  provider: widget.provider,
                  onStatusChanged: (status) {
                    if (mounted) setState(() => _statusOverride = status);
                  },
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'Order details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow('Order number', '#${displayOrder.id}'),
                      _DetailRow('Status', displayOrder.statusLabel),
                      if (displayOrder.createdAt != null)
                        _DetailRow(
                          'Placed',
                          _formatDateTime(displayOrder.createdAt!),
                        ),
                      _DetailRow(
                        'Total',
                        '₹${displayOrder.totalAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                if (displayOrder.deliveryAddress != null) ...[
                  const SizedBox(height: 12),
                  _DetailCard(
                    title: 'Delivery address',
                    child: Text(
                      displayOrder.deliveryAddress!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                if (displayOrder.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailCard(
                    title: 'Items',
                    child: Column(
                      children: [
                        for (final item in displayOrder.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child:
                                      item.imageUrl?.trim().isNotEmpty == true
                                      ? Image.network(
                                          item.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.shopping_bag_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${item.quantity} × ${item.productName}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '₹${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _DeliveryPartnerCard(order: displayOrder),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}

class _DeliveryPartnerCard extends StatelessWidget {
  final CustomerOrderTracking order;

  const _DeliveryPartnerCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final assigned = order.assignedDeliveryPartnerId?.isNotEmpty == true;
    final name = order.assignedDeliveryPartnerName?.trim();
    return _DetailCard(
      title: 'Delivery Partner Assigned',
      child: !assigned
          ? const Text('Delivery partner will be assigned soon.')
          : order.partnerDetailsUnavailable || name == null || name.isEmpty
          ? const Text('Partner details are temporarily unavailable.')
          : Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
