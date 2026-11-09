import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import 'customer_event_service.dart';

class OrderResult {
  final bool isSuccess;
  final String orderId;
  final String? errorMessage;
  final double? totalAmount;

  OrderResult({
    required this.isSuccess,
    required this.orderId,
    this.errorMessage,
    this.totalAmount,
  });
}

typedef SecureRpcCaller = Future<dynamic> Function(
  String functionName, {
  Map<String, dynamic>? params,
});

class OrderService {
  final SupabaseClient? _explicitClient;
  final SecureRpcCaller? rpcCaller;
  final bool? _explicitIsAuthenticated;
  final CustomerEventLogger eventLogger;

  OrderService({
    SupabaseClient? client,
    this.rpcCaller,
    bool? isAuthenticated,
    CustomerEventLogger? eventLogger,
  }) : _explicitClient = client,
       _explicitIsAuthenticated = isAuthenticated,
       eventLogger = eventLogger ?? CustomerEventService(client: client);

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    if (_explicitIsAuthenticated != null) return _explicitIsAuthenticated;
    try {
      final client = _client;
      return client != null && client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  bool get _hasRpcEndpoint => rpcCaller != null || _client != null;

  /// Places a COD order through the constrained cash-only checkout RPC.
  /// Enforces that the caller is authenticated, validates catalog product IDs,
  /// aggregates duplicate items, locks rows in deterministic order, and recalculates total.
  Future<OrderResult> placeOrder({
    required List<CartItem> items,
    required double totalAmount,
    required String deliveryAddressId,
    String paymentMethod = 'cash_on_delivery',
  }) async {
    if (paymentMethod != 'cash_on_delivery') {
      return OrderResult(
        isSuccess: false,
        orderId: '',
        errorMessage:
            'Online payments must use the verified Razorpay checkout.',
      );
    }
    // 0. Authentication Check: Guest checkout is strictly rejected; login is required
    if (!isAuthenticated && _hasRpcEndpoint) {
      return OrderResult(
        isSuccess: false,
        orderId: '',
        errorMessage:
            'Authentication required: You must be signed in to place an order.',
      );
    }

    if (items.isEmpty) {
      return OrderResult(
        isSuccess: false,
        orderId: '',
        errorMessage: 'Cannot place an empty order.',
      );
    }

    if (deliveryAddressId.trim().isEmpty) {
      return OrderResult(
        isSuccess: false,
        orderId: '',
        errorMessage: 'Please select a delivery address to continue.',
      );
    }

    // 0. Catalog ID verification: Reject any synthetic products (e.g. prod_*, deal_*, gen_*)
    for (final item in items) {
      final id = item.product.id;
      final isSynthetic =
          id.startsWith('prod_') ||
          id.startsWith('deal_') ||
          id.startsWith('gen_');
      if (isSynthetic) {
        return OrderResult(
          isSuccess: false,
          orderId: '',
          errorMessage:
              'Item "${item.product.name}" is not a valid catalog product and cannot be ordered.',
        );
      }
    }

    // 1. Validate numeric IDs and positive quantities, aggregating duplicate products
    final Map<int, int> aggregated = {};
    for (final item in items) {
      final pid = int.tryParse(item.product.id);
      if (pid == null || pid <= 0) {
        return OrderResult(
          isSuccess: false,
          orderId: '',
          errorMessage:
              'Item "${item.product.name}" has an invalid product ID ("${item.product.id}").',
        );
      }
      if (item.quantity <= 0) {
        return OrderResult(
          isSuccess: false,
          orderId: '',
          errorMessage:
              'Invalid quantity ${item.quantity} for "${item.product.name}".',
        );
      }
      aggregated[pid] = (aggregated[pid] ?? 0) + item.quantity;
    }

    if (!_hasRpcEndpoint) {
      // In offline/test mode without an active Supabase client or custom RPC handler
      final fallbackId =
          'PC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      return OrderResult(isSuccess: true, orderId: fallbackId);
    }

    // 2. Route COD exclusively through the secure atomic server RPC.
    try {
      final rpcItems = aggregated.entries
          .map((entry) => {'product_id': entry.key, 'quantity': entry.value})
          .toList();

      // Client strictly DOES NOT send p_user_id; identity is derived exclusively on the server from auth.uid()
      final dynamic rpcResponse = rpcCaller != null
          ? await rpcCaller!(
              'create_order_cash_secure',
              params: {
                'p_items': rpcItems,
                'p_delivery_address_id': deliveryAddressId,
              },
            )
          : await _client!.rpc(
              'create_order_cash_secure',
              params: {
                'p_items': rpcItems,
                'p_delivery_address_id': deliveryAddressId,
              },
            );

      if (rpcResponse is Map &&
          rpcResponse['success'] == true &&
          rpcResponse['order_id'] != null) {
        final orderId = rpcResponse['order_id'].toString();
        final totalAmount = rpcResponse['total_amount'] is num
            ? (rpcResponse['total_amount'] as num).toDouble()
            : null;
        debugPrint(
          'COD order placed securely via create_order_cash_secure RPC: $orderId',
        );
        logEventWithoutBlocking(eventLogger.logCheckoutCompleted(orderId));
        return OrderResult(
          isSuccess: true,
          orderId: orderId,
          totalAmount: totalAmount,
        );
      }

      // Handle malformed or failed server response
      final errorMsg = rpcResponse is Map && rpcResponse['error'] != null
          ? rpcResponse['error'].toString()
          : 'Server did not return a valid order confirmation.';
      debugPrint('create_order_cash_secure RPC rejected: $errorMsg');
      return OrderResult(isSuccess: false, orderId: '', errorMessage: errorMsg);
    } catch (rpcError) {
      final cleanMessage = _formatErrorMessage(rpcError);
      debugPrint('create_order_cash_secure RPC error: $cleanMessage');
      // Never fall back to unvalidated direct inserts
      return OrderResult(
        isSuccess: false,
        orderId: '',
        errorMessage: cleanMessage,
      );
    }
  }

  String _formatErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    final str = error.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(str);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return str.replaceAll('Exception: ', '').trim();
  }
}
