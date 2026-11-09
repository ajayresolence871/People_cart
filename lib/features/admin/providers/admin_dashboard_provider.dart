import 'package:flutter/foundation.dart';

import '../models/admin_dashboard_data.dart';
import '../services/admin_dashboard_service.dart';

class AdminDashboardProvider extends ChangeNotifier {
  final AdminDashboardDataSource dataSource;

  AdminDashboardProvider({required this.dataSource});

  AdminOrderMetrics? metrics;
  List<AdminRecentOrder>? recentOrders;

  bool isMetricsLoading = false;
  bool isRecentOrdersLoading = false;
  String? metricsError;
  String? recentOrdersError;

  bool get isLoading => isMetricsLoading || isRecentOrdersLoading;

  Future<void> loadDashboard() async {
    await Future.wait([_loadMetrics(), _loadRecentOrders()]);
  }

  Future<void> _loadMetrics() async {
    isMetricsLoading = true;
    metricsError = null;
    notifyListeners();
    try {
      metrics = await dataSource.loadOrderMetrics();
    } catch (error) {
      metricsError = error.toString();
    } finally {
      isMetricsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecentOrders() async {
    isRecentOrdersLoading = true;
    recentOrdersError = null;
    notifyListeners();
    try {
      recentOrders = await dataSource.loadRecentOrders();
    } catch (error) {
      recentOrdersError = error.toString();
    } finally {
      isRecentOrdersLoading = false;
      notifyListeners();
    }
  }
}
