import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';

class RazorpayOrderInfo {
  const RazorpayOrderInfo({
    required this.attemptId,
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountPaise,
    required this.currency,
  });

  final String attemptId;
  final String razorpayOrderId;
  final String keyId;
  final int amountPaise;
  final String currency;
}

typedef EdgeFunctionCaller = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> body,
);

/// Client-side transport only. Prices are never sent; the database derives them.
class RazorpayOrderService {
  RazorpayOrderService({this.client, this.caller});

  final SupabaseClient? client;
  final EdgeFunctionCaller? caller;

  Future<dynamic> _invoke(String name, Map<String, dynamic> body) async {
    if (caller != null) return caller!(name, body);
    final supabase = client ?? Supabase.instance.client;
    final response = await supabase.functions.invoke(name, body: body);
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Payment service could not complete the request.');
    }
    return response.data;
  }

  Future<RazorpayOrderInfo> createOrder({
    required List<CartItem> items,
    required String addressId,
    required String idempotencyKey,
  }) async {
    if (items.isEmpty || addressId.trim().isEmpty) {
      throw ArgumentError(
        'A delivery address and at least one item are required.',
      );
    }
    final aggregated = <int, int>{};
    for (final item in items) {
      final id = int.tryParse(item.product.id);
      if (id == null || id <= 0 || item.quantity <= 0) {
        throw ArgumentError(
          'The cart contains an invalid product or quantity.',
        );
      }
      aggregated.update(
        id,
        (qty) => qty + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    final data = await _invoke('razorpay-create-order', {
      'items': aggregated.entries
          .map((entry) => {'product_id': entry.key, 'quantity': entry.value})
          .toList(),
      'delivery_address_id': addressId,
      'idempotency_key': idempotencyKey,
    });
    if (data is! Map || data['success'] != true) {
      throw Exception('Could not start payment. Please retry.');
    }
    final amount = data['amount_paise'];
    if (amount is! num || amount < 100) {
      throw Exception('The server returned an invalid payment amount.');
    }
    return RazorpayOrderInfo(
      attemptId: data['attempt_id'].toString(),
      razorpayOrderId: data['razorpay_order_id'].toString(),
      keyId: data['key_id'].toString(),
      amountPaise: amount.toInt(),
      currency: (data['currency'] ?? 'INR').toString(),
    );
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String attemptId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    final data = await _invoke('razorpay-verify-payment', {
      'attempt_id': attemptId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': signature,
    });
    if (data is! Map || data['success'] != true || data['order_id'] == null) {
      throw Exception(
        'Payment could not be verified. Refresh before retrying.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<bool> releaseCancelledAttempt({
    required String attemptId,
    required String razorpayOrderId,
  }) async {
    final data = await _invoke('razorpay-cancel-checkout', {
      'attempt_id': attemptId,
      'razorpay_order_id': razorpayOrderId,
    });
    return data is Map && data['released'] == true;
  }

  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
