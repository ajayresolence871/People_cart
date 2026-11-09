import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/delivery_assignment_data.dart';

class AdminOrderCard extends StatelessWidget {
  final DeliveryManagedOrder order;
  final VoidCallback onViewDetails;
  final VoidCallback? onAssignPartner;
  final VoidCallback? onTrackOrder;
  final bool isUpdating;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.onViewDetails,
    this.onAssignPartner,
    this.onTrackOrder,
    this.isUpdating = false,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Today, --:--';
    final local = date.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final prefix = isToday
        ? 'Today'
        : '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$prefix, $hour:$minute $ampm';
  }

  (Color, Color, String) _statusBadgeInfo(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return (const Color(0xFFF3EAF8), AppColors.primary, 'Placed');
      case 'preparing':
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Preparing');
      case 'out_for_delivery':
        return (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
          'Out for Delivery',
        );
      case 'delivered':
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), 'Delivered');
      case 'cancelled':
        return (const Color(0xFFFFEBEE), const Color(0xFFC62828), 'Cancelled');
      default:
        return (const Color(0xFFF5F5F7), AppColors.textSecondary, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg, statusLabel) = _statusBadgeInfo(order.status);
    final customerName = order.customerName?.trim().isNotEmpty == true
        ? order.customerName!.trim()
        : 'Customer #${order.id}';
    final addressText = order.deliveryAddress?.trim().isNotEmpty == true
        ? order.deliveryAddress!.trim()
        : 'Address on file';
    final partnerName = order.assignedPartnerName?.trim();
    final hasPartner =
        order.assignedPartnerId != null && order.assignedPartnerId!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onViewDetails,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEADBEE), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Order ID, Date, Amount, Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onViewDetails,
                          child: Text(
                            'Order #${order.id}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                _formatDate(order.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFFEADBEE),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 6, color: statusFg),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF3EDF7)),
              const SizedBox(height: 12),

              // 2. Customer & Delivery Information
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Customer Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF4FC),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF0EBF4)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Customer Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                addressText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${order.itemCount} items',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right Delivery Status Indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasPartner) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delivery_dining_rounded,
                              size: 18,
                              color: Color(0xFF0C8340),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              partnerName?.isNotEmpty == true
                                  ? partnerName!
                                  : 'Partner Assigned',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.badgeGreenLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'On Time',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.badgeGreen,
                            ),
                          ),
                        ),
                      ] else if (order.status == 'preparing') ...[
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.kitchen_rounded,
                              size: 16,
                              color: Color(0xFFE65100),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Preparing',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'at Store',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else ...[
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Unassigned',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. Action Buttons Row
              Row(
                children: [
                  // "View Details" Button
                  Expanded(
                    child: Material(
                      color: const Color(0xFFF7F4F9),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onViewDetails,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEADBEE)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'View Details',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Contextual Action Button
                  Expanded(child: _buildContextualActionButton()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextualActionButton() {
    if (isUpdating) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentPinkSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.accentPink,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (order.status == 'delivered' || order.status == 'cancelled') {
      return Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            order.status == 'delivered' ? 'Completed' : 'Cancelled',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (order.status == 'out_for_delivery') {
      return Material(
        color: const Color(0xFFFFF0F3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTrackOrder ?? onViewDetails,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.accentPink,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Track Order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentPink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Default: Assign / Reassign Partner
    final isReassign =
        order.assignedPartnerId != null && order.assignedPartnerId!.isNotEmpty;
    return Material(
      color: AppColors.accentPinkSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAssignPartner,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentPink.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isReassign
                    ? Icons.person_add_alt_1_rounded
                    : Icons.person_add_rounded,
                size: 16,
                color: AppColors.accentPink,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isReassign ? 'Reassign partner' : 'Assign partner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentPink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
