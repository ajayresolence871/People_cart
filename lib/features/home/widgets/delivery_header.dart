import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/people_mart_logo.dart';
import '../../address/providers/address_provider.dart';
import '../../address/widgets/address_selector_bottom_sheet.dart';

class DeliveryHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAddressTap;
  final VoidCallback? onWishlistTap;

  const DeliveryHeader({
    super.key,
    this.onProfileTap,
    this.onAddressTap,
    this.onWishlistTap,
  });

  @override
  Widget build(BuildContext context) {
    AddressProvider? addressProvider;
    try {
      addressProvider = context.watch<AddressProvider>();
    } catch (_) {}

    final deliverySpeed =
        addressProvider?.currentDeliverySpeed ?? '5-10 minutes';
    final addressText =
        addressProvider?.currentShortDisplay ??
        'Home — Plot 12, Tech Zone, Hitech City...';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const PeopleMartLogoMark(size: 38),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap:
                        onAddressTap ??
                        () => AddressSelectorBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              deliverySpeed,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                addressText,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Wishlist',
            onPressed: onWishlistTap,
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.accentPink,
              size: 25,
            ),
          ),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
