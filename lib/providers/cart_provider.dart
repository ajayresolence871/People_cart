import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/customer_event_service.dart';

enum CartOperationStatus { success, outOfStock, maxStockReached, removed }

class CartOperationResult {
  final CartOperationStatus status;
  final String message;
  final int currentQuantity;
  final int stockQuantity;

  const CartOperationResult({
    required this.status,
    required this.message,
    required this.currentQuantity,
    required this.stockQuantity,
  });

  bool get isSuccess => status == CartOperationStatus.success;
  bool get isOutOfStock => status == CartOperationStatus.outOfStock;
  bool get isMaxStockReached => status == CartOperationStatus.maxStockReached;
  bool get isRemoved => status == CartOperationStatus.removed;
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  final CustomerEventLogger _eventLogger;

  CartProvider({CustomerEventLogger? eventLogger})
    : _eventLogger = eventLogger ?? CustomerEventService();

  // Free delivery threshold as featured in the Zepto UI screenshot ("Shop for ₹49 -> Unlock free delivery")
  static const double freeDeliveryThreshold = 49.0;

  Map<String, CartItem> get items => {..._items};

  List<CartItem> get itemList => _items.values.toList();

  int get distinctItemCount => _items.length;

  int get totalQuantity {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    return _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  bool get isFreeDeliveryUnlocked => subtotal >= freeDeliveryThreshold;

  double get amountNeededForFreeDelivery {
    final remaining = freeDeliveryThreshold - subtotal;
    return remaining > 0 ? remaining : 0.0;
  }

  double get freeDeliveryProgress {
    if (subtotal <= 0) return 0.0;
    return (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0);
  }

  // Bill Summary & Savings calculations matching Zepto Checkout UI
  double get mrpTotal {
    return _items.values.fold(
      0.0,
      (sum, item) => sum + (item.product.originalPrice * item.quantity),
    );
  }

  double get discountOnMrp {
    final diff = mrpTotal - subtotal;
    return diff > 0 ? diff : 0.0;
  }

  double get deliveryFee => isFreeDeliveryUnlocked ? 0.0 : 30.0;

  double get handlingFee => 0.0;

  double get totalSavings =>
      discountOnMrp + (isFreeDeliveryUnlocked ? 30.0 : 0.0) + 10.0;

  double get toPayAmount => subtotal + deliveryFee;

  int getQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  bool containsProduct(String productId) {
    return _items.containsKey(productId);
  }

  /// Checks if a product is available with at least 1 unit in stock
  bool isProductAvailable(Product product) {
    return product.isAvailable && product.stockQuantity > 0;
  }

  bool isOutOfStock(Product product) {
    return !isProductAvailable(product);
  }

  /// Checks if quantity can be incremented without exceeding stock limit
  bool canIncrement(Product product) {
    if (!isProductAvailable(product)) return false;
    final current = getQuantity(product.id);
    return current < product.stockQuantity;
  }

  /// Returns remaining available units for this product
  int getRemainingStock(Product product) {
    if (!product.isAvailable) return 0;
    final remaining = product.stockQuantity - getQuantity(product.id);
    return remaining > 0 ? remaining : 0;
  }

  /// Adds 1 unit of product to personal cart respecting stock limit
  CartOperationResult addItem(Product product) {
    if (!isProductAvailable(product)) {
      return CartOperationResult(
        status: CartOperationStatus.outOfStock,
        message: '${product.name} is currently out of stock.',
        currentQuantity: getQuantity(product.id),
        stockQuantity: product.stockQuantity,
      );
    }

    final currentQty = getQuantity(product.id);
    if (currentQty >= product.stockQuantity) {
      return CartOperationResult(
        status: CartOperationStatus.maxStockReached,
        message: 'Cannot add more. Only ${product.stockQuantity} in stock.',
        currentQuantity: currentQty,
        stockQuantity: product.stockQuantity,
      );
    }

    if (currentQty == 0) {
      _items[product.id] = CartItem(product: product, quantity: 1);
    } else {
      _items[product.id]!.quantity += 1;
      _items[product.id] = _items[product.id]!.copyWith(product: product);
    }

    notifyListeners();
    logEventWithoutBlocking(_eventLogger.logAddToCart(product.id));

    return CartOperationResult(
      status: CartOperationStatus.success,
      message: 'Added to cart',
      currentQuantity: _items[product.id]!.quantity,
      stockQuantity: product.stockQuantity,
    );
  }

  /// Alias for addItem to standardize across all screens
  CartOperationResult incrementQuantity(Product product) {
    return addItem(product);
  }

  /// Decrements quantity by 1; removes completely when quantity reaches 0
  CartOperationResult removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return const CartOperationResult(
        status: CartOperationStatus.removed,
        message: 'Item not in cart',
        currentQuantity: 0,
        stockQuantity: 0,
      );
    }

