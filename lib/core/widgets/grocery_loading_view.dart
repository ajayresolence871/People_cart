import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GroceryLoadingView extends StatelessWidget {
  final String? message;
  final String? subtitle;
  final double? size;
  final bool compact;

  const GroceryLoadingView({
    super.key,
    this.message,
    this.subtitle,
    this.size,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? (compact ? 70.0 : 90.0);
    final iconSize = (effectiveSize * 0.38).clamp(20.0, 40.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: compact ? 16.0 : 32.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Themed Grocery Loading Indicator
          SizedBox(
            width: effectiveSize,
            height: effectiveSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft pink pulsing background circle
                Container(
                  width: effectiveSize * 0.78,
                  height: effectiveSize * 0.78,
                  decoration: const BoxDecoration(
                    color: AppColors.accentPinkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: iconSize,
                      color: AppColors.accentPink,
                    ),
                  ),
                ),
                // Circular progress spinner
                SizedBox(
                  width: effectiveSize,
                  height: effectiveSize,
                  child: const CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPink),
                  ),
                ),
              ],
            ),
          ),
          if (message != null) ...[
            SizedBox(height: compact ? 12.0 : 18.0),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: compact ? 13.0 : 15.0,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 6.0),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.0,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
