import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CustomerEventLogger {
  Future<void> logProductView(String productId);
  Future<void> logAddToCart(String productId);
  Future<void> logSearch(String term, int resultCount);
  Future<void> logCheckoutCompleted(String orderId);
}

class CustomerEventService implements CustomerEventLogger {
  final SupabaseClient? _explicitClient;

  CustomerEventService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String _normalizedTerm(String term) =>
      term.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<void> _record(Map<String, dynamic> event) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;

    try {
      await client.from('customer_events').insert(event);
    } catch (error) {
      debugPrint('Customer event was not recorded: $error');
    }
  }

  @override
  Future<void> logProductView(String productId) async {
    if (productId.isEmpty) return;
    await _record({'event_type': 'product_view', 'product_id': productId});
  }

  @override
  Future<void> logAddToCart(String productId) async {
    if (productId.isEmpty) return;
    await _record({'event_type': 'add_to_cart', 'product_id': productId});
  }

  @override
  Future<void> logSearch(String term, int resultCount) async {
    final normalized = _normalizedTerm(term);
    if (normalized.isEmpty || resultCount < 0) return;
    await _record({
      'event_type': 'search',
      'search_term': normalized,
      'results_count': resultCount,
    });
  }

  @override
  Future<void> logCheckoutCompleted(String orderId) async {
    if (orderId.isEmpty) return;
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    try {
      await client.rpc(
        'record_checkout_completed_event',
        params: {'p_order_id': orderId},
      );
    } catch (error) {
      debugPrint('Checkout completion event was not recorded: $error');
    }
  }
}

void logEventWithoutBlocking(Future<void> event) {
  unawaited(_ignoreEventFailure(event));
}

Future<void> _ignoreEventFailure(Future<void> event) async {
  try {
    await event;
  } catch (error) {
    debugPrint('Customer event was not recorded: $error');
  }
}
