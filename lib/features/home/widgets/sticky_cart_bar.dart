import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/cart_provider.dart';

class StickyCartBar extends StatelessWidget {
  final VoidCallback? onViewCartTap;

  const StickyCartBar({
    super.key,
    this.onViewCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              children: [
                // Delivery Scooter / Gift Icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cart.isFreeDeliveryUnlocked
                        ? AppColors.badgeGreenLight
                        : const Color(0xFFF4F0F8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    cart.isFreeDeliveryUnlocked
                        ? Icons.check_circle_outline
                        : Icons.delivery_dining,
                    color: cart.isFreeDeliveryUnlocked
                        ? AppColors.badgeGreen
                        : AppColors.primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),

                // Free delivery text description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          children: cart.isFreeDeliveryUnlocked
                              ? const [
                                  TextSpan(
                                    text: '🎉 Free Delivery Unlocked!',
                                    style: TextStyle(
                                      color: AppColors.badgeGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ]
                              : [
                                  const TextSpan(text: 'Shop for '),
                                  TextSpan(
                                    text:
                                        '₹${cart.amountNeededForFreeDelivery.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  const TextSpan(text: ' → Unlock free delivery'),
                                ],
                        ),
                      ),
                      if (cart.totalQuantity > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            '${cart.totalQuantity} items | ₹${cart.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // View Cart Action button (Zepto-style 🛒 Cart 1 button matching Screenshot 1)
                if (cart.totalQuantity > 0)
                  InkWell(
                    onTap: onViewCartTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentPink,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPink.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Cart',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Center(
                              child: Text(
                                '${cart.totalQuantity}',
                                style: const TextStyle(
                                  color: AppColors.accentPink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Free delivery progress line
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: LinearProgressIndicator(
              value: cart.freeDeliveryProgress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                cart.isFreeDeliveryUnlocked ? AppColors.badgeGreen : AppColors.accentPink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
