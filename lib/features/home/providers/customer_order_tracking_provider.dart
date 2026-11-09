import 'package:flutter/foundation.dart';

import '../models/customer_order_tracking.dart';
import '../services/customer_order_tracking_service.dart';

class CustomerOrderTrackingProvider extends ChangeNotifier {
  final CustomerOrderTrackingDataSource _dataSource;
  CustomerOrderTracking? _currentOrder;
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  int _requestGeneration = 0;
  bool _disposed = false;

  CustomerOrderTrackingProvider({CustomerOrderTrackingDataSource? dataSource})
    : _dataSource = dataSource ?? CustomerOrderTrackingService();

  CustomerOrderTracking? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get requestedUserId => _userId;

  Future<void> refresh({String? userId}) async {
    final generation = ++_requestGeneration;
    if (_userId != userId) _currentOrder = null;
    _userId = userId;
    if (userId == null || userId.isEmpty) {
      _currentOrder = null;
      _errorMessage = null;
      _isLoading = false;
      _notifyIfAlive();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyIfAlive();
    try {
      final order = await _dataSource.getCurrentOrderForHome(userId: userId);
      if (!_isCurrentRequest(generation, userId)) return;
      _currentOrder = order;
    } catch (error) {
      if (!_isCurrentRequest(generation, userId)) return;
      debugPrint('CustomerOrderTrackingProvider.refresh failed: $error');
      _errorMessage = 'Could not load active order. Please try again.';
    } finally {
      if (_isCurrentRequest(generation, userId)) {
        _isLoading = false;
        _notifyIfAlive();
      }
    }
  }

  Future<CustomerOrderTracking?> loadOrderDetails({
    required String orderId,
    required String userId,
  }) {
    return _dataSource.getOrderDetails(orderId: orderId, userId: userId);
  }

  Future<void> cancelOrder({required String orderId, required String userId}) {
    return _dataSource.cancelOrder(orderId: orderId, userId: userId);
  }

  bool _isCurrentRequest(int generation, String userId) =>
      !_disposed && generation == _requestGeneration && _userId == userId;

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
