import 'package:flutter/foundation.dart';

import '../models/admin_order_data.dart';
import '../services/admin_order_service.dart';

class AdminOrderProvider extends ChangeNotifier {
  final AdminOrderDataSource dataSource;

  AdminOrderProvider({required this.dataSource});

  String? selectedStatus;
  List<AdminManagedOrder>? orders;
  AdminManagedOrder? orderDetails;
  String? orderDetailsId;
  bool isLoading = false;
  bool isDetailsLoading = false;
  bool isUpdating = false;
  String? loadError;
  String? detailsError;
  String? updateError;

  Future<void> loadOrders({String? status}) async {
    selectedStatus = status;
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      orders = await dataSource.loadOrders(status: status);
    } catch (error) {
      loadError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrderDetails(String orderId) async {
    orderDetailsId = orderId;
    orderDetails = null;
    isDetailsLoading = true;
    detailsError = null;
    notifyListeners();
    try {
      orderDetails = await dataSource.loadOrderDetails(orderId);
    } catch (error) {
      detailsError = error.toString();
    } finally {
      isDetailsLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String orderId, String nextStatus) async {
    final currentStatus = orderDetails?.status;
    if (orderDetailsId != orderId ||
        currentStatus == null ||
        !AdminOrderStatus.nextFor(currentStatus).contains(nextStatus)) {
      throw ArgumentError('This order status transition is not allowed.');
    }

    isUpdating = true;
    updateError = null;
    notifyListeners();
    try {
      await dataSource.updateOrderStatus(orderId, nextStatus);
      await Future.wait([
        loadOrderDetails(orderId),
        loadOrders(status: selectedStatus),
      ]);
    } catch (error) {
      updateError = error.toString();
      rethrow;
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }
}
