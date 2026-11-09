import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/product_service.dart';
import '../models/wishlist_entry.dart';
import '../services/wishlist_service.dart';

typedef WishlistCatalogLookup = Future<List<Product>> Function(
  Iterable<String> productIds,
);

class WishlistProvider extends ChangeNotifier {
  final WishlistDataSource _dataSource;
  final WishlistCatalogLookup _loadProductsByIds;
  final AuthProvider? _authProvider;

  String? _userId;
  Set<String> _productIds = {};
  List<Product> _products = [];
  final Map<String, int> _pendingProductOperations = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  int _loadGeneration = 0;
  int _userGeneration = 0;
  int _operationGeneration = 0;
  bool _disposed = false;

  WishlistProvider({
    String? userId,
    AuthProvider? authProvider,
    WishlistDataSource? dataSource,
    WishlistCatalogLookup? loadProductsByIds,
    bool autoLoad = true,
  }) : _dataSource = dataSource ?? WishlistService(),
       _loadProductsByIds =
           loadProductsByIds ?? ProductService().getProductsByIds,
       // ignore: prefer_initializing_formals
       _authProvider = authProvider,
       // ignore: prefer_initializing_formals
       _userId = userId {
    if (_authProvider != null) {
      _userId = _authenticatedCustomerId(_authProvider);
      _authProvider.addListener(_handleAuthChanged);
    }
    if (autoLoad && _userId != null) unawaited(load());
  }

  String? get userId => _userId;
  Set<String> get productIds => Set.unmodifiable(_productIds);
  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  bool get hasPendingChanges => _pendingProductOperations.isNotEmpty;

  bool contains(String productId) => _productIds.contains(productId);
  bool isPending(String productId) =>
      _pendingProductOperations.containsKey(productId);

  Future<void> load({bool force = false}) async {
    if (_isLoading || hasPendingChanges || (_hasLoaded && !force)) return;

    final activeUserId = _userId;
    if (activeUserId == null) {
      _error = 'Sign in to manage your wishlist.';
      _notifyIfAlive();
      return;
    }

    final generation = ++_loadGeneration;
    _isLoading = true;
    _error = null;
    _notifyIfAlive();

    try {
      final entries = await _dataSource.loadEntries(
        expectedUserId: activeUserId,
      );
      final ids = entries.map((entry) => entry.productId).toSet();
      final products = await _loadProductsByIds(ids);
      if (_disposed ||
          generation != _loadGeneration ||
          activeUserId != _userId) {
        return;
      }

      _productIds = ids;
      _products = _sortBySavedOrder(products, entries);
      _hasLoaded = true;
    } catch (error) {
      if (_disposed ||
          generation != _loadGeneration ||
          activeUserId != _userId) {
        return;
      }
      _error = error.toString();
    } finally {
      if (!_disposed &&
          generation == _loadGeneration &&
          activeUserId == _userId) {
        _isLoading = false;
        _notifyIfAlive();
      }
    }
  }

  Future<bool> toggleProduct(String productId, {Product? product}) async {
    final activeUserId = _userId;
    if (productId.isEmpty ||
        activeUserId == null ||
        !_hasLoaded ||
        _isLoading ||
        isPending(productId)) {
      return false;
    }

    final wasSaved = _productIds.contains(productId);
    final userGeneration = _userGeneration;
    final operation = ++_operationGeneration;
    _pendingProductOperations[productId] = operation;
    _error = null;
    if (wasSaved) {
      _productIds.remove(productId);
      _products.removeWhere((item) => item.id == productId);
    } else {
      _productIds.add(productId);
      if (product != null && !_products.any((item) => item.id == productId)) {
        _products = [..._products, product];
      }
    }
    _notifyIfAlive();

    try {
      if (wasSaved) {
        await _dataSource.removeProduct(
          productId,
          expectedUserId: activeUserId,
        );
      } else {
        await _dataSource.addProduct(productId, expectedUserId: activeUserId);
      }
      return true;
    } catch (error) {
      if (_userGeneration == userGeneration &&
          _pendingProductOperations[productId] == operation) {
        if (wasSaved) {
          _productIds.add(productId);
          if (product != null &&
              !_products.any((item) => item.id == productId)) {
            _products = [..._products, product];
          }
        } else {
          _productIds.remove(productId);
          _products.removeWhere((item) => item.id == productId);
        }
        _error = error.toString();
      }
      return false;
    } finally {
      if (_pendingProductOperations[productId] == operation) {
        _pendingProductOperations.remove(productId);
        _notifyIfAlive();
      }
    }
  }

  String? _authenticatedCustomerId(AuthProvider? auth) {
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.isProfileLoading ||
        auth.role != 'customer' ||
        auth.profile == null) {
      return null;
    }
    return auth.user?.id ?? auth.profile!.id;
  }

  void _handleAuthChanged() {
    final nextUserId = _authenticatedCustomerId(_authProvider);
    if (nextUserId != _userId) setUserId(nextUserId);
  }

  void setUserId(String? nextUserId) {
    if (_userId == nextUserId) return;
    _userId = nextUserId;
    _userGeneration++;
    _loadGeneration++;
    _productIds = {};
    _products = [];
    _pendingProductOperations.clear();
    _isLoading = false;
    _hasLoaded = false;
    _error = null;
    _notifyIfAlive();
    if (nextUserId != null) unawaited(load());
  }

  List<Product> _sortBySavedOrder(
    List<Product> products,
    List<WishlistEntry> entries,
  ) {
    final order = {
      for (var index = 0; index < entries.length; index++)
        entries[index].productId: index,
    };
    final orderedProducts = [...products];
    orderedProducts.sort(
      (a, b) => (order[a.id] ?? entries.length).compareTo(
        order[b.id] ?? entries.length,
      ),
    );
    return orderedProducts;
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _authProvider?.removeListener(_handleAuthChanged);
    super.dispose();
  }
}
