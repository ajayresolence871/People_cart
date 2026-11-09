class AdminOrderMetrics {
  final int totalOrders;
  final int ordersToday;
  final Map<String, int> ordersByStatus;
  final double nonCancelledOrderValueToday;
  final List<AdminDailyOrderCount> dailyOrderCounts;

  const AdminOrderMetrics({
    required this.totalOrders,
    required this.ordersToday,
    required this.ordersByStatus,
    this.nonCancelledOrderValueToday = 0,
    this.dailyOrderCounts = const [],
  });
}

class AdminDailyOrderCount {
  final DateTime date;
  final int count;

  const AdminDailyOrderCount({required this.date, required this.count});
}

class AdminRecentOrder {
  final String id;
  final DateTime? createdAt;
  final double? totalAmount;
  final String status;

  const AdminRecentOrder({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
  });
}
