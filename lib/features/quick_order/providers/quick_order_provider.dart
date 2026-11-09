import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../models/predefined_modes.dart';
import '../models/quick_order_mode.dart';
import '../services/quick_order_service.dart';

class QuickOrderAddResult {
  final bool success;
  final String modeName;
  final int addedItemCount;
  final int totalUnits;
  final double newSubtotal;
  final List<String> unavailableItems;
  final List<String> cappedItems;

  QuickOrderAddResult({
    required this.success,
    required this.modeName,
    required this.addedItemCount,
    required this.totalUnits,
    required this.newSubtotal,
    this.unavailableItems = const [],
    this.cappedItems = const [],
  });

  String get summaryMessage {
    if (addedItemCount == 0) {
      return 'No available items in "$modeName" could be added.';
    }
    String msg = 'Added $totalUnits ${totalUnits == 1 ? "item" : "items"} from "$modeName" to cart!';
    if (unavailableItems.isNotEmpty) {
      msg += ' (${unavailableItems.length} unavailable item(s) skipped)';
    }
    return msg;
  }
}

class QuickOrderProvider extends ChangeNotifier {
  static const String _hiddenPresetsKey = 'pc_hidden_predefined_modes';

  final QuickOrderService _service;

  List<QuickOrderMode> _predefinedModes = [];
  List<QuickOrderMode> _customModes = [];
  List<Product> _cachedCatalog = [];
  final Set<String> _hiddenPresetIds = {};
  String? _currentUserId;

  bool _isLoading = false;
  bool _isAddingToCart = false;
  String? _errorMessage;

  QuickOrderProvider({QuickOrderService? service})
      : _service = service ?? QuickOrderService();

  List<QuickOrderMode> get predefinedModes => [..._predefinedModes];
  List<QuickOrderMode> get customModes => [..._customModes];
  List<QuickOrderMode> get allModes => [..._customModes, ..._predefinedModes];

  bool get isLoading => _isLoading;
  bool get isAddingToCart => _isAddingToCart;
  String? get errorMessage => _errorMessage;
  bool get hasHiddenPresets => _hiddenPresetIds.isNotEmpty;
  String? get currentUserId => _currentUserId;

  /// Resets in-memory modes and clears active user session
  void clearModes() {
    _predefinedModes.clear();
    _customModes.clear();
    _currentUserId = null;
    _errorMessage = null;
    _isLoading = false;
    _isAddingToCart = false;
    notifyListeners();
  }

  /// Loads and resolves modes using current product catalog.
  /// For authenticated users (userId != null): NO default presets are loaded;
  /// new users start with nothing default and create their own custom modes.
  /// For unauthenticated / standalone test environments (userId == null):
  /// resolves default preset templates from catalog.
  Future<void> loadModes(List<Product> catalog, {String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    _cachedCatalog = catalog;
    if (userId != null) {
      _currentUserId = userId;
    }
    notifyListeners();

    try {
      if (_currentUserId == null) {
        // 0. Load hidden preset IDs from local storage (unauthenticated test harness only)
        try {
          final prefs = await SharedPreferences.getInstance();
          final hiddenList = prefs.getStringList(_hiddenPresetsKey) ?? [];
          _hiddenPresetIds.clear();
          _hiddenPresetIds.addAll(hiddenList);
        } catch (e) {
          debugPrint('QuickOrderProvider: error reading hidden presets: $e');
        }

        // 1. Resolve Predefined Modes from templates for unauthenticated testing
        final allPredefined = PredefinedModesCatalog.resolveAll(catalog);
        _predefinedModes = allPredefined
            .where((m) => !_hiddenPresetIds.contains(m.id))
            .toList();
      } else {
        // Authenticated user: NO default presets! New accounts start with 0 modes.
        _predefinedModes.clear();
        _hiddenPresetIds.clear();
      }

      // 2. Load user-scoped Custom Modes
      _customModes = await _service.loadCustomModes(catalog, userId: _currentUserId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not load quick order modes: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes/hides a predefined preset mode and saves state
  Future<bool> deletePresetMode(String id) async {
    _hiddenPresetIds.add(id);
    _predefinedModes.removeWhere((m) => m.id == id);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenPresetsKey, _hiddenPresetIds.toList());
      return true;
    } catch (e) {
      debugPrint('QuickOrderProvider: error saving hidden presets: $e');
      return false;
    }
  }

  /// Restores all default predefined presets
  Future<bool> restoreDefaultPresets() async {
    _hiddenPresetIds.clear();
    _predefinedModes = PredefinedModesCatalog.resolveAll(_cachedCatalog);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hiddenPresetsKey);
      return true;
    } catch (e) {
      debugPrint('QuickOrderProvider: error removing hidden presets: $e');
      return false;
    }
  }

