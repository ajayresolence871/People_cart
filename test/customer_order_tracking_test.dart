import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:people_cart/features/home/models/customer_order_tracking.dart';
import 'package:people_cart/features/home/providers/customer_order_tracking_provider.dart';
import 'package:people_cart/features/home/screens/order_tracking_screen.dart';
import 'package:people_cart/features/home/services/customer_order_tracking_service.dart';
import 'package:people_cart/features/home/widgets/customer_order_tracking_card.dart';
import 'package:people_cart/features/profile/models/order_history_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only supported in-progress statuses count as active', () {
    expect(_order('placed').isActive, isTrue);
    expect(_order('preparing').isActive, isTrue);
    expect(_order('out_for_delivery').isActive, isTrue);
    expect(_order('delivered').isActive, isFalse);
    expect(_order('cancelled').isActive, isFalse);
    expect(_order('unknown_status').isActive, isFalse);
  });

  test('saved order item parser retains image URL when provided', () {
    final order = CustomerOrderTracking.fromJson({
      'id': 105,
      'status': 'placed',
      'total_amount': 20,
      'order_items': [
        {
          'product_id': 1,
          'product_name': 'Fresh Apples',
          'quantity': 1,
          'unit_price': 20,
          'image_url': 'https://example.com/apple.png',
        },
      ],
    });

    expect(order.items.single.imageUrl, 'https://example.com/apple.png');
  });

  test('tracking parses the assigned partner relationship', () {
    final order = CustomerOrderTracking.fromJson({
      'id': 105,
      'status': 'preparing',
      'assigned_delivery_partner_id': 'partner-1',
      'total_amount': 20,
      'order_items': const [],
    });

    expect(order.assignedDeliveryPartnerId, 'partner-1');
  });

  test(
    'switching user immediately clears the previous customer order',
    () async {
      final source = _FakeOrderTrackingDataSource(order: _order('placed'));
      final provider = CustomerOrderTrackingProvider(dataSource: source);
      await provider.refresh(userId: 'customer-a');
      expect(provider.currentOrder?.id, '105');

      source.pendingOrder = Completer<CustomerOrderTracking?>();
      final refresh = provider.refresh(userId: 'customer-b');
      expect(provider.currentOrder, isNull);
      source.pendingOrder!.complete(_order('preparing', id: '106'));
      await refresh;
      expect(provider.currentOrder?.id, '106');
      provider.dispose();
    },
  );

  test(
    'disposing with a pending refresh does not notify listeners later',
    () async {
      final source = _FakeOrderTrackingDataSource()
        ..pendingOrder = Completer<CustomerOrderTracking?>();
      final provider = CustomerOrderTrackingProvider(dataSource: source);
      var notifications = 0;
      provider.addListener(() => notifications++);
      final refresh = provider.refresh(userId: 'customer-a');
      final notificationsAtDispose = notifications;
      provider.dispose();

      source.pendingOrder!.complete(_order('placed'));
      await refresh;
      expect(notifications, notificationsAtDispose);
    },
  );

  testWidgets(
    'active order card shows current real status and supports tracking',
    (tester) async {
      final provider = CustomerOrderTrackingProvider(
        dataSource: _FakeOrderTrackingDataSource(order: _order('preparing')),
      );
      await provider.refresh(userId: 'customer-a');
      var trackingOpened = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<CustomerOrderTrackingProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: ActiveOrderTrackingSection(
                userId: 'customer-a',
                onTrackOrder: (_) => trackingOpened = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your order is being prepared'), findsOneWidget);
      expect(find.text('Order #105'), findsOneWidget);
      expect(find.text('Preparing'), findsWidgets);
      expect(find.text('Order Placed'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      await tester.tap(find.text('Track Order'));
      expect(trackingOpened, isTrue);
    },
  );

  testWidgets(
    'delivered and cancelled statuses do not show normal active progress',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CustomerOrderTrackingCard(
                  order: _order('delivered'),
                  onTrackOrder: () {},
                ),
                CustomerOrderTrackingCard(
                  order: _order('cancelled', id: '106'),
                  onTrackOrder: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Your order was delivered'), findsOneWidget);
      expect(find.text('Your order was cancelled'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(
        find.text('This order will not continue to delivery.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a cancelled order is omitted from active Home tracking', (
    tester,
  ) async {
    final provider = CustomerOrderTrackingProvider(
      dataSource: _FakeOrderTrackingDataSource(order: _order('cancelled')),
    );
    await provider.refresh(userId: 'customer-a');

    await tester.pumpWidget(
      ChangeNotifierProvider<CustomerOrderTrackingProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: ActiveOrderTrackingSection(
              userId: 'customer-a',
              onTrackOrder: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Your order was cancelled'), findsNothing);
    expect(find.text('Track Order'), findsNothing);
    provider.dispose();
  });

  testWidgets('loading, empty, and error states are explicit and retryable', (
    tester,
  ) async {
    final source = _FakeOrderTrackingDataSource();
    source.pendingOrder = Completer<CustomerOrderTracking?>();
    final provider = CustomerOrderTrackingProvider(dataSource: source);
    final refresh = provider.refresh(userId: 'customer-a');

    await tester.pumpWidget(
      ChangeNotifierProvider<CustomerOrderTrackingProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: ActiveOrderTrackingSection(
              userId: 'customer-a',
              onTrackOrder: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    source.pendingOrder!.complete(null);
    await refresh;
    source.pendingOrder = null;
    await tester.pumpAndSettle();
    expect(find.text('Track Order'), findsNothing);

    source.error = StateError('offline');
    await provider.refresh(userId: 'customer-a');
    await tester.pumpAndSettle();
    expect(find.text('Could not refresh order status.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    source.error = null;
    source.order = _order('out_for_delivery');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your order is on the way'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('tracking details show available saved items and address only', (
    tester,
  ) async {
    final order = _order('out_for_delivery');
    final provider = CustomerOrderTrackingProvider(
      dataSource: _FakeOrderTrackingDataSource(detail: order),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: order.id,
          userId: 'customer-a',
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order number'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('12 Main Street, Downtown'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('2 × Fresh Apples'), findsOneWidget);
    expect(find.text('Payment method'), findsNothing);
    expect(find.text('Cancel Order'), findsNothing);
    provider.dispose();
  });

  testWidgets('tracking shows assigned partner name', (tester) async {
    final order = _order(
      'preparing',
      partnerId: 'partner-1',
      partnerName: 'Sam Delivery',
    );
    final provider = CustomerOrderTrackingProvider(
      dataSource: _FakeOrderTrackingDataSource(detail: order),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: order.id,
          userId: 'customer-a',
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delivery Partner Assigned'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Delivery Partner Assigned'), findsOneWidget);
    expect(find.text('Sam Delivery'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('tracking shows the unassigned partner state', (tester) async {
    final order = _order('placed');
    final provider = CustomerOrderTrackingProvider(
      dataSource: _FakeOrderTrackingDataSource(detail: order),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: order.id,
          userId: 'customer-a',
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delivery Partner Assigned'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('Delivery partner will be assigned soon.'),
      findsOneWidget,
    );
    provider.dispose();
  });

  testWidgets('placed tracking order can be cancelled and refreshes status', (
    tester,
  ) async {
    final order = _order('placed');
    final source = _FakeOrderTrackingDataSource(detail: order);
    final provider = CustomerOrderTrackingProvider(dataSource: source);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: order.id,
          userId: 'customer-a',
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel Order'), findsOneWidget);
    await tester.tap(find.text('Cancel Order').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Cancel this order only before preparation begins.'),
      findsNothing,
    );
    expect(
      find.text('You can cancel this order only before preparation begins.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel Order').last);
    await tester.pumpAndSettle();

    expect(source.cancelCalls, 1);
    expect(find.text('Cancel Order'), findsNothing);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Order cancelled.'), findsOneWidget);
    provider.dispose();
  });

  testWidgets(
    'failed cancellation refreshes status and hides action after preparing',
    (tester) async {
      final source = _FakeOrderTrackingDataSource(detail: _order('placed'))
        ..cancelError = StateError('Only placed orders can be cancelled');
      final provider = CustomerOrderTrackingProvider(dataSource: source);

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: '105',
            userId: 'customer-a',
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Order').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Order').last);
      await tester.pumpAndSettle();

      expect(find.text('Preparing'), findsWidgets);
      expect(find.text('Cancel Order'), findsNothing);
      expect(
        find.textContaining('Only placed orders can be cancelled'),
        findsOneWidget,
      );
      provider.dispose();
    },
  );

  testWidgets('tracking details use the catalog image when available', (
    tester,
  ) async {
    final order = _order('out_for_delivery');
    final orderWithImage = CustomerOrderTracking(
      id: order.id,
      status: order.status,
      createdAt: order.createdAt,
      totalAmount: order.totalAmount,
      deliveryAddress: order.deliveryAddress,
      items: order.items
          .map((item) => item.withImageUrl('https://example.com/apple.png'))
          .toList(),
    );
    final provider = CustomerOrderTrackingProvider(
      dataSource: _FakeOrderTrackingDataSource(detail: orderWithImage),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: order.id,
          userId: 'customer-a',
          provider: provider,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'https://example.com/apple.png',
      ),
      findsOneWidget,
    );
    provider.dispose();
  });
}

CustomerOrderTracking _order(
  String status, {
  String id = '105',
  String? partnerId,
  String? partnerName,
}) {
  return CustomerOrderTracking(
    id: id,
    status: status,
    createdAt: DateTime.utc(2025, 1, 1, 12),
    totalAmount: 45,
    deliveryAddress: '12 Main Street, Downtown',
    assignedDeliveryPartnerId: partnerId,
    assignedDeliveryPartnerName: partnerName,
    items: [
      OrderItemSummary(
        productId: '1',
        productName: 'Fresh Apples',
        quantity: 2,
        unitPrice: 20,
      ),
    ],
  );
}

class _FakeOrderTrackingDataSource implements CustomerOrderTrackingDataSource {
  CustomerOrderTracking? order;
  CustomerOrderTracking? detail;
  Completer<CustomerOrderTracking?>? pendingOrder;
  Object? error;
  Object? cancelError;
  int cancelCalls = 0;

  _FakeOrderTrackingDataSource({this.order, this.detail});

  @override
  Future<CustomerOrderTracking?> getCurrentOrderForHome({
    required String userId,
  }) async {
    if (pendingOrder != null) return pendingOrder!.future;
    if (error != null) throw error!;
    return order;
  }

  @override
  Future<CustomerOrderTracking?> getOrderDetails({
    required String orderId,
    required String userId,
  }) async {
    if (error != null) throw error!;
    return detail;
  }

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String userId,
  }) async {
    cancelCalls++;
    if (cancelError != null) {
      detail = detail?.copyWith(status: 'preparing');
      throw cancelError!;
    }
    detail = detail?.copyWith(status: 'cancelled');
  }
}
