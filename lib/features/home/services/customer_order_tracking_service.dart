import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/models/order_history_item.dart';
import '../../../services/product_service.dart';
import '../models/customer_order_tracking.dart';

abstract class CustomerOrderTrackingDataSource {
  Future<CustomerOrderTracking?> getCurrentOrderForHome({
    required String userId,
  });

  Future<CustomerOrderTracking?> getOrderDetails({
    required String orderId,
    required String userId,
  });

  Future<void> cancelOrder({required String orderId, required String userId});
}

class CustomerOrderTrackingService implements CustomerOrderTrackingDataSource {
  final SupabaseClient? _explicitClient;
  final ProductCatalogDataSource _productCatalog;

  CustomerOrderTrackingService({
    SupabaseClient? client,
    ProductCatalogDataSource? productCatalog,
  }) : _explicitClient = client,
       _productCatalog = productCatalog ?? ProductService();

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String _verifiedUserId(String expectedUserId) {
    final client = _client;
    final actualUserId = client?.auth.currentUser?.id;
    if (actualUserId == null || actualUserId != expectedUserId) {
      throw StateError('Sign in to view your orders.');
    }
    return actualUserId;
  }

  @override
  Future<CustomerOrderTracking?> getCurrentOrderForHome({
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Order tracking is not available.');
    }
    final verifiedUserId = _verifiedUserId(userId);
    final activeOrder = await client
        .from('orders')
        .select(
          'id, user_id, status, created_at, total_amount, '
          'assigned_delivery_partner_id, delivery_address_snapshot, '
          'order_items(product_id, product_name, quantity, unit_price)',
        )
        .eq('user_id', verifiedUserId)
        .inFilter('status', ['placed', 'preparing', 'out_for_delivery'])
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    if (activeOrder != null) {
      return _attachDetails(CustomerOrderTracking.fromJson(activeOrder));
    }
    return null;
  }

  @override
  Future<CustomerOrderTracking?> getOrderDetails({
    required String orderId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Order details are not available.');
    }
    final verifiedUserId = _verifiedUserId(userId);
    final id = orderId.startsWith('PC-') ? orderId.substring(3) : orderId;
    final parsedOrderId = int.tryParse(id);
    if (parsedOrderId == null || parsedOrderId <= 0) return null;
    final response = await client
        .from('orders')
        .select(
          'id, user_id, status, created_at, total_amount, '
          'assigned_delivery_partner_id, delivery_address_snapshot, '
          'order_items(product_id, product_name, quantity, unit_price)',
        )
        .eq('id', parsedOrderId)
        .eq('user_id', verifiedUserId)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    return response == null
        ? null
        : _attachDetails(CustomerOrderTracking.fromJson(response));
  }

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Order cancellation is not available.');
    }
    _verifiedUserId(userId);
    final id = orderId.startsWith('PC-') ? orderId.substring(3) : orderId;
    final parsedOrderId = int.tryParse(id);
    if (parsedOrderId == null || parsedOrderId <= 0) {
      throw const FormatException('The order ID is not valid.');
    }
    final response = await client.rpc(
      'customer_cancel_order',
      params: {'p_order_id': parsedOrderId},
    );
    if (response is! Map || response['success'] != true) {
      throw const FormatException(
        'The server did not confirm order cancellation.',
      );
    }
  }

  Future<CustomerOrderTracking> _attachDetails(
    CustomerOrderTracking order,
  ) async {
    var detailedOrder = order;
    final partnerId = order.assignedDeliveryPartnerId;
    if (partnerId != null && partnerId.isNotEmpty) {
      try {
        final orderId = int.tryParse(order.id);
        if (orderId == null) {
          throw const FormatException('The order ID is not valid.');
        }
        final response = await _client!
            .rpc(
              'customer_get_assigned_delivery_partner',
              params: {'p_order_id': orderId},
            )
            .timeout(const Duration(seconds: 12));
        final partnerRow = response is List && response.isNotEmpty
            ? response.first
            : response is Map
            ? response
            : null;
        final name = partnerRow is Map
            ? partnerRow['partner_name']?.toString().trim()
            : null;
        detailedOrder = order.withDeliveryPartner(
          name: name == null || name.isEmpty ? null : name,
          unavailable: name == null || name.isEmpty,
        );
      } catch (error) {
        debugPrint('Customer order tracking: Could not load partner: $error');
        detailedOrder = order.withDeliveryPartner(
          name: null,
          unavailable: true,
        );
      }
    }

    final productIds = detailedOrder.items
        .map((item) => item.productId)
        .where((id) => id.isNotEmpty);
    try {
      final products = await _productCatalog.getProductsByIds(productIds);
      return CustomerOrderTracking(
        id: detailedOrder.id,
        status: detailedOrder.status,
        createdAt: detailedOrder.createdAt,
        totalAmount: detailedOrder.totalAmount,
        deliveryAddress: detailedOrder.deliveryAddress,
        assignedDeliveryPartnerId: detailedOrder.assignedDeliveryPartnerId,
        assignedDeliveryPartnerName: detailedOrder.assignedDeliveryPartnerName,
        partnerDetailsUnavailable: detailedOrder.partnerDetailsUnavailable,
        items: OrderItemSummary.withCatalogImages(
          detailedOrder.items,
          products,
        ),
      );
    } catch (error) {
      debugPrint(
        'Customer order tracking: Could not load product images: $error',
      );
      return detailedOrder;
    }
  }
}
