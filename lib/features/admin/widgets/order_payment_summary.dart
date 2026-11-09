import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class OrderPaymentSummary extends StatelessWidget {
  final String? paymentMethod;
  final String? paymentStatus;

  const OrderPaymentSummary({
    super.key,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final method = switch (paymentMethod) {
      'cash_on_delivery' => 'Cash on delivery',
      'razorpay' => 'Online payment',
      _ => 'Payment information unavailable',
    };
    final status = switch ((paymentMethod, paymentStatus)) {
      ('cash_on_delivery', 'pending') => 'Collect payment on delivery',
      ('cash_on_delivery', 'paid') => 'Paid',
      ('razorpay', 'paid') => 'Paid',
      _ => 'Payment status unavailable',
    };
    final paid = paymentStatus == 'paid';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                status,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (paid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.badgeGreenLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PAID',
              style: TextStyle(
                color: AppColors.badgeGreen,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}
