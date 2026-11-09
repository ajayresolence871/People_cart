import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/product_service.dart';
import '../models/order_history_item.dart';

class OrderHistoryService {
  static const String _storageKey = 'pc_order_history_list';

  static final OrderHistoryService _instance = OrderHistoryService._internal();
  final ProductCatalogDataSource _productCatalog;

  factory OrderHistoryService() => _instance;
  OrderHistoryService._internal() : _productCatalog = ProductService();

  OrderHistoryService.withProductCatalog(this._productCatalog);

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Record an order when placed (both in memory/cache and user-scoped storage)
  Future<void> recordOrder(OrderHistoryItem order, {String? userId}) async {
    try {
      final activeUserId = userId ?? _client?.auth.currentUser?.id;
      final orders = await getOrders(
        userId: activeUserId,
        includeMocksIfEmpty: false,
      );
      orders.insert(0, order);

      final prefs = await SharedPreferences.getInstance();
      final jsonList = orders.map((o) => o.toJson()).toList();

      final key = activeUserId != null
          ? '${_storageKey}_$activeUserId'
          : _storageKey;
      await prefs.setString(key, jsonEncode(jsonList));
      debugPrint(
        'OrderHistoryService: Recorded order ${order.orderId} for user: $activeUserId',
      );
    } catch (e) {
      debugPrint('OrderHistoryService.recordOrder error: $e');
    }
  }

  /// Get list of orders for a user. Real Supabase orders first, user-scoped cache second.
  /// Never returns mock orders for a user with an active userId!
  Future<List<OrderHistoryItem>> getOrders({
    String? userId,
    bool includeMocksIfEmpty = true,
  }) async {
    final activeUserId = userId ?? _client?.auth.currentUser?.id;

    if (activeUserId != null) {
      // 1. If Supabase client is available, query real orders from Supabase orders & order_items
      final client = _client;
      if (client != null) {
        var liveQuerySucceeded = false;
        try {
          final List<dynamic> response = await client
              .from('orders')
              .select(
                'id, total_amount, status, created_at, delivery_address_snapshot, '
                'order_items(id, product_id, product_name, quantity, unit_price)',
              )
              .eq('user_id', activeUserId)
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 2));
          liveQuerySucceeded = true;

          final List<OrderHistoryItem> liveOrders = [];
          for (final row in response) {
            final itemsRaw = row['order_items'] as List<dynamic>? ?? [];
            final items = itemsRaw.map((it) {
              return OrderItemSummary(
                productId: it['product_id']?.toString() ?? '',
                productName: it['product_name']?.toString() ?? 'Product',
                quantity: (it['quantity'] as num?)?.toInt() ?? 1,
                unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0.0,
              );
            }).toList();

            liveOrders.add(
              OrderHistoryItem(
                orderId: 'PC-${row['id']}',
                status: _formatStatus(row['status']?.toString()),
                createdAt: row['created_at'] != null
                    ? DateTime.tryParse(row['created_at'].toString()) ??
                          DateTime.now()
                    : DateTime.now(),
                totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0.0,
                deliveryAddress: _addressFromSnapshot(
                  row['delivery_address_snapshot'],
                ),
                items: items,
              ),
            );
          }

          if (liveOrders.isNotEmpty) {
            final ordersWithImages = await _attachCatalogImages(liveOrders);
            try {
              final prefs = await SharedPreferences.getInstance();
              final jsonList = ordersWithImages.map((o) => o.toJson()).toList();
              await prefs.setString(
                '${_storageKey}_$activeUserId',
                jsonEncode(jsonList),
              );
            } catch (_) {}
            return ordersWithImages;
          }
          if (liveQuerySucceeded) return [];
        } catch (e) {
          debugPrint('OrderHistoryService: Error querying Supabase orders: $e');
        }
      }

      // 2. Check user-scoped local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('${_storageKey}_$activeUserId');
        if (jsonString != null && jsonString.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(jsonString);
          return decoded
              .map(
                (item) =>
                    OrderHistoryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('OrderHistoryService local read error: $e');
      }

      // A real customer with 0 orders must see 0 orders. Never inject fake orders!
      return [];
    }

    // 3. Unauthenticated / test environment fallback (activeUserId == null)
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded
            .map(
              (item) => OrderHistoryItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }

      if (includeMocksIfEmpty) {
        final defaults = _defaultMockOrders();
        final jsonList = defaults.map((o) => o.toJson()).toList();
        await prefs.setString(_storageKey, jsonEncode(jsonList));
        return defaults;
      }
      return [];
    } catch (e) {
      debugPrint('OrderHistoryService.getOrders fallback error: $e');
      return includeMocksIfEmpty ? _defaultMockOrders() : [];
    }
  }

  Future<List<OrderHistoryItem>> _attachCatalogImages(
    List<OrderHistoryItem> orders,
  ) async {
    final productIds = orders
        .expand((order) => order.items)
        .map((item) => item.productId)
        .where((id) => id.isNotEmpty);
    try {
      final products = await _productCatalog.getProductsByIds(productIds);
      return orders
          .map(
            (order) => OrderHistoryItem(
              orderId: order.orderId,
              status: order.status,
              createdAt: order.createdAt,
              totalAmount: order.totalAmount,
              paymentMethod: order.paymentMethod,
              deliveryAddress: order.deliveryAddress,
              items: OrderItemSummary.withCatalogImages(order.items, products),
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('OrderHistoryService: Could not load product images: $error');
      return orders;
    }
  }

  String _formatStatus(String? raw) {
    if (raw == null) return 'Unknown status';
    switch (raw.toLowerCase()) {
      case 'placed':
        return 'Order Placed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw;
    }
  }

  String? _addressFromSnapshot(dynamic rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final houseNo = address['house_no']?.toString().trim() ?? '';
    final area = address['area']?.toString().trim() ?? '';
    final landmark = address['landmark']?.toString().trim() ?? '';
    final parts = [
      if (houseNo.isNotEmpty) houseNo,
      if (area.isNotEmpty) area,
      if (landmark.isNotEmpty) 'Near $landmark',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  List<OrderHistoryItem> _defaultMockOrders() {
    return [
      OrderHistoryItem(
        orderId: 'PC-892401',
        status: 'Delivered',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        totalAmount: 185.0,
        paymentMethod: 'UPI (Google Pay)',
        deliveryAddress: 'Home — Plot 12, Floor 2, Tech Zone, Hitech City',
        items: [
          OrderItemSummary(
            productId: 'sample_milk',
            productName: 'Full Cream Fresh Milk 500ml',
            quantity: 2,
            unitPrice: 35.0,
          ),
          OrderItemSummary(
            productId: 'sample_bread',
            productName: 'Whole Wheat Brown Bread 400g',
            quantity: 1,
            unitPrice: 45.0,
          ),
          OrderItemSummary(
            productId: 'sample_banana',
            productName: 'Fresh Robusta Bananas (500g)',
            quantity: 1,
            unitPrice: 40.0,
          ),
          OrderItemSummary(
            productId: 'sample_tomato',
            productName: 'Fresh Country Tomatoes (500g)',
            quantity: 1,
            unitPrice: 30.0,
          ),
        ],
      ),
      OrderHistoryItem(
        orderId: 'PC-783192',
        status: 'Delivered',
        createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
        totalAmount: 319.0,
        paymentMethod: 'Cash on Delivery',
        deliveryAddress: 'Home — Plot 12, Floor 2, Tech Zone, Hitech City',
        items: [
          OrderItemSummary(
            productId: 'sample_thaali',
            productName: 'Karwa Chauth Pooja Thali Set',
            quantity: 1,
            unitPrice: 319.0,
          ),
        ],
      ),
      OrderHistoryItem(
        orderId: 'PC-619024',
        status: 'Delivered',
        createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
        totalAmount: 149.0,
        paymentMethod: 'UPI (PhonePe)',
        deliveryAddress: 'Work — Mindspace IT Park, Madhapur',
        items: [
          OrderItemSummary(
            productId: 'sample_coconut',
            productName: 'Fresh Tender Coconut Water',
            quantity: 2,
            unitPrice: 55.0,
          ),
          OrderItemSummary(
            productId: 'sample_chips',
            productName: 'Salted Banana Chips 150g',
            quantity: 1,
            unitPrice: 39.0,
          ),
        ],
      ),
    ];
  }
}