    final item = _items[productId]!;
    if (item.quantity > 1) {
      item.quantity -= 1;
      final newQty = item.quantity;
      notifyListeners();
      return CartOperationResult(
        status: CartOperationStatus.success,
        message: 'Quantity updated',
        currentQuantity: newQty,
        stockQuantity: item.product.stockQuantity,
      );
    } else {
      _items.remove(productId);
      notifyListeners();
      return const CartOperationResult(
        status: CartOperationStatus.removed,
        message: 'Item removed from cart',
        currentQuantity: 0,
        stockQuantity: 0,
      );
    }
  }

  /// Alias for removeSingleItem to standardize across all screens
  CartOperationResult decrementQuantity(Product product) {
    return removeSingleItem(product.id);
  }

  /// Adds a specific quantity up to available stock limit
  int addProductWithQuantity(Product product, int quantity) {
    if (quantity <= 0 || !isProductAvailable(product)) return 0;

    final currentQty = getQuantity(product.id);
    final maxAddable = product.stockQuantity - currentQty;
    if (maxAddable <= 0) return 0;

    final actualAdd = quantity > maxAddable ? maxAddable : quantity;
    if (currentQty == 0) {
      _items[product.id] = CartItem(product: product, quantity: actualAdd);
    } else {
      _items[product.id]!.quantity += actualAdd;
      _items[product.id] = _items[product.id]!.copyWith(product: product);
    }

    notifyListeners();
    return actualAdd;
  }

  /// Adds a batch of products (used by Quick-Order Modes and Reorder) in one notification
  Map<Product, int> addBatchProducts(Map<Product, int> productQuantities) {
    final Map<Product, int> added = {};
    if (productQuantities.isEmpty) return added;

    for (final entry in productQuantities.entries) {
      final product = entry.key;
      final requestedQty = entry.value;
      if (requestedQty <= 0 || !isProductAvailable(product)) continue;

      final currentQty = getQuantity(product.id);
      final maxAddable = product.stockQuantity - currentQty;
      if (maxAddable <= 0) continue;

      final actualAdd = requestedQty > maxAddable ? maxAddable : requestedQty;
      if (currentQty == 0) {
        _items[product.id] = CartItem(product: product, quantity: actualAdd);
      } else {
        _items[product.id]!.quantity += actualAdd;
        _items[product.id] = _items[product.id]!.copyWith(product: product);
      }
      added[product] = actualAdd;
    }

    if (added.isNotEmpty) {
      notifyListeners();
    }
    return added;
  }

  /// Handles stale stock information gracefully by re-validating cart items
  /// against the latest known catalog products.
  List<String> validateCartAgainstStock(List<Product> latestCatalog) {
    final List<String> notices = [];
    bool modified = false;

    for (final cartItem in itemList) {
      final pid = cartItem.product.id;
      final matchingProduct = latestCatalog.where((p) => p.id == pid).toList();

      if (matchingProduct.isEmpty ||
          !matchingProduct.first.isAvailable ||
          matchingProduct.first.stockQuantity <= 0) {
        // Item is no longer available or out of stock
        _items.remove(pid);
        notices.add(
          '"${cartItem.product.name}" was removed because it is out of stock.',
        );
        modified = true;
      } else {
        final latest = matchingProduct.first;
        if (cartItem.quantity > latest.stockQuantity) {
          // Quantity exceeds new reduced stock
          final oldQty = cartItem.quantity;
          _items[pid] = cartItem.copyWith(
            product: latest,
            quantity: latest.stockQuantity,
          );
          notices.add(
            'Quantity for "${latest.name}" adjusted from $oldQty to ${latest.stockQuantity} due to stock limits.',
          );
          modified = true;
        } else if (cartItem.product.price != latest.price ||
            cartItem.product.stockQuantity != latest.stockQuantity) {
          // Update product price/stock reference
          _items[pid] = cartItem.copyWith(product: latest);
          modified = true;
        }
      }
    }

    if (modified) {
      notifyListeners();
    }
    return notices;
  }

  void removeItemCompletely(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
