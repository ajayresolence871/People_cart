import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/product_service.dart';
import '../models/admin_order_data.dart';

abstract class AdminOrderDataSource {
  Future<List<AdminManagedOrder>> loadOrders({String? status});
  Future<AdminManagedOrder> loadOrderDetails(String orderId);
  Future<void> updateOrderStatus(String orderId, String status);
}

class AdminOrderService implements AdminOrderDataSource {
  final SupabaseClient? _explicitClient;
  final ProductCatalogDataSource _productCatalog;

  AdminOrderService({
    SupabaseClient? client,
    ProductCatalogDataSource? productCatalog,
  }) : _explicitClient = client,
       _productCatalog = productCatalog ?? ProductService();

  SupabaseClient get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase is not initialized.');
    }
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is! List) {
      throw const FormatException('Unexpected admin orders response.');
    }
    return response.map((row) {
      if (row is! Map) {
        throw const FormatException('Unexpected admin order row.');
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  @override
  Future<List<AdminManagedOrder>> loadOrders({String? status}) async {
    final response = await _client.rpc(
      'admin_list_orders',
      params: {'p_status': status},
    );
    return _rows(response)
        .map(AdminManagedOrder.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AdminManagedOrder> loadOrderDetails(String orderId) async {
    final numericOrderId = int.tryParse(orderId);
    if (numericOrderId == null) {
      throw const FormatException('The order ID is not a valid number.');
    }
    final response = await _client.rpc(
      'admin_get_order_details',
      params: {'p_order_id': numericOrderId},
    );
    if (response is! Map) {
      throw const FormatException('Unexpected order details response.');
    }
    return _attachCatalogImages(
      AdminManagedOrder.fromJson(Map<String, dynamic>.from(response)),
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    if (status == 'out_for_delivery' || status == 'delivered') {
      throw StateError(
        'Delivery status must be updated by the assigned delivery partner.',
      );
    }
    if (status != 'preparing' && status != 'cancelled') {
      throw const FormatException('Unsupported admin order status.');
    }
    final numericOrderId = int.tryParse(orderId);
    if (numericOrderId == null) {
      throw const FormatException('The order ID is not a valid number.');
    }
    await _client.rpc(
      'admin_update_order_status',
      params: {'p_order_id': numericOrderId, 'p_new_status': status},
    );
  }

  Future<AdminManagedOrder> _attachCatalogImages(
    AdminManagedOrder order,
  ) async {
    final productIds = order.items
        .map((item) => item.productId)
        .whereType<String>()
        .where((id) => id.isNotEmpty);
    try {
      final products = await _productCatalog.getProductsByIds(productIds);
      final imageUrls = {
        for (final product in products)
          if (product.imageUrl?.trim().isNotEmpty == true)
            product.id: product.imageUrl!,
      };
      return AdminManagedOrder(
        id: order.id,
        createdAt: order.createdAt,
        totalAmount: order.totalAmount,
        status: order.status,
        customerName: order.customerName,
        paymentMethod: order.paymentMethod,
        paymentStatus: order.paymentStatus,
        items: order.items
            .map(
              (item) => item.withImageUrl(
                item.imageUrl?.trim().isNotEmpty == true
                    ? item.imageUrl
                    : imageUrls[item.productId],
              ),
            )
            .toList(),
      );
    } catch (error) {
      debugPrint('Admin order details: Could not load product images: $error');
      return order;
    }
  }
}
