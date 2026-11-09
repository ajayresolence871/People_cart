import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../providers/quick_order_provider.dart';
import '../screens/custom_mode_editor_screen.dart';
import 'quick_order_mode_card.dart';

class QuickOrderModesSection extends StatefulWidget {
  final List<Product> catalog;

  const QuickOrderModesSection({super.key, required this.catalog});

  @override
  State<QuickOrderModesSection> createState() => _QuickOrderModesSectionState();
}

class _QuickOrderModesSectionState extends State<QuickOrderModesSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.catalog.isNotEmpty && mounted) {
        final auth = Provider.of<AuthProvider?>(context, listen: false);
        final userId = auth?.user?.id ?? auth?.profile?.id;
        context.read<QuickOrderProvider>().loadModes(
          widget.catalog,
          userId: userId,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant QuickOrderModesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.catalog != oldWidget.catalog &&
        widget.catalog.isNotEmpty &&
        mounted) {
      final auth = Provider.of<AuthProvider?>(context, listen: false);
      final userId = auth?.user?.id ?? auth?.profile?.id;
      context.read<QuickOrderProvider>().loadModes(
        widget.catalog,
        userId: userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickOrder = context.watch<QuickOrderProvider>();
    final allModes = quickOrder.allModes;
    final compact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header matching reference
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 22,
                          color: AppColors.accentPink,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Quick-Order Modes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (!compact) const SizedBox(width: 8),
                        if (!compact)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentPink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '1-TAP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Your regular groceries, one tap away',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7D6585),
                      ),
                    ),
                  ],
                ),
              ),

              // Right-aligned actions: Restore & "+ Custom" pill button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (quickOrder.hasHiddenPresets)
                    compact
                        ? IconButton(
                            tooltip: 'Restore default presets',
                            onPressed: () {
                              quickOrder.restoreDefaultPresets();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Default presets restored!'),
                                  backgroundColor: AppColors.badgeGreen,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.restore, size: 18),
                          )
                        : TextButton.icon(
                            onPressed: () {
                              quickOrder.restoreDefaultPresets();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Default presets restored!'),
                                  backgroundColor: AppColors.badgeGreen,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.restore, size: 14),
                            label: const Text(
                              'Restore',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomModeEditorScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: Color(0xFF5A2A6B),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 12,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Custom',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Horizontal Mode Cards Carousel
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount:
                allModes.length + 1, // +1 for the "+ Add Custom Mode" card
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index < allModes.length) {
                final mode = allModes[index];
                return QuickOrderModeCard(mode: mode);
              }

              // The trailing "+ Add Custom Mode" card
              return _buildAddCustomModeCard(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddCustomModeCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomModeEditorScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF4FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentPink.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.accentPinkSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.accentPink,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add Custom\nMode',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Save your own collection',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
