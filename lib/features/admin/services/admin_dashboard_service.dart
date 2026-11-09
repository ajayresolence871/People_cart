import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_dashboard_data.dart';

abstract class AdminDashboardDataSource {
  Future<AdminOrderMetrics> loadOrderMetrics();
  Future<List<AdminRecentOrder>> loadRecentOrders();
}

class AdminDashboardService implements AdminDashboardDataSource {
  static const int lowStockThreshold = 5;
  static const int recentOrderLimit = 3;
  static const List<String> orderStatuses = [
    'placed',
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  final SupabaseClient? _explicitClient;

  AdminDashboardService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'Supabase is not initialized. Admin data cannot be loaded.',
      );
    }
  }

  @override
  Future<AdminOrderMetrics> loadOrderMetrics() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfTrend = today.subtract(const Duration(days: 6));
    final endOfTrend = today.add(const Duration(days: 1));
    final counts = await Future.wait<int>([
      _countOrders(),
      ...orderStatuses.map((status) => _countOrders(status: status)),
    ]);

    final trendRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('orders')
          .select('created_at, total_amount, status')
          .gte('created_at', startOfTrend.toUtc().toIso8601String())
          .lt('created_at', endOfTrend.toUtc().toIso8601String())
          .order('created_at')
          .order('id')
          .range(offset, offset + 999);
      trendRows.addAll(page);
      if (page.length < 1000) break;
      offset += 1000;
    }

    final countsByDay = <DateTime, int>{};
    var ordersToday = 0;
    var nonCancelledOrderValueToday = 0.0;
    for (final row in trendRows) {
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      final local = createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      countsByDay.update(day, (count) => count + 1, ifAbsent: () => 1);
      if (day == today) {
        ordersToday++;
        if (row['status']?.toString() != 'cancelled') {
          nonCancelledOrderValueToday +=
              (row['total_amount'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    return AdminOrderMetrics(
      totalOrders: counts[0],
      ordersToday: ordersToday,
      ordersByStatus: {
        for (var index = 0; index < orderStatuses.length; index++)
          orderStatuses[index]: counts[index + 1],
      },
      nonCancelledOrderValueToday: nonCancelledOrderValueToday,
      dailyOrderCounts: [
        for (
          var day = startOfTrend;
          !day.isAfter(today);
          day = day.add(const Duration(days: 1))
        )
          AdminDailyOrderCount(date: day, count: countsByDay[day] ?? 0),
      ],
    );
  }

  Future<int> _countOrders({
    String? status,
    String? createdAtOrAfter,
    String? createdAtBefore,
  }) async {
    var query = _client.from('orders').select('id');
    if (status != null) query = query.eq('status', status);
    if (createdAtOrAfter != null) {
      query = query.gte('created_at', createdAtOrAfter);
    }
    if (createdAtBefore != null) {
      query = query.lt('created_at', createdAtBefore);
    }
    final response = await query.limit(1).count(CountOption.exact);
    return response.count;
  }

  @override
  Future<List<AdminRecentOrder>> loadRecentOrders() async {
    final rows = await _client
        .from('orders')
        .select('id, created_at, total_amount, status')
        .order('created_at', ascending: false)
        .limit(recentOrderLimit);

    return rows.map((row) {
      return AdminRecentOrder(
        id: row['id']?.toString() ?? '',
        createdAt: row['created_at'] == null
            ? null
            : DateTime.tryParse(row['created_at'].toString()),
        totalAmount: (row['total_amount'] as num?)?.toDouble(),
        status: row['status']?.toString() ?? 'unknown',
      );
    }).toList();
  }
}
