import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/delivery_assignment_data.dart';
import '../widgets/order_payment_summary.dart';
import 'delivery_pickup_confirmation_screen.dart';
import 'delivery_map_screen.dart';

class DeliveryPartnerOrderDetailsScreen extends StatefulWidget {
  final DeliveryManagedOrder order;
  final Future<bool> Function(String)? onUpdate;
  final bool isUpdating;

  const DeliveryPartnerOrderDetailsScreen({
    super.key,
    required this.order,
    this.onUpdate,
    this.isUpdating = false,
  });

  @override
  State<DeliveryPartnerOrderDetailsScreen> createState() =>
      _DeliveryPartnerOrderDetailsScreenState();
}

class _DeliveryPartnerOrderDetailsScreenState
    extends State<DeliveryPartnerOrderDetailsScreen> {
  bool _isProcessing = false;
  String? _actionError;

  bool get _busy => _isProcessing || widget.isUpdating;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Order details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (_actionError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _actionError!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  '#ORD-${order.id}',
                  style: const TextStyle(
                    color: AppColors.accentPink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${_orderAge(order.createdAt)}  ·  ${order.itemCount} items  ·  ${_money(order.totalAmount)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _OrderTimeline(status: order.status, createdAt: order.createdAt),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Order items',
            child: order.items.isEmpty
                ? const Text(
                    'Item details are unavailable for this order.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                : Column(
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: AppColors.giftBannerBg,
                                child: item.imageUrl?.trim().isNotEmpty == true
                                    ? ClipOval(
                                        child: Image.network(
                                          item.imageUrl!,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.shopping_bag_outlined,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: AppColors.primary,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.quantity} × ${_money(item.unitPrice)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    item.lineTotal == null
                                        ? '—'
                                        : '₹${item.lineTotal!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => DeliveryMapScreen(order: order),
              ),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open delivery map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.location_on_outlined,
            title: 'Delivery Address',
            trailing: order.deliveryAddress?.trim().isNotEmpty == true
                ? const Icon(Icons.near_me_outlined, color: AppColors.primary)
                : null,
            child: Text(
              order.deliveryAddress ??
                  'No saved delivery address is available.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.payments_outlined,
            title: 'Payment',
            child: OrderPaymentSummary(
              paymentMethod: order.paymentMethod,
              paymentStatus: order.paymentStatus,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _actionButton(context, order),
    );
  }

  Widget? _actionButton(BuildContext context, DeliveryManagedOrder order) {
    if (widget.onUpdate == null ||
        (order.status != 'preparing' && order.status != 'out_for_delivery')) {
      return null;
    }
    final isPickup = order.status == 'preparing';
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _submitStatus(order, isPickup),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(isPickup ? 'Order Picked Up' : 'Mark delivered'),
        ),
      ),
    );
  }

  Future<void> _submitStatus(DeliveryManagedOrder order, bool isPickup) async {
    if (!isPickup) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark order delivered?'),
          content: Text('Confirm that order #${order.id} has been delivered.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm delivery'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isProcessing = true;
      _actionError = null;
    });
    final nextStatus = isPickup ? 'out_for_delivery' : 'delivered';
    final succeeded = await widget.onUpdate!(nextStatus);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (!succeeded) {
      setState(
        () => _actionError = 'Could not update the order. Please retry.',
      );
      return;
    }

    if (isPickup) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DeliveryPickupConfirmationScreen(
            order: order.copyWith(status: 'out_for_delivery'),
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delivery status updated.')));
    }
  }
}

class _OrderTimeline extends StatelessWidget {
  final String status;
  final DateTime? createdAt;

  const _OrderTimeline({required this.status, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final current = switch (status) {
      'placed' => 0,
      'preparing' => 1,
      'out_for_delivery' => 2,
      'delivered' => 3,
      _ => -1,
    };
    const labels = [
      'Order Assigned',
      'Preparing',
      'Out for Delivery',
      'Delivered',
    ];
    return Column(
      children: [
        for (var index = 0; index < labels.length; index++)
          _TimelineRow(
            label: labels[index],
            subtitle: index == 0 && index <= current
                ? _formatDate(createdAt)
                : index == current
                ? 'In progress'
                : null,
            complete: current >= 0 && index < current,
            active: current == index,
            isLast: index == labels.length - 1,
          ),
        if (status == 'cancelled')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'This order was cancelled.',
              style: TextStyle(color: AppColors.accentPink),
            ),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool complete;
  final bool active;
  final bool isLast;

  const _TimelineRow({
    required this.label,
    required this.subtitle,
    required this.complete,
    required this.active,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        SizedBox(
          width: 38,
          child: Column(
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: complete || active
                      ? AppColors.primary
                      : const Color(0xFFE8E5EC),
                  shape: BoxShape.circle,
                ),
                child: complete
                    ? const Icon(Icons.check, color: Colors.white, size: 17)
                    : active
                    ? const Icon(Icons.circle, color: Colors.white, size: 8)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: complete
                        ? AppColors.primary
                        : const Color(0xFFE8E5EC),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active || complete
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: active || complete
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.giftBannerBg,
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                child,
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final delivered = status == 'delivered';
    final cancelled = status == 'cancelled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: delivered
            ? AppColors.badgeGreenLight
            : cancelled
            ? const Color(0xFFFFE7EC)
            : AppColors.giftBannerBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: delivered
              ? AppColors.badgeGreen
              : cancelled
              ? AppColors.accentPink
              : AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

String _money(double? value) =>
    value == null ? 'Total unavailable' : '₹${value.toStringAsFixed(2)}';

String _orderAge(DateTime? date) {
  if (date == null) return 'Time unavailable';
  final elapsed = DateTime.now().difference(date.toLocal());
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} mins ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} hours ago';
  return '${elapsed.inDays} days ago';
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _statusLabel(String status) => switch (status) {
  'placed' => 'Placed',
  'preparing' => 'Preparing',
  'out_for_delivery' => 'Out for Delivery',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status.replaceAll('_', ' '),
};
