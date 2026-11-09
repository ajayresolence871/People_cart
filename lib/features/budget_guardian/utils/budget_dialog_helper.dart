import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/cart_provider.dart';

class BudgetDialogHelper {
  /// Checks whether adding an item of [itemPrice] will cross the active budget.
  /// If budget is exceeded:
  /// - Raises popup: "Budget is exceeding, do you want to continue?"
  /// - If user clicks YES: removes the budget (disables Budget Guardian) and adds the item.
  /// - If user clicks NO: cancels the addition and returns to cart.
  static Future<bool> checkAndAdd({
    required BuildContext context,
    required double itemPrice,
    required VoidCallback onProceed,
  }) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final budget = Provider.of<BudgetProvider>(context, listen: false);

    // If Budget Guardian is not active, add normally
    if (!budget.isEnabled) {
      onProceed();
      return true;
    }

    final currentSubtotal = cart.subtotal;
    final newSubtotal = currentSubtotal + itemPrice;

    // Check if adding this item crosses the budget limit
    if (newSubtotal > budget.budgetAmount) {
      final excess = newSubtotal - budget.budgetAmount;

      final bool? continueAndRemoveBudget = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget Exceeded',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Budget is exceeding by ₹${excess.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Adding this item makes your total ₹${newSubtotal.toStringAsFixed(0)}, which crosses your ₹${budget.budgetAmount.toStringAsFixed(0)} budget limit.\n\nDo you want to continue?',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            // NO button: return to cart without adding
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'No, Keep Budget',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            // YES button: remove budget and continue
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text(
                'Yes, Continue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );

      if (continueAndRemoveBudget == true) {
        // User clicked YES -> remove budget and proceed
        budget.setEnabled(false);
        onProceed();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget Guardian removed. You can continue shopping!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      } else {
        // User clicked NO -> return to cart / do not add item
        return false;
      }
    } else {
      // Within budget -> add item normally
      onProceed();
      return true;
    }
  }
}
