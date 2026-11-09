import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/features/admin/models/customer_behavior_data.dart';
import 'package:people_cart/features/admin/providers/customer_behavior_provider.dart';
import 'package:people_cart/features/admin/screens/customer_behavior_screen.dart';
import 'package:people_cart/features/admin/services/customer_behavior_service.dart';
import 'package:people_cart/models/cart_item.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';
import 'package:people_cart/providers/cart_provider.dart';
import 'package:people_cart/services/customer_event_service.dart';
import 'package:people_cart/services/order_service.dart';

class _FakeEventLogger implements CustomerEventLogger {
  final List<String> viewed = [];
  final List<String> added = [];
  final List<(String, int)> searches = [];
  final List<String> checkouts = [];

  @override
  Future<void> logProductView(String productId) async => viewed.add(productId);

  @override
  Future<void> logAddToCart(String productId) async => added.add(productId);

  @override
  Future<void> logSearch(String term, int resultCount) async =>
      searches.add((term, resultCount));

  @override
  Future<void> logCheckoutCompleted(String orderId) async =>
      checkouts.add(orderId);
}

class _FakeInsightsSource implements CustomerBehaviorDataSource {
  final CustomerBehaviorData result;
  final Object? failure;
  int? requestedDays;

  _FakeInsightsSource(this.result, {this.failure});

  @override
  Future<CustomerBehaviorData> load({
    required DateTime from,
    required DateTime to,
  }) async {
    requestedDays = to.difference(from).inDays;
    if (failure != null) throw failure!;
    return result;
  }
}

CustomerBehaviorData _sampleData() => CustomerBehaviorData(
  productViews: 12,
  addToCartEvents: 5,
  searches: 3,
  completedOrders: 2,
  zeroResultSearches: 1,
  mostViewedProducts: const [
    ProductBehaviorMetric(
      productId: '4',
      name: 'Apples',
      count: 8,
      views: 8,
      additions: 3,
    ),
  ],
  mostAddedProducts: const [
    ProductBehaviorMetric(
      productId: '4',
      name: 'Apples',
      count: 3,
      views: 8,
      additions: 3,
    ),
  ],
  zeroResultSearchTerms: const [SearchTermMetric(term: 'oat milk', count: 2)],
  topSearchTerms: const [SearchTermMetric(term: 'apple', count: 2)],
  activityByHour: const {9: 4},
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 2),
);

void main() {
  group('Customer activity instrumentation', () {
    test('only accepted cart additions record add-to-cart events', () async {
      final logger = _FakeEventLogger();
      final cart = CartProvider(eventLogger: logger);
      final product = Product(
        id: '12',
        name: 'Fresh Pear',
        price: 20,
        stockQuantity: 1,
      );

      expect(cart.addItem(product).isSuccess, isTrue);
      expect(cart.addItem(product).isMaxStockReached, isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(logger.added, ['12']);
    });

    test(
      'checkout completion is recorded only after secure RPC success',
      () async {
        final logger = _FakeEventLogger();
        final successful = OrderService(
          isAuthenticated: true,
          eventLogger: logger,
          rpcCaller: (name, {params}) async => {
            'success': true,
            'order_id': 123,
          },
        );
        final item = CartItem(
          product: Product(id: '1', name: 'Apples', price: 20),
          quantity: 1,
        );

        final result = await successful.placeOrder(
          items: [item],
          totalAmount: 20,
          deliveryAddressId: 'address-test',
        );
        await Future<void>.delayed(Duration.zero);
        expect(result.isSuccess, isTrue);
        expect(logger.checkouts, ['123']);

        final failed = OrderService(
          isAuthenticated: true,
          eventLogger: logger,
          rpcCaller: (name, {params}) async => {
            'success': false,
            'error': 'Rejected',
          },
        );
        await failed.placeOrder(
          items: [item],
          totalAmount: 20,
          deliveryAddressId: 'address-test',
        );
        await Future<void>.delayed(Duration.zero);
        expect(logger.checkouts, ['123']);
      },
    );

    test(
      'analytics logger failures do not escape the fire-and-forget helper',
      () async {
        final errors = <Object>[];
        final completed = runZonedGuarded<Future<void>>(() async {
          logEventWithoutBlocking(Future<void>.error(StateError('offline')));
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }, (error, stackTrace) => errors.add(error));
        await completed;
        expect(errors, isEmpty);
      },
    );
  });

  group('Customer behavior admin analytics', () {
    test('provider loads selected date range and exposes real data', () async {
      final source = _FakeInsightsSource(_sampleData());
      final provider = CustomerBehaviorProvider(dataSource: source);
      await provider.load(days: 7);

      expect(source.requestedDays, 7);
      expect(provider.data?.productViews, 12);
      expect(provider.data?.completedOrders, 2);
      expect(provider.error, isNull);
    });

    test(
      'provider exposes query failures without substituting sample data',
      () async {
        final source = _FakeInsightsSource(
          _sampleData(),
          failure: StateError('permission denied'),
        );
        final provider = CustomerBehaviorProvider(dataSource: source);
        await provider.load();

        expect(provider.data, isNull);
        expect(provider.error, contains('permission denied'));
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'popular products combine views and additions without duplication',
      () {
        final popular = _sampleData().popularProducts;
        expect(popular, hasLength(1));
        expect(popular.single.views, 8);
        expect(popular.single.additions, 3);
        expect(popular.single.count, 11);
        expect(popular.single.imageUrl, isNull);
      },
    );

    testWidgets('admin insights render metrics and honest funnel definition', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _FakeInsightsSource(_sampleData());
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: Scaffold(body: CustomerBehaviorScreen(dataSource: source)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Customer insights'), findsOneWidget);
      expect(find.text('12'), findsWidgets);
      expect(find.text('Popular products'), findsOneWidget);
      expect(find.text('Apples'), findsWidgets);
      expect(find.text('8 views · 3 added'), findsOneWidget);
      expect(find.text('Search opportunities'), findsOneWidget);
      expect(find.text('oat milk'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Activity by hour'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('09:00 · 4'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
      expect(
        find.textContaining('Counts are events, not unique customers.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('30 days'));
      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      expect(source.requestedDays, 30);
    });
  });
}
