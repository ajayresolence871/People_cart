import 'package:flutter/foundation.dart';

import '../models/delivery_assignment_data.dart';
import '../services/delivery_assignment_service.dart';

class AdminDeliveryAssignmentProvider extends ChangeNotifier {
  final DeliveryAssignmentDataSource dataSource;

  AdminDeliveryAssignmentProvider({required this.dataSource});

  List<DeliveryManagedOrder>? orders;
  List<DeliveryPartner>? partners;
  bool isLoading = false;
  String? error;
  final Set<String> updatingOrderIds = {};
  String? actionError;
  String? actionMessage;
  int _loadGeneration = 0;
  bool _isDisposed = false;

  Future<void> load() async {
    if (_isDisposed) return;
    await _loadData();
  }

  Future<bool> _loadData() async {
    if (_isDisposed) return false;
    final generation = ++_loadGeneration;
    isLoading = true;
    error = null;
    _notifyListeners();
    try {
      final results = await Future.wait([
        dataSource.loadOrders(),
        dataSource.loadPartners(),
      ]);
      if (_isDisposed || generation != _loadGeneration) return true;
      orders = results[0] as List<DeliveryManagedOrder>;
      partners = results[1] as List<DeliveryPartner>;
      error = null;
      return true;
    } catch (exception) {
      if (_isDisposed || generation != _loadGeneration) return true;
      error = exception.toString();
      return false;
    } finally {
      if (!_isDisposed && generation == _loadGeneration) {
        isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> assign(String orderId, String? partnerId) async {
    if (_isDisposed) return false;
    final matchingOrders = orders?.where(
      (candidate) => candidate.id == orderId,
    );
    final order = matchingOrders == null || matchingOrders.isEmpty
        ? null
        : matchingOrders.first;
    if (order != null && order.isAssignmentLocked) {
      actionError = order.isOutForDelivery
          ? 'Partner assignment is locked after pickup.'
          : 'Completed or cancelled orders cannot be reassigned.';
      actionMessage = null;
      _notifyListeners();
      return false;
    }
    if (!updatingOrderIds.add(orderId)) {
      actionError = _duplicateAssignmentMessage;
      actionMessage = null;
      _notifyListeners();
      return false;
    }

    actionError = null;
    actionMessage = null;
    _notifyListeners();
    try {
      await dataSource.assignOrder(orderId, partnerId);
      final refreshed = await _loadData();
      if ((!refreshed || error != null) && !_isDisposed) {
        actionMessage =
            'Assignment saved, but the displayed data could not be refreshed: '
            '$error';
        _notifyListeners();
      }
      return true;
    } catch (exception) {
      if (!_isDisposed) actionError = exception.toString();
      return false;
    } finally {
      updatingOrderIds.remove(orderId);
      if (actionError == _duplicateAssignmentMessage) actionError = null;
      _notifyListeners();
    }
  }

  static const _duplicateAssignmentMessage =
      'An assignment for this order is already in progress.';

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadGeneration++;
    super.dispose();
  }
}

class DeliveryPartnerOrdersProvider extends ChangeNotifier {
  final DeliveryAssignmentDataSource dataSource;

  DeliveryPartnerOrdersProvider({required this.dataSource});

  List<DeliveryManagedOrder>? orders;
  bool isLoading = false;
  String? error;
  String? updatingOrderId;
  String? actionError;
  bool _isDisposed = false;

  Future<void> load() async {
    if (_isDisposed || isLoading || updatingOrderId != null) return;
    isLoading = true;
    error = null;
    _notifyListeners();
    try {
      orders = await dataSource.loadMyAssignedOrders();
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      _notifyListeners();
    }
  }

  Future<bool> updateStatus(String orderId, String status) async {
    if (_isDisposed) return false;
    if (isLoading || updatingOrderId != null) {
      actionError = 'Wait for the current request to finish, then try again.';
      _notifyListeners();
      return false;
    }

    final matchingOrders = orders?.where(
      (candidate) => candidate.id == orderId,
    );
    final order = matchingOrders == null || matchingOrders.isEmpty
        ? null
        : matchingOrders.first;
    if (order == null || !_isValidTransition(order.status, status)) {
      actionError = 'This order cannot be moved to that status.';
      _notifyListeners();
      return false;
    }

    updatingOrderId = orderId;
    actionError = null;
    _notifyListeners();
    try {
      await dataSource.updateMyOrderStatus(orderId, status);
      if (_isDisposed) return true;
      updatingOrderId = null;
      _notifyListeners();
      await load();
      return true;
    } catch (exception) {
      actionError = exception.toString();
      if (!_isDisposed) {
        updatingOrderId = null;
        _notifyListeners();
        await load();
      }
      return false;
    } finally {
      if (!_isDisposed) {
        updatingOrderId = null;
        _notifyListeners();
      }
    }
  }

  bool _isValidTransition(String currentStatus, String newStatus) =>
      (currentStatus == 'preparing' && newStatus == 'out_for_delivery') ||
      (currentStatus == 'out_for_delivery' && newStatus == 'delivered');

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
