import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/product_service.dart';
import '../models/delivery_assignment_data.dart';

abstract class DeliveryAssignmentDataSource {
  Future<List<DeliveryManagedOrder>> loadOrders();
  Future<List<DeliveryPartner>> loadPartners();
  Future<void> assignOrder(String orderId, String? partnerId);
  Future<List<DeliveryManagedOrder>> loadMyAssignedOrders();
  Future<void> updateMyOrderStatus(String orderId, String status);
}

class DeliveryAssignmentService implements DeliveryAssignmentDataSource {
  final SupabaseClient? _explicitClient;
  final ProductCatalogDataSource _productCatalog;

  DeliveryAssignmentService({
    SupabaseClient? client,
    ProductCatalogDataSource? productCatalog,
  }) : _explicitClient = client,
       _productCatalog = productCatalog ?? ProductService();

  SupabaseClient get _client {
    final explicitClient = _explicitClient;
    if (explicitClient != null) return explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase is not initialized.');
    }
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is! List) {
      throw const FormatException('Unexpected delivery assignment response.');
    }
    return response.map((row) {
      if (row is! Map) {
        throw const FormatException(
          'Unexpected delivery assignment row returned.',
        );
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  @override
  Future<List<DeliveryManagedOrder>> loadOrders() async {
    final response = await _client.rpc('admin_list_delivery_orders');
    return _rows(response).map(DeliveryManagedOrder.fromJson).toList();
  }

  @override
  Future<List<DeliveryPartner>> loadPartners() async {
    final response = await _client.rpc('admin_list_delivery_partners');
    return _rows(response)
        .map(
          (row) => DeliveryPartner(
            id: row['partner_id']?.toString() ?? '',
            name: row['full_name']?.toString(),
          ),
        )
        .where((partner) => partner.id.isNotEmpty)
        .toList();
  }

  @override
  Future<void> assignOrder(String orderId, String? partnerId) async {
    final numericOrderId = int.tryParse(orderId);
    if (numericOrderId == null) {
      throw const FormatException('The order ID is not a valid number.');
    }
    await _client.rpc(
      'admin_assign_delivery_partner',
      params: {
        'p_order_id': numericOrderId,
        'p_delivery_partner_id': partnerId,
      },
    );
  }

  @override
  Future<List<DeliveryManagedOrder>> loadMyAssignedOrders() async {
    final orders = _rows(await _client.rpc('delivery_partner_list_my_orders'))
        .map(DeliveryManagedOrder.fromJson)
        .toList();

    // Payment details are returned by a separate assignment-scoped RPC. Keep
    // order tracking available while the review-only database proposal is not
    // installed; in that case the details screen shows payment as unavailable.
    try {
      final paymentRows = _rows(
        await _client.rpc('delivery_partner_list_my_order_payment_summary'),
      );
      final paymentsByOrderId = {
        for (final row in paymentRows)
          if (row['order_id'] != null) row['order_id'].toString(): row,
      };
      final enriched = orders.map((order) {
        final payment = paymentsByOrderId[order.id];
        return order.copyWith(
          paymentMethod: payment?['payment_method']?.toString(),
          paymentStatus: payment?['payment_status']?.toString(),
        );
      }).toList();
      return await _attachCatalogImages(enriched);
    } catch (error) {
      debugPrint(
        'Delivery partner orders: payment details unavailable: $error',
      );
      return await _attachCatalogImages(orders);
    }
  }

  @override
  Future<void> updateMyOrderStatus(String orderId, String status) async {
    if (status != 'out_for_delivery' && status != 'delivered') {
      throw const FormatException('Unsupported delivery status.');
    }
    final numericOrderId = int.tryParse(orderId);
    if (numericOrderId == null) {
      throw const FormatException('The order ID is not a valid number.');
    }
    await _client.rpc(
      'delivery_partner_update_order_status',
      params: {'p_order_id': numericOrderId, 'p_new_status': status},
    );
  }

  Future<List<DeliveryManagedOrder>> _attachCatalogImages(
    List<DeliveryManagedOrder> orders,
  ) async {
    final productIds = orders
        .expand((order) => order.items)
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
      return orders
          .map(
            (order) => DeliveryManagedOrder(
              id: order.id,
              createdAt: order.createdAt,
              totalAmount: order.totalAmount,
              status: order.status,
              assignedPartnerId: order.assignedPartnerId,
              assignedPartnerName: order.assignedPartnerName,
              paymentMethod: order.paymentMethod,
              paymentStatus: order.paymentStatus,
              itemCount: order.itemCount,
              items: order.items
                  .map(
                    (item) => item.withImageUrl(
                      item.imageUrl?.trim().isNotEmpty == true
                          ? item.imageUrl
                          : imageUrls[item.productId],
                    ),
                  )
                  .toList(),
              deliveryAddress: order.deliveryAddress,
            ),
          )
          .toList();
    } catch (error) {
      debugPrint(
        'Delivery partner orders: Could not load product images: $error',
      );
      return orders;
    }
  }
}