  /// Creates a new custom mode with validation
  Future<bool> createCustomMode({
    required String name,
    required Map<Product, int> items,
    String iconName = 'custom',
    String? tagline,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Collection name cannot be empty';
      notifyListeners();
      return false;
    }

    if (items.isEmpty) {
      _errorMessage = 'Please add at least one product to this mode';
      notifyListeners();
      return false;
    }

    // Convert map to QuickOrderItem list, ensuring unique products
    final List<QuickOrderItem> orderItems = [];
    final Set<String> seenIds = {};

    for (final entry in items.entries) {
      final product = entry.key;
      final qty = entry.value;
      if (qty <= 0 || seenIds.contains(product.id)) continue;

      seenIds.add(product.id);
      orderItems.add(
        QuickOrderItem(
          productId: product.id,
          quantity: qty,
          product: product,
          customTitle: product.name,
        ),
      );
    }

    if (orderItems.isEmpty) {
      _errorMessage = 'At least one valid product is required';
      notifyListeners();
      return false;
    }

    final newMode = QuickOrderMode(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      iconName: iconName,
      tagline: tagline ?? '${orderItems.length} items custom shortcut',
      isPredefined: false,
      items: orderItems,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _customModes.insert(0, newMode);
    notifyListeners();

    await _service.saveCustomMode(newMode, _customModes, userId: _currentUserId);
    return true;
  }

  /// Updates an existing custom mode
  Future<bool> updateCustomMode({
    required String id,
    required String name,
    required Map<Product, int> items,
    String? iconName,
    String? tagline,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Collection name cannot be empty';
      notifyListeners();
      return false;
    }

    if (items.isEmpty) {
      _errorMessage = 'Please add at least one product';
      notifyListeners();
      return false;
    }

    final existingIndex = _customModes.indexWhere((m) => m.id == id);
    if (existingIndex < 0) return false;

    final List<QuickOrderItem> orderItems = [];
    final Set<String> seenIds = {};

    for (final entry in items.entries) {
      final product = entry.key;
      final qty = entry.value;
      if (qty <= 0 || seenIds.contains(product.id)) continue;

      seenIds.add(product.id);
      orderItems.add(
        QuickOrderItem(
          productId: product.id,
          quantity: qty,
          product: product,
          customTitle: product.name,
        ),
      );
    }

    final updatedMode = _customModes[existingIndex].copyWith(
      name: cleanName,
      iconName: iconName,
      tagline: tagline ?? '${orderItems.length} items custom shortcut',
      items: orderItems,
      updatedAt: DateTime.now(),
    );

    _customModes[existingIndex] = updatedMode;
    notifyListeners();

    await _service.saveCustomMode(updatedMode, _customModes, userId: _currentUserId);
    return true;
  }

  /// Deletes a custom mode (never modifies or touches the actual cart)
  Future<bool> deleteCustomMode(String id) async {
    _customModes.removeWhere((m) => m.id == id);
    notifyListeners();

    await _service.deleteCustomMode(id, _customModes, userId: _currentUserId);
    return true;
  }

  /// One-tap Add All to Personal Cart with rapid-tap debounce and stock verification
  Future<QuickOrderAddResult> addAllToCart(
    QuickOrderMode mode,
    CartProvider cart,
  ) async {
    // Debounce rapid repeated taps
    if (_isAddingToCart) {
      return QuickOrderAddResult(
        success: false,
        modeName: mode.name,
        addedItemCount: 0,
        totalUnits: 0,
        newSubtotal: cart.subtotal,
      );
    }

    _isAddingToCart = true;
    notifyListeners();

    try {
      final Map<Product, int> itemsToAdd = {};
      final List<String> unavailable = [];
      final List<String> capped = [];
      int totalUnits = 0;

      for (final item in mode.items) {
        // Find latest product instance in catalog or item
        Product? product = item.product;
        if (product == null && _cachedCatalog.isNotEmpty) {
          try {
            product = _cachedCatalog.firstWhere((p) => p.id == item.productId);
          } catch (_) {
            product = null;
          }
        }

        if (product == null || !product.isAvailable) {
          unavailable.add(item.displayName);
          continue;
        }

        int qtyToAdd = item.quantity;

        // Check stock quantity if tracked (> 0)
        if (product.stockQuantity > 0) {
          final currentCartQty = cart.getQuantity(product.id);
          final maxAllowed = product.stockQuantity - currentCartQty;
          if (maxAllowed <= 0) {
            capped.add(product.name);
            continue;
          } else if (qtyToAdd > maxAllowed) {
            qtyToAdd = maxAllowed;
            capped.add(product.name);
          }
        }

        if (qtyToAdd > 0) {
          itemsToAdd[product] = qtyToAdd;
          totalUnits += qtyToAdd;
        }
      }

      if (itemsToAdd.isNotEmpty) {
        // Add to personal CartProvider
        cart.addBatchProducts(itemsToAdd);
      }

      final result = QuickOrderAddResult(
        success: itemsToAdd.isNotEmpty,
        modeName: mode.name,
        addedItemCount: itemsToAdd.length,
        totalUnits: totalUnits,
        newSubtotal: cart.subtotal,
        unavailableItems: unavailable,
        cappedItems: capped,
      );

      _isAddingToCart = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isAddingToCart = false;
      notifyListeners();
      return QuickOrderAddResult(
        success: false,
        modeName: mode.name,
        addedItemCount: 0,
        totalUnits: 0,
        newSubtotal: cart.subtotal,
      );
    }
  }
}
