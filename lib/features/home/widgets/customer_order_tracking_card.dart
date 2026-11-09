import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../models/customer_order_tracking.dart';
import '../providers/customer_order_tracking_provider.dart';

class ActiveOrderTrackingSection extends StatelessWidget {
  final String? userId;
  final ValueChanged<CustomerOrderTracking> onTrackOrder;

  const ActiveOrderTrackingSection({
    super.key,
    required this.userId,
    required this.onTrackOrder,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CustomerOrderTrackingProvider?>(context);
    if (provider == null) return const SizedBox.shrink();
    if (provider.requestedUserId != userId) {
      return userId == null
          ? const SizedBox.shrink()
          : const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accentPink,
                backgroundColor: AppColors.accentPinkSoft,
              ),
            );
    }

    final order = provider.currentOrder;
    if (order != null && !order.isActive) {
      return const SizedBox.shrink();
    }
    if (order != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            CustomerOrderTrackingCard(
              order: order,
              onTrackOrder: () => onTrackOrder(order),
            ),
            if (provider.errorMessage != null)
              _InlineTrackingError(
                onRetry: () => provider.refresh(userId: userId),
              ),
          ],
        ),
      );
    }

    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: AppColors.accentPink,
          backgroundColor: AppColors.accentPinkSoft,
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _InlineTrackingError(
          onRetry: () => provider.refresh(userId: userId),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class CustomerOrderTrackingCard extends StatelessWidget {
  final CustomerOrderTracking order;
  final VoidCallback onTrackOrder;
  final bool showTrackButton;

  const CustomerOrderTrackingCard({
    super.key,
    required this.order,
    required this.onTrackOrder,
    this.showTrackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.isCancelled;
    final statusIcon = switch (order.status.toLowerCase()) {
      'placed' => Icons.receipt_long_outlined,
      'preparing' => Icons.inventory_2_outlined,
      'out_for_delivery' => Icons.local_shipping_outlined,
      'delivered' => Icons.check_circle_outline,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.info_outline,
    };
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DDF0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.accentPinkSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCancelled
                      ? Icons.cancel_outlined
                      : Icons.local_shipping_outlined,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.heading,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Order #${order.id}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? const Color(0xFFFFE8EC)
                      : AppColors.accentPinkSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 12,
                      color: isCancelled
                          ? AppColors.accentPink
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.statusLabel,
                      style: TextStyle(
                        color: isCancelled
                            ? AppColors.accentPink
                            : AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCancelled) ...[
            const SizedBox(height: 14),
            OrderProgressTimeline(status: order.status),
          ],
          if (showTrackButton) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onTrackOrder,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPink,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text(
                    'Track Order',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              order.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OrderProgressTimeline extends StatelessWidget {
  final String status;

  const OrderProgressTimeline({super.key, required this.status});

  static const _stages = [
    'Order Placed',
    'Preparing',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final order = CustomerOrderTracking(
      id: '',
      status: status,
      createdAt: null,
      totalAmount: 0,
      deliveryAddress: null,
      items: const [],
    );
    if (order.progressIndex < 0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (var index = 0; index < _stages.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: index == 0
                          ? const SizedBox(height: 2)
                          : Container(
                              height: 2,
                              color: index <= order.progressIndex
                                  ? AppColors.badgeGreen
                                  : const Color(0xFFE2DCE6),
                            ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: index < order.progressIndex
                            ? AppColors.badgeGreen
                            : index == order.progressIndex
                            ? AppColors.accentPink
                            : const Color(0xFFE2DCE6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: index == _stages.length - 1
                          ? const SizedBox(height: 2)
                          : Container(
                              height: 2,
                              color: index < order.progressIndex
                                  ? AppColors.badgeGreen
                                  : const Color(0xFFE2DCE6),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _stages[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: index == order.progressIndex
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: index <= order.progressIndex
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineTrackingError extends StatelessWidget {
  final VoidCallback onRetry;

  const _InlineTrackingError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Could not refresh order status.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
