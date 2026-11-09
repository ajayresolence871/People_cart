import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/features/home/models/customer_order_tracking.dart';
import 'package:people_cart/features/home/providers/customer_order_tracking_provider.dart';
import 'package:people_cart/features/home/services/customer_order_tracking_service.dart';
import 'package:people_cart/features/profile/models/order_history_item.dart';
import 'package:people_cart/features/profile/screens/order_detail_screen.dart';
import 'package:people_cart/features/profile/services/order_history_service.dart';
import 'package:people_cart/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderHistoryService & Item Tests', () {
    late OrderHistoryService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = OrderHistoryService();
    });

    test('Loads default mock orders on fresh install', () async {
      final orders = await service.getOrders();
      expect(orders.isNotEmpty, true);
      expect(orders.length >= 3, true);
      expect(orders.first.status, 'Delivered');
      expect(orders.first.items.isNotEmpty, true);
    });

    test(
      'Recording a new order prepends it to the top of the history list',
      () async {
        final newOrder = OrderHistoryItem(
          orderId: 'PC-999999',
          status: 'Order Placed',
          createdAt: DateTime.now(),
          totalAmount: 450.0,
          paymentMethod: 'Online Payment',
          deliveryAddress: 'Home — Tech Zone',
          items: [
            OrderItemSummary(
              productId: 'p1',
              productName: 'Organic Honey',
              quantity: 2,
              unitPrice: 225.0,
            ),
          ],
        );

        await service.recordOrder(newOrder);

        final updatedOrders = await service.getOrders();
        expect(updatedOrders.first.orderId, 'PC-999999');
        expect(updatedOrders.first.totalAmount, 450.0);
        expect(updatedOrders.first.items.length, 1);
      },
    );

    test('OrderItemSummary converts cleanly to Product for reordering', () {
      final summary = OrderItemSummary(
        productId: 'prod_101',
        productName: 'Brown Eggs (6 pcs)',
        quantity: 1,
        unitPrice: 65.0,
      );

      final product = summary.toProduct();
      expect(product.id, 'prod_101');
      expect(product.name, 'Brown Eggs (6 pcs)');
      expect(product.price, 65.0);
    });

    test(
      'catalog images enrich saved items without changing order snapshots',
      () {
        final savedItem = OrderItemSummary(
          productId: '4',
          productName: 'Name at purchase',
          quantity: 2,
          unitPrice: 15,
        );
        final hydrated = OrderItemSummary.withCatalogImages(
          [savedItem],
          [
            Product(
              id: '4',
              name: 'Current catalog name',
              price: 99,
              imageUrl: 'https://example.com/item.png',
            ),
          ],
        ).single;

        expect(hydrated.imageUrl, 'https://example.com/item.png');
        expect(hydrated.productName, 'Name at purchase');
        expect(hydrated.quantity, 2);
        expect(hydrated.unitPrice, 15);
      },
    );

    testWidgets('placed order history details expose cancellation', (
      tester,
    ) async {
      final item = OrderItemSummary(
        productId: '4',
        productName: 'Fresh Apples',
        quantity: 1,
        unitPrice: 15,
      );
      final order = OrderHistoryItem(
        orderId: 'PC-4',
        status: 'Order Placed',
        createdAt: DateTime(2026, 11, 3),
        totalAmount: 15,
        items: [item],
      );
      final provider = CustomerOrderTrackingProvider(
        dataSource: _OrderDetailsSource(
          CustomerOrderTracking(
            id: '4',
            status: 'placed',
            createdAt: order.createdAt,
            totalAmount: order.totalAmount,
            deliveryAddress: null,
            items: [item],
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailScreen(
            order: order,
            userId: 'customer-a',
            trackingProvider: provider,
          ),
        ),
      );

      expect(find.text('Cancel Order'), findsOneWidget);
      provider.dispose();
    });

    test(
      'New authenticated user has empty order history (no fake orders)',
      () async {
        final newCustomerOrders = await service.getOrders(
          userId: 'new_customer_deva',
        );
        expect(
          newCustomerOrders.isEmpty,
          true,
          reason: 'New customers must never see fake mock orders',
        );
      },
    );

    test(
      'Recording an order for a specific user scopes it to that user',
      () async {
        const userId = 'user_deva_123';
        final order = OrderHistoryItem(
          orderId: 'PC-100200',
          status: 'Order Placed',
          createdAt: DateTime.now(),
          totalAmount: 120.0,
          paymentMethod: 'Cash on Delivery',
          deliveryAddress: 'Home — Hitech City',
          items: [
            OrderItemSummary(
              productId: 'p_milk',
              productName: 'Fresh Milk',
              quantity: 1,
              unitPrice: 120.0,
            ),
          ],
        );

        await service.recordOrder(order, userId: userId);

        final devaOrders = await service.getOrders(userId: userId);
        expect(devaOrders.length, 1);
        expect(devaOrders.first.orderId, 'PC-100200');

        // Another user has 0 orders
        final otherOrders = await service.getOrders(userId: 'other_user_456');
        expect(otherOrders.isEmpty, true);
      },
    );
  });
}

class _OrderDetailsSource implements CustomerOrderTrackingDataSource {
  CustomerOrderTracking order;

  _OrderDetailsSource(this.order);

  @override
  Future<CustomerOrderTracking?> getCurrentOrderForHome({
    required String userId,
  }) async => order;

  @override
  Future<CustomerOrderTracking?> getOrderDetails({
    required String orderId,
    required String userId,
  }) async => order;

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String userId,
  }) async {
    order = order.copyWith(status: 'cancelled');
  }
}
