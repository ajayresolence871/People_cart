import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/cart_provider.dart';
import '../models/quick_order_mode.dart';
import '../providers/quick_order_provider.dart';
import '../screens/custom_mode_editor_screen.dart';

class QuickOrderModeDetailSheet extends StatelessWidget {
  final QuickOrderMode mode;

  const QuickOrderModeDetailSheet({
    super.key,
    required this.mode,
  });

  static void show(BuildContext context, QuickOrderMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickOrderModeDetailSheet(mode: mode),
    );
  }

  String _getProductEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('chip') || lower.contains('turns')) return '🥨';
    if (lower.contains('juice') || lower.contains('orange')) return '🍊';
    if (lower.contains('coconut')) return '🥥';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('potato')) return '🥔';
    if (lower.contains('chilli')) return '🌶️';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍨';
    if (lower.contains('atta') || lower.contains('oil')) return '🌾';
    return '🥗';
  }

  Future<void> _handleAddAll(BuildContext context) async {
    final provider = context.read<QuickOrderProvider>();
    final cart = context.read<CartProvider>();

    final result = await provider.addAllToCart(mode, cart);

    if (!context.mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.summaryMessage,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: result.addedItemCount > 0 ? AppColors.badgeGreen : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableItems = mode.availableItems;
    final unavailableItems = mode.unavailableItems;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mode.isPredefined ? AppColors.giftBannerBg : AppColors.accentPinkSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: mode.isPredefined ? AppColors.primary : AppColors.accentPink,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mode.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: mode.isPredefined ? AppColors.giftBannerBg : AppColors.accentPinkSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                mode.isPredefined ? 'PRESET' : 'CUSTOM',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: mode.isPredefined ? AppColors.primary : AppColors.accentPink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mode.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Unavailable items warning banner if any
            if (unavailableItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${unavailableItems.length} item(s) currently out of dark store stock and will be skipped.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // Products List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: mode.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = mode.items[index];
                  final product = item.product;
                  final isAvailable = item.isAvailable;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        // Thumbnail
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: product?.imageUrl != null && product!.imageUrl!.isNotEmpty
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Text(
                                      _getProductEmoji(item.displayName),
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  )
                                : Text(
                                    _getProductEmoji(item.displayName),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name and quantity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.giftBannerBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Qty: ${item.quantity}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${item.price.toStringAsFixed(0)} each',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  if (!isAvailable) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '• Out of Stock',
                                      style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Line total
                        Text(
                          '₹${item.lineTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Actions & Add All Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Price breakdown row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESTIMATED TOTAL',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${mode.estimatedTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      if (!mode.isPredefined)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomModeEditorScreen(existingMode: mode),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // "⚡ Add All to Cart" Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: availableItems.isNotEmpty ? () => _handleAddAll(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: Text(
                        'Add All to Cart (${availableItems.length} items)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
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
