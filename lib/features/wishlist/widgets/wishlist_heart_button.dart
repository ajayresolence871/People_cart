import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';
import '../providers/wishlist_provider.dart';

class WishlistHeartButton extends StatelessWidget {
  final Product product;
  final double diameter;
  final double iconSize;

  const WishlistHeartButton({
    super.key,
    required this.product,
    this.diameter = 36,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider?>();
    final isSaved = wishlist?.contains(product.id) ?? false;
    final isPending = wishlist?.isPending(product.id) ?? false;
    final enabled = wishlist != null && !wishlist.isLoading && !isPending;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        color: Colors.white.withValues(alpha: 0.96),
        shape: const CircleBorder(),
        elevation: 1,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: wishlist?.hasLoaded == false
              ? 'Retry wishlist'
              : isSaved
              ? 'Remove from wishlist'
              : 'Add to wishlist',
          onPressed: enabled
              ? () async {
                  if (!wishlist.hasLoaded) {
                    await wishlist.load(force: true);
                    if (!wishlist.hasLoaded) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                wishlist.error ??
                                    'Wishlist is not available right now.',
                              ),
                            ),
                          );
                      }
                      return;
                    }
                  }
                  final succeeded = await wishlist.toggleProduct(
                    product.id,
                    product: product,
                  );
                  if (!succeeded && context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            wishlist.error ?? 'Could not update your wishlist.',
                          ),
                        ),
                      );
                  }
                }
              : null,
          icon: isPending
              ? SizedBox(
                  width: iconSize * 0.7,
                  height: iconSize * 0.7,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentPink,
                  ),
                )
              : Icon(
                  isSaved ? Icons.favorite_rounded : Icons.favorite_border,
                  size: iconSize,
                  color: isSaved ? AppColors.accentPink : AppColors.primary,
                ),
        ),
      ),
    );
  }
}
