import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/customer_order_tracking_provider.dart';

class CustomerOrderCancellationAction extends StatefulWidget {
  final String orderId;
  final String status;
  final String userId;
  final CustomerOrderTrackingProvider provider;
  final ValueChanged<String> onStatusChanged;

  const CustomerOrderCancellationAction({
    super.key,
    required this.orderId,
    required this.status,
    required this.userId,
    required this.provider,
    required this.onStatusChanged,
  });

  @override
  State<CustomerOrderCancellationAction> createState() =>
      _CustomerOrderCancellationActionState();
}

class _CustomerOrderCancellationActionState
    extends State<CustomerOrderCancellationAction> {
  late String _status = widget.status;
  bool _isCancelling = false;

  @override
  void didUpdateWidget(covariant CustomerOrderCancellationAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _status = widget.status;
  }

  bool get _canCancel {
    final normalizedStatus = _status.toLowerCase();
    return normalizedStatus == 'placed' || normalizedStatus == 'order placed';
  }

  Future<void> _confirmCancellation() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'You can cancel this order only before preparation begins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentPink),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted || _isCancelling) return;

    setState(() => _isCancelling = true);
    try {
      await widget.provider.cancelOrder(
        orderId: widget.orderId,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() => _status = 'cancelled');
      widget.onStatusChanged('cancelled');

      String? refreshError;
      try {
        final refreshedOrder = await widget.provider.loadOrderDetails(
          orderId: widget.orderId,
          userId: widget.userId,
        );
        if (refreshedOrder != null && mounted) {
          setState(() => _status = refreshedOrder.status);
          widget.onStatusChanged(refreshedOrder.status);
        }
      } catch (error) {
        refreshError = error.toString();
      }

      if (mounted) {
        _showMessage(
          refreshError == null ? 'Order cancelled.' : 'Order cancelled, but its latest status could not be refreshed.',
        );
      }
    } catch (error) {
      var message = 'Could not cancel this order: $error';
      try {
        final refreshedOrder = await widget.provider.loadOrderDetails(
          orderId: widget.orderId,
          userId: widget.userId,
        );
        if (refreshedOrder != null && mounted) {
          setState(() => _status = refreshedOrder.status);
          widget.onStatusChanged(refreshedOrder.status);
        }
      } catch (refreshError) {
        message += '\nCould not refresh the order status: $refreshError';
      }
      if (mounted) _showMessage(message);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCancel) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: _isCancelling ? null : _confirmCancellation,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentPink,
        side: const BorderSide(color: AppColors.accentPink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      icon: _isCancelling
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cancel_outlined),
      label: Text(_isCancelling ? 'Cancelling…' : 'Cancel Order'),
    );
  }
}
