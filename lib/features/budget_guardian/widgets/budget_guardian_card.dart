import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/cart_provider.dart';

class BudgetGuardianCard extends StatefulWidget {
  const BudgetGuardianCard({super.key});

  @override
  State<BudgetGuardianCard> createState() => _BudgetGuardianCardState();
}

class _BudgetGuardianCardState extends State<BudgetGuardianCard> {
  final TextEditingController _customController = TextEditingController();
  bool _isEditingCustom = false;
  String? _customErrorText;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _applyCustomBudget(BudgetProvider budget) {
    final text = _customController.text.trim();
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      setState(() {
        _customErrorText = 'Enter a valid amount > ₹0';
      });
      return;
    }

    setState(() {
      _customErrorText = null;
      _isEditingCustom = false;
    });

    budget.setBudgetAmount(amount);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final budget = context.watch<BudgetProvider>();

    final subtotal = cart.subtotal;
    final isEnabled = budget.isEnabled;
    final budgetAmount = budget.budgetAmount;

    final isOver = budget.isOverBudget(subtotal);
    final isNear = budget.isNearLimit(subtotal);
    final isReached = budget.isBudgetReached(subtotal);
    final usageRatio = budget.budgetUsage(subtotal);
    final remaining = budget.remainingBudget(subtotal);
    final overAmount = budget.overBudgetAmount(subtotal);

    // Determine state theme colors
    Color stateColor;
    Color stateBgColor;
    IconData stateIcon;
    String stateMessage;

    if (isOver) {
      stateColor = const Color(0xFFDC2626); // Strong red
      stateBgColor = const Color(0xFFFEF2F2);
      stateIcon = Icons.error_outline_rounded;
      stateMessage = "You're ₹${overAmount.toStringAsFixed(0)} over your budget!";
    } else if (isReached) {
      stateColor = const Color(0xFFEA580C); // Orange
      stateBgColor = const Color(0xFFFFF7ED);
      stateIcon = Icons.warning_amber_rounded;
      stateMessage = 'Budget reached! Total cart matches your ₹${budgetAmount.toStringAsFixed(0)} limit.';
    } else if (isNear) {
      stateColor = const Color(0xFFD97706); // Amber
      stateBgColor = const Color(0xFFFFFBEB);
      stateIcon = Icons.info_outline_rounded;
      stateMessage = "You're getting close to your budget limit (${(subtotal / budgetAmount * 100).round()}% used).";
    } else {
      stateColor = AppColors.badgeGreen;
      stateBgColor = const Color(0xFFF0FDF4);
      stateIcon = Icons.check_circle_outline_rounded;
      stateMessage = 'Healthy budget! You have ₹${remaining.toStringAsFixed(0)} remaining.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled && isOver
              ? const Color(0xFFFCA5A5)
              : Colors.grey.shade200,
          width: isEnabled && isOver ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Shield Icon, Title, Subtitle, and ON/OFF Toggle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? (isOver ? const Color(0xFFFEE2E2) : const Color(0xFFE8F6ED))
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: isEnabled
                      ? (isOver ? const Color(0xFFDC2626) : AppColors.badgeGreen)
                      : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Budget Guardian',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isEnabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isOver ? const Color(0xFFFEE2E2) : const Color(0xFFE8F6ED),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '₹${budgetAmount.toStringAsFixed(0)} Limit',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOver ? const Color(0xFFDC2626) : AppColors.badgeGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Keep your shopping within budget',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // ON/OFF Switch
              Switch.adaptive(
                value: isEnabled,
                activeTrackColor: AppColors.accentPink,
                onChanged: (val) => budget.setEnabled(val),
              ),
            ],
          ),

          // 2. Budget Controls and Visual Status (shown only when enabled)
          if (isEnabled) ...[
            const Divider(height: 18),

            // Budget Preset Selection Row
            Row(
              children: [
                ...BudgetProvider.presetBudgets.map((preset) {
                  final isSelected = !_isEditingCustom && budgetAmount == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text('₹${preset.toStringAsFixed(0)}'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isEditingCustom = false;
                            _customErrorText = null;
                          });
                          budget.setBudgetAmount(preset);
                        }
                      },
                      selectedColor: const Color(0xFFFFEFF2),
                      backgroundColor: const Color(0xFFF9F9FA),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.accentPink : AppColors.textPrimary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.accentPink : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),

                // Custom Budget Chip
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _isEditingCustom ||
                      !BudgetProvider.presetBudgets.contains(budgetAmount),
                  onSelected: (selected) {
                    setState(() {
                      _isEditingCustom = true;
                      _customController.text = budgetAmount.toStringAsFixed(0);
                    });
                  },
                  selectedColor: const Color(0xFFFFEFF2),
                  backgroundColor: const Color(0xFFF9F9FA),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: (_isEditingCustom ||
                            !BudgetProvider.presetBudgets.contains(budgetAmount))
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: (_isEditingCustom ||
                            !BudgetProvider.presetBudgets.contains(budgetAmount))
                        ? AppColors.accentPink
                        : AppColors.textPrimary,
                  ),
                  side: BorderSide(
                    color: (_isEditingCustom ||
                            !BudgetProvider.presetBudgets.contains(budgetAmount))
                        ? AppColors.accentPink
                        : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // Custom Budget Input Field (expandable)
            if (_isEditingCustom) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        hintText: 'Enter budget amount',
                        hintStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        errorText: _customErrorText,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => _applyCustomBudget(budget),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _applyCustomBudget(budget),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // 3. Subtotal vs Remaining/Over-budget Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Subtotal: ',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      '₹${subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  isOver
                      ? '₹${overAmount.toStringAsFixed(0)} over budget'
                      : (isReached
                          ? 'Budget reached'
                          : '₹${remaining.toStringAsFixed(0)} remaining'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: stateColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 4. Budget Usage Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usageRatio,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              ),
            ),

            const SizedBox(height: 10),

            // 5. Visual State Message Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: stateBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: stateColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(stateIcon, size: 16, color: stateColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stateMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: stateColor,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 6. Savings Suggestions Placeholder (only shown when over budget)
            if (isOver) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Smart saving suggestions coming soon. Review items above to stay on track.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
