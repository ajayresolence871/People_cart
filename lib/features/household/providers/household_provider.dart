import 'package:flutter/foundation.dart';

import '../../../models/product.dart';
import '../models/household.dart';
import '../models/shared_basket_item.dart';
import '../services/household_service.dart';

class HouseholdProvider extends ChangeNotifier {
  final HouseholdService _service;

  int _selectedTabIndex = 0; // 0: 'For me & family', 1: 'Myself'
  Household? _household;
  List<SharedBasketItem> _sharedItems = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  HouseholdProvider({HouseholdService? service, bool autoLoad = true})
    : _service = service ?? HouseholdService() {
    if (autoLoad) {
      loadHouseholdData();
    }
  }

  int get selectedTabIndex => _selectedTabIndex;
  Household? get household => _household;
  bool get hasHousehold => _household != null;
  List<SharedBasketItem> get sharedItems => [..._sharedItems];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  double get sharedSubtotal {
    return _sharedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get sharedTotalQuantity {
    return _sharedItems.fold(0, (sum, item) => sum + item.quantity);
  }

  List<SharedBasketItem> get filteredSharedItems {
    if (_searchQuery.trim().isEmpty) {
      return _sharedItems;
    }
    final q = _searchQuery.trim().toLowerCase();
    return _sharedItems
        .where((item) => item.product.name.toLowerCase().contains(q))
        .toList();
  }

  void setTabIndex(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Clears household data from memory on logout
  void clearHousehold() {
    _household = null;
    _sharedItems = [];
    _isLoading = false;
    _errorMessage = null;
    _searchQuery = '';
    notifyListeners();
  }

  /// Loads current household and its shared basket
  Future<void> loadHouseholdData() async {
    _isLoading = true;
    _errorMessage = null;
    _sharedItems = [];
    notifyListeners();

    try {
      _household = await _service.getCurrentUserHousehold();
      if (_household != null) {
        _sharedItems = await _service.getSharedBasketItems(_household!.id);
      } else {
        _sharedItems = [];
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not load household data: $e';
      _sharedItems = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new household
  Future<bool> createHousehold(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _household = await _service.createHousehold(name);
      _sharedItems = [];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Joins an existing household using code
  Future<bool> joinHousehold(String joinCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _household = await _service.joinHouseholdByCode(joinCode);
      if (_household != null) {
        _sharedItems = await _service.getSharedBasketItems(_household!.id);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Adds a product to the shared household basket
  Future<void> addSharedProduct(Product product, {int quantity = 1}) async {
    if (_household == null) return;
    try {
      _errorMessage = null;
      _service.requireAuthenticatedUserId();
      await _service.addItemToSharedBasket(
        _household!.id,
        product,
        quantity: quantity,
      );
      await _refreshSharedItems();
    } catch (error) {
      _errorMessage =
          'Could not add ${product.name} to the shared basket: $error';
      notifyListeners();
      rethrow;
    }
  }

  /// Increments quantity of a shared item
  Future<void> incrementItem(SharedBasketItem item) async {
    await _changeItemQuantity(item, item.quantity + 1);
  }

  /// Decrements quantity or removes if quantity becomes 0
  Future<void> decrementItem(SharedBasketItem item) async {
    await _changeItemQuantity(item, item.quantity - 1);
  }

  Future<void> _changeItemQuantity(
    SharedBasketItem item,
    int newQuantity,
  ) async {
    try {
      _errorMessage = null;
      await _service.updateItemQuantity(item.id, newQuantity);
      await _refreshSharedItems();
    } catch (error) {
      _errorMessage = 'Could not update ${item.product.name}: $error';
      notifyListeners();
      rethrow;
    }
  }

  /// Removes an item completely from the shared basket
  Future<void> removeItem(String itemId) async {
    try {
      _errorMessage = null;
      await _service.removeItemFromSharedBasket(itemId);
      await _refreshSharedItems();
    } catch (error) {
      _errorMessage = 'Could not remove item from the shared basket: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeItemsAfterCheckout(Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    try {
      _errorMessage = null;
      await _service.removeItemsFromSharedBasket(ids);
      await _refreshSharedItems();
    } catch (error) {
      _errorMessage = 'Order placed, but shared basket cleanup failed: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshSharedItems() async {
    final household = _household;
    if (household == null) return;
    _sharedItems = await _service.getSharedBasketItems(household.id);
    notifyListeners();
  }
}
