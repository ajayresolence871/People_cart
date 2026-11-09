import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/cart_provider.dart';
import '../models/quick_order_mode.dart';
import '../providers/quick_order_provider.dart';
import '../screens/custom_mode_editor_screen.dart';
import 'quick_order_mode_detail_sheet.dart';

class QuickOrderModeCard extends StatelessWidget {
  final QuickOrderMode mode;

  const QuickOrderModeCard({
    super.key,
    required this.mode,
  });

  String? _getModeImagePath(QuickOrderMode mode) {
    final name = mode.name.toLowerCase();
    final icon = mode.iconName.toLowerCase();
    if (name.contains('essential') || icon == 'essentials') {
      return 'assets/images/home/qo_essentials.png';
    }
    if (name.contains('breakfast') || icon == 'breakfast') {
      return 'assets/images/home/qo_breakfast.png';
    }
    if (name.contains('snack') || icon == 'snacks') {
      return 'assets/images/home/qo_snacks.png';
    }
    if (name.contains('emergency') || icon == 'emergency') {
      return 'assets/images/home/qo_emergency.png';
    }
    return null;
  }

  IconData _getModeIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'breakfast':
        return Icons.breakfast_dining_rounded;
      case 'snacks':
        return Icons.fastfood_rounded;
      case 'emergency':
        return Icons.bolt_rounded;
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'movie':
        return Icons.movie_creation_rounded;
      case 'custom':
        return Icons.bookmark_added_rounded;
      case 'essentials':
      default:
        return Icons.shopping_basket_rounded;
    }
  }

  Future<void> _handleAddAll(BuildContext context) async {
    final provider = context.read<QuickOrderProvider>();
    final cart = context.read<CartProvider>();

    final result = await provider.addAllToCart(mode, cart);

    if (!context.mounted) return;

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
    final availableCount = mode.availableItems.length;
    final imagePath = _getModeImagePath(mode);

    return InkWell(
      onTap: () => QuickOrderModeDetailSheet.show(context, mode),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 156,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF4FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF3E5F5),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B0938).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with 3-dot menu aligned to the right
            Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                height: 24,
                width: 24,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Color(0xFF4A154B),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomModeEditorScreen(existingMode: mode),
                        ),
                      );
                    } else if (val == 'delete') {
                      _showDeleteConfirm(context);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!mode.isPredefined)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit Mode', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            mode.isPredefined ? 'Delete Preset' : 'Delete',
                            style: const TextStyle(fontSize: 13, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Large Grocery Illustration
            Center(
              child: SizedBox(
                height: 80,
                width: 130,
                child: imagePath != null
                    ? Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                      )
                    : (mode.items.isNotEmpty && mode.items.first.product?.imageUrl != null
                        ? Image.network(
                            mode.items.first.product!.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              _getModeIcon(mode.iconName),
                              size: 48,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(
                            _getModeIcon(mode.iconName),
                            size: 48,
                            color: AppColors.primary,
                          )),
              ),
            ),

            const SizedBox(height: 8),

            // Preset Name
            Text(
              mode.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 2),

            // Item count & price
            Text(
              '$availableCount items • ₹${mode.estimatedTotal.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B4377),
              ),
            ),

            const Spacer(),

            // Solid Pink "⚡ ADD ALL" Button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _handleAddAll(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'ADD ALL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    final isPreset = mode.isPredefined;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isPreset ? 'Delete Preset?' : 'Delete Shortcut?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          isPreset
              ? 'Are you sure you want to delete preset "${mode.name}"? You can restore default presets anytime from the section.'
              : 'Are you sure you want to delete "${mode.name}"? This will not affect items currently in your cart.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isPreset) {
                context.read<QuickOrderProvider>().deletePresetMode(mode.id);
              } else {
                context.read<QuickOrderProvider>().deleteCustomMode(mode.id);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${mode.name}"'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
