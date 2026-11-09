import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetProvider extends ChangeNotifier {
  static const List<double> presetBudgets = [300.0, 500.0, 1000.0];
  static const double defaultBudget = 500.0;

  static const String _prefKeyEnabled = 'budget_guardian_enabled';
  static const String _prefKeyAmount = 'budget_guardian_amount';

  bool _isEnabled = false;
  double _budgetAmount = defaultBudget;
  bool _isInitialized = false;

  BudgetProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPreferences();
    }
  }

  bool get isEnabled => _isEnabled;
  double get budgetAmount => _budgetAmount;
  bool get isInitialized => _isInitialized;

  /// Loads saved budget preferences from SharedPreferences
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefKeyEnabled) ?? false;
      final savedAmount = prefs.getDouble(_prefKeyAmount);
      if (savedAmount != null && savedAmount > 0) {
        _budgetAmount = savedAmount;
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('BudgetProvider.loadPreferences notice: $e');
      _isInitialized = true;
    }
  }

  /// Saves preferences to local storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, _isEnabled);
      await prefs.setDouble(_prefKeyAmount, _budgetAmount);
    } catch (e) {
      debugPrint('BudgetProvider._savePreferences notice: $e');
    }
  }

  /// Toggles Budget Guardian ON or OFF
  void toggleEnabled() {
    _isEnabled = !_isEnabled;
    _savePreferences();
    notifyListeners();
  }

  /// Sets Budget Guardian enabled state explicitly
  void setEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
    _savePreferences();
    notifyListeners();
  }

  /// Updates the budget amount if valid (> 0).
  /// Rejects 0 or negative numbers.
  bool setBudgetAmount(double amount) {
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      return false;
    }
    _budgetAmount = amount;
    _savePreferences();
    notifyListeners();
    return true;
  }

  // ========================================================================
  // Calculation Methods (derived using the authoritative cart subtotal)
  // ========================================================================

  /// Calculates remaining budget amount: max(0, budget - subtotal)
  double remainingBudget(double subtotal) {
    final remaining = _budgetAmount - subtotal;
    return remaining > 0 ? remaining : 0.0;
  }

  /// Calculates excess amount over budget: max(0, subtotal - budget)
  double overBudgetAmount(double subtotal) {
    final over = subtotal - _budgetAmount;
    return over > 0 ? over : 0.0;
  }

  /// Returns budget usage ratio clamped between 0.0 and 1.0 (prevents division by zero)
  double budgetUsage(double subtotal) {
    if (_budgetAmount <= 0) return 0.0;
    if (subtotal <= 0) return 0.0;
    return (subtotal / _budgetAmount).clamp(0.0, 1.0);
  }

  /// Returns true if cart subtotal strictly exceeds the budget
  bool isOverBudget(double subtotal) {
    return subtotal > _budgetAmount;
  }

  /// Returns true if 80% or more of the budget has been used, but not exceeded
  bool isNearLimit(double subtotal) {
    if (_budgetAmount <= 0) return false;
    final ratio = subtotal / _budgetAmount;
    return ratio >= 0.8 && ratio <= 1.0;
  }

  /// Returns true if subtotal equals budget exactly
  bool isBudgetReached(double subtotal) {
    return (subtotal - _budgetAmount).abs() < 0.01;
  }
}
