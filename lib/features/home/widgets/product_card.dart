import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../budget_guardian/utils/budget_dialog_helper.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../../wishlist/widgets/wishlist_heart_button.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final String? badgeText;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.badgeText,
  });

  // Fallback visual emoji if image URL is empty
  String _getProductEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread') || lower.contains('baked')) return '🍞';
    if (lower.contains('curly') || lower.contains('turn')) return '🥨';
    if (lower.contains('party') ||
        lower.contains('mix') ||
        lower.contains('bbq')) {
      return '🥜';
    }
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍨';
    if (lower.contains('skin') ||
        lower.contains('spot') ||
        lower.contains('serum')) {
      return '🧴';
    }
    if (lower.contains('berry') || lower.contains('cinnamon')) return '🫐';
    if (lower.contains('chip') || lower.contains('potato chips')) return '🥔';
    if (lower.contains('juice') || lower.contains('orange')) return '🍊';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('chilli')) return '🌶️';
    if (lower.contains('potato')) return '🥔';
    return '🥗';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.getQuantity(product.id);

    return InkWell(
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 125,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Section with "+" Add Button overlay
            Stack(
              children: [
                // Product Image / Fallback Container
                Container(
                  height: 105,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBFBFB),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CatalogImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: Text(
                          _getProductEmoji(product.name),
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),
                ),
                // Top-left "Select >" brown badge (as seen in Zepto Steal Deals)
                if (badgeText != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C4A11), // Rich brown badge
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            badgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 1),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 11,
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: WishlistHeartButton(
                    product: product,
                    diameter: 32,
                    iconSize: 18,
                  ),
                ),
                // Zepto-style "+" or "- [qty] +" button on bottom-right of image
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: cart.isOutOfStock(product)
                      ? InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.name} is currently out of stock.',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : quantity == 0
                      ? InkWell(
                          onTap: () {
                            BudgetDialogHelper.checkAndAdd(
                              context: context,
                              itemPrice: product.price,
                              onProceed: () => cart.addItem(product),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.accentPink,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentPink.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: AppColors.accentPink,
                              size: 20,
                            ),
                          ),
                        )
                      : Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.accentPink,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentPink.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => cart.removeSingleItem(product.id),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '$quantity',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  if (!cart.canIncrement(product)) {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cannot add more. Only ${product.stockQuantity} in stock.',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                    return;
                                  }
                                  BudgetDialogHelper.checkAndAdd(
                                    context: context,
                                    itemPrice: product.price,
                                    onProceed: () => cart.addItem(product),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: cart.canIncrement(product)
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price & Discount tags
                  Row(
                    children: [
                      // Green Price Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.badgeGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Original price strikethrough
                      Text(
                        '₹${product.originalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Discount Saved Text
                  if (product.discountAmount > 0)
                    Text(
                      '₹${product.discountAmount.toStringAsFixed(0)} OFF',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.badgeGreen,
                      ),
                    ),
                  const SizedBox(height: 4),

                  // Product Name
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Unit / Weight
                  Text(
                    product.description != null &&
                            product.description!.isNotEmpty
                        ? product.description!
                        : '500 g',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
