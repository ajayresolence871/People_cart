import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final double? totalAmount;
  final int itemCount;
  final String paymentMethod;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.itemCount,
    this.paymentMethod = 'cash_on_delivery',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Celebration Icon
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.badgeGreenLight,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.badgeGreen,
                    size: 64,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Order Placed!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your order status is available from Home.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 28),

              // Order Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildRow('Order ID', '#$orderId'),
                    const Divider(height: 20),
                    _buildRow('Items Ordered', '$itemCount items'),
                    const Divider(height: 20),
                    _buildRow(
                      'Selected payment method',
                      paymentMethod == 'razorpay'
                          ? 'Razorpay (Test Mode)'
                          : 'Cash on delivery',
                    ),
                    if (totalAmount != null) ...[
                      const Divider(height: 20),
                      _buildRow(
                        'Order total',
                        '₹${totalAmount!.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              const SizedBox(height: 20),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue Shopping',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: isBold ? AppColors.badgeGreen : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
