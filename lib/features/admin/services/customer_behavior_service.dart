import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_behavior_data.dart';

abstract class CustomerBehaviorDataSource {
  Future<CustomerBehaviorData> load({
    required DateTime from,
    required DateTime to,
  });
}

class CustomerBehaviorService implements CustomerBehaviorDataSource {
  static const _pageSize = 1000;
  final SupabaseClient? _explicitClient;

  CustomerBehaviorService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase is not initialized.');
    }
  }

  @override
  Future<CustomerBehaviorData> load({
    required DateTime from,
    required DateTime to,
  }) async {
    final client = _client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in as an admin to view customer insights.');
    }

    final eventRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await client
          .from('customer_events')
          .select(
            'event_type, product_id, search_term, results_count, created_at',
          )
          .gte('created_at', from.toUtc().toIso8601String())
          .lt('created_at', to.toUtc().toIso8601String())
          .order('created_at')
          .order('id')
          .range(offset, offset + _pageSize - 1);
      eventRows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    final productIds = eventRows
        .where(
          (event) =>
              event['event_type'] == 'product_view' ||
              event['event_type'] == 'add_to_cart',
        )
        .map((event) => event['product_id']?.toString())
        .whereType<String>()
        .toSet();
    final productNames = <String, String>{};
    final productImages = <String, String?>{};
    if (productIds.isNotEmpty) {
      final products = await client
          .from('products')
          .select('id, name, image_url')
          .inFilter('id', productIds.toList());
      for (final product in products) {
        final id = product['id'].toString();
        productNames[id] = product['name']?.toString() ?? 'Unnamed product';
        productImages[id] = product['image_url']?.toString();
      }
    }

    var views = 0;
    var adds = 0;
    var searchCount = 0;
    var checkouts = 0;
    var zeroResults = 0;
    final viewsByProduct = <String, int>{};
    final addsByProduct = <String, int>{};
    final searches = <String, int>{};
    final zeroResultTerms = <String, int>{};
    final activity = <int, int>{};

    for (final event in eventRows) {
      final type = event['event_type'] as String?;
      final productId = event['product_id']?.toString();
      final createdAt = DateTime.tryParse(
        event['created_at']?.toString() ?? '',
      );
      if (createdAt != null) {
        activity.update(
          createdAt.toLocal().hour,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      switch (type) {
        case 'product_view':
          views++;
          if (productId != null) {
            viewsByProduct.update(
              productId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
        case 'add_to_cart':
          adds++;
          if (productId != null) {
            addsByProduct.update(
              productId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
        case 'search':
          searchCount++;
          final term = event['search_term']?.toString();
          if (term != null && term.isNotEmpty) {
            searches.update(term, (count) => count + 1, ifAbsent: () => 1);
          }
          if ((event['results_count'] as num?)?.toInt() == 0) {
            zeroResults++;
            if (term != null && term.isNotEmpty) {
              zeroResultTerms.update(
                term,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
        case 'checkout_completed':
          checkouts++;
      }
    }

    List<ProductBehaviorMetric> topProducts(Map<String, int> values) {
      final entries = values.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(10).map((entry) {
        return ProductBehaviorMetric(
          productId: entry.key,
          name: productNames[entry.key] ?? 'Product ${entry.key}',
          count: entry.value,
          views: viewsByProduct[entry.key] ?? 0,
          additions: addsByProduct[entry.key] ?? 0,
          imageUrl: productImages[entry.key],
        );
      }).toList();
    }

    final searchEntries = searches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final zeroResultEntries = zeroResultTerms.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomerBehaviorData(
      productViews: views,
      addToCartEvents: adds,
      searches: searchCount,
      completedOrders: checkouts,
      zeroResultSearches: zeroResults,
      mostViewedProducts: topProducts(viewsByProduct),
      mostAddedProducts: topProducts(addsByProduct),
      zeroResultSearchTerms: zeroResultEntries
          .take(10)
          .map((entry) => SearchTermMetric(term: entry.key, count: entry.value))
          .toList(),
      topSearchTerms: searchEntries
          .take(10)
          .map((entry) => SearchTermMetric(term: entry.key, count: entry.value))
          .toList(),
      activityByHour: activity,
      from: from,
      to: to,
    );
  }
}
