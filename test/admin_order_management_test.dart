import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/features/admin/models/admin_dashboard_data.dart';
import 'package:people_cart/features/admin/models/admin_order_data.dart';
import 'package:people_cart/features/admin/models/delivery_assignment_data.dart';
import 'package:people_cart/features/admin/providers/admin_order_provider.dart';
import 'package:people_cart/features/admin/services/delivery_assignment_service.dart';
import 'package:people_cart/features/admin/screens/admin_dashboard_screen.dart';
import 'package:people_cart/features/admin/screens/admin_order_management_screen.dart';
import 'package:people_cart/features/admin/services/admin_dashboard_service.dart';
import 'package:people_cart/features/admin/services/admin_order_service.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';

class _FakeAdminOrderDataSource implements AdminOrderDataSource {
  final List<AdminManagedOrder> orders;
  final Map<String, AdminManagedOrder> details;
  final List<String?> requestedFilters = [];
  final List<(String, String)> statusUpdates = [];
  Object? failure;

  _FakeAdminOrderDataSource({required this.orders, required this.details});

  @override
  Future<List<AdminManagedOrder>> loadOrders({String? status}) async {
    requestedFilters.add(status);
    if (failure != null) throw failure!;
    return orders
        .where((order) => status == null || order.status == status)
        .toList();
  }

  @override
  Future<AdminManagedOrder> loadOrderDetails(String orderId) async {
    if (failure != null) throw failure!;
    final order = details[orderId];
    if (order == null) throw StateError('Order not found.');
    return order;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    if (failure != null) throw failure!;
    final order = details[orderId];
    if (order == null) throw StateError('Order not found.');
    if (!AdminOrderStatus.nextFor(order.status).contains(status)) {
      throw StateError('Invalid order status transition.');
    }
    statusUpdates.add((orderId, status));
    final updated = AdminManagedOrder(
      id: order.id,
      createdAt: order.createdAt,
      totalAmount: order.totalAmount,
      status: status,
      customerName: order.customerName,
      items: order.items,
    );
    details[orderId] = updated;
    final index = orders.indexWhere((candidate) => candidate.id == orderId);
    if (index >= 0) orders[index] = updated;
  }
}

class _FakeAdminDashboardDataSource implements AdminDashboardDataSource {
  @override
  Future<AdminOrderMetrics> loadOrderMetrics() async => const AdminOrderMetrics(
    totalOrders: 1,
    ordersToday: 1,
    ordersByStatus: {'placed': 1},
  );

  @override
  Future<List<AdminRecentOrder>> loadRecentOrders() async => [
    AdminRecentOrder(
      id: '501',
      createdAt: DateTime.utc(2026, 11, 2),
      totalAmount: 450,
      status: 'placed',
    ),
  ];
}

class _FakeDashboardAssignmentDataSource
    implements DeliveryAssignmentDataSource {
  final List<DeliveryManagedOrder> orders;
  final List<DeliveryPartner> partners;
  final List<(String, String?)> assignments = [];

  _FakeDashboardAssignmentDataSource({
    required this.orders,
    required this.partners,
  });

  @override
  Future<List<DeliveryManagedOrder>> loadOrders() async => orders;

  @override
  Future<List<DeliveryPartner>> loadPartners() async => partners;

  @override
  Future<void> assignOrder(String orderId, String? partnerId) async {
    assignments.add((orderId, partnerId));
    final partner = partners.where((item) => item.id == partnerId).firstOrNull;
    final index = orders.indexWhere((item) => item.id == orderId);
    if (index >= 0) {
      final previous = orders[index];
      orders[index] = DeliveryManagedOrder(
        id: previous.id,
        createdAt: previous.createdAt,
        totalAmount: previous.totalAmount,
        status: previous.status,
        assignedPartnerId: partnerId,
        assignedPartnerName: partner?.displayName,
        itemCount: previous.itemCount,
      );
    }
  }

  @override
  Future<List<DeliveryManagedOrder>> loadMyAssignedOrders() async => orders;

  @override
  Future<void> updateMyOrderStatus(String orderId, String status) async {
    throw UnsupportedError('Partner status updates are not used in this test.');
  }
}

AdminManagedOrder _order({
  String id = '501',
  String status = 'placed',
  String? customerName = 'Asha',
  List<AdminOrderLine> items = const [],
}) => AdminManagedOrder(
  id: id,
  createdAt: DateTime.utc(2026, 11, 2, 10),
  totalAmount: 450,
  status: status,
  customerName: customerName,
  items: items,
);

void main() {
  group('Admin order model and provider', () {
    test('preserves nullable historical product references and prices', () {
      final order = AdminManagedOrder.fromJson({
        'order_id': 9,
        'created_at': '2026-11-02T10:00:00Z',
        'total_amount': 75,
        'status': 'placed',
        'customer_name': null,
        'items': [
          {
            'product_id': null,
            'product_name': 'Archived item',
            'quantity': 3,
            'unit_price': 25,
          },
        ],
      });

      expect(order.customerName, isNull);
      expect(order.items.single.productId, isNull);
      expect(order.items.single.lineTotal, 75);
    });

    test(
      'allows only forward transitions and cancellation before dispatch',
      () {
        expect(AdminOrderStatus.nextFor('placed'), ['preparing', 'cancelled']);
        expect(AdminOrderStatus.nextFor('preparing'), ['cancelled']);
        expect(AdminOrderStatus.nextFor('out_for_delivery'), isEmpty);
        expect(AdminOrderStatus.nextFor('delivered'), isEmpty);
        expect(AdminOrderStatus.nextFor('cancelled'), isEmpty);
      },
    );

    test(
      'filters orders and refreshes list and details after an update',
      () async {
        final order = _order();
        final source = _FakeAdminOrderDataSource(
          orders: [order],
          details: {'501': order},
        );
        final provider = AdminOrderProvider(dataSource: source);

        await provider.loadOrders(status: 'placed');
        await provider.loadOrderDetails('501');
        await provider.updateStatus('501', 'preparing');

        expect(source.requestedFilters, ['placed', 'placed']);
        expect(source.statusUpdates, [('501', 'preparing')]);
        expect(provider.orderDetails?.status, 'preparing');
        expect(provider.orders, isEmpty);
        await provider.loadOrders();
        expect(provider.orders?.single.status, 'preparing');
        await expectLater(
          provider.updateStatus('501', 'out_for_delivery'),
          throwsArgumentError,
        );
        await expectLater(
          provider.updateStatus('501', 'delivered'),
          throwsArgumentError,
        );
      },
    );

    test('surfaces order read and update failures', () async {
      final source = _FakeAdminOrderDataSource(orders: [], details: {})
        ..failure = StateError('permission denied');
      final provider = AdminOrderProvider(dataSource: source);

      await provider.loadOrders();
      await provider.loadOrderDetails('501');

      expect(provider.loadError, contains('permission denied'));
      expect(provider.detailsError, contains('permission denied'));
    });
  });

  group('Admin order management screens', () {
    Future<void> pumpOrders(
      WidgetTester tester,
      _FakeAdminOrderDataSource source, {
      String role = 'admin',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(id: 'user-1', role: role),
            ),
            child: AdminOrderManagementScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('blocks direct order access to customers', (tester) async {
      final source = _FakeAdminOrderDataSource(orders: [], details: {});
      await pumpOrders(tester, source, role: 'customer');

      expect(find.text('Admin access required.'), findsOneWidget);
      expect(source.requestedFilters, isEmpty);
    });

    testWidgets('shows real order fields and applies status filters', (
      tester,
    ) async {
      final placed = _order();
      final preparing = _order(id: '502', status: 'preparing');
      final source = _FakeAdminOrderDataSource(
        orders: [placed, preparing],
        details: {'501': placed, '502': preparing},
      );
      await pumpOrders(tester, source);

      expect(find.text('Order #501'), findsOneWidget);
      expect(find.text('Asha'), findsNWidgets(2));
      expect(find.text('₹450.00'), findsNWidgets(2));
      await tester.tap(find.text('Preparing').first);
      await tester.pumpAndSettle();

      expect(source.requestedFilters.last, 'preparing');
      expect(find.text('Order #502'), findsOneWidget);
      expect(find.text('Order #501'), findsNothing);
      expect(find.text('Mark Out for Delivery'), findsNothing);
    });

    testWidgets('shows an honest empty state and retryable read errors', (
      tester,
    ) async {
      final emptySource = _FakeAdminOrderDataSource(orders: [], details: {});
      await pumpOrders(tester, emptySource);
      expect(find.text('No orders found for this filter.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final failingSource = _FakeAdminOrderDataSource(orders: [], details: {})
        ..failure = StateError('admin orders permission denied');
      await pumpOrders(tester, failingSource);
      expect(find.textContaining('permission denied'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('opens detail with saved item snapshots and updates status', (
      tester,
    ) async {
      final order = _order(
        items: const [
          AdminOrderLine(
            productId: null,
            productName: 'Historical product',
            quantity: 2,
            unitPrice: 40,
          ),
        ],
      );
      final source = _FakeAdminOrderDataSource(
        orders: [order],
        details: {'501': order},
      );
      await pumpOrders(tester, source);

      await tester.tap(find.text('Order #501'));
      await tester.pumpAndSettle();

      expect(find.text('Historical product'), findsOneWidget);
      expect(find.textContaining('2 × ₹40.00'), findsOneWidget);
      expect(find.text('₹80.00'), findsOneWidget);
      expect(find.textContaining('Historical item'), findsOneWidget);
      await tester.tap(find.text('Preparing'));
      await tester.pumpAndSettle();

      expect(source.statusUpdates, [('501', 'preparing')]);
      expect(find.text('Preparing'), findsWidgets);
      expect(find.text('Out for delivery'), findsNothing);
    });

    testWidgets('requires confirmation before cancellation', (tester) async {
      final order = _order();
      final source = _FakeAdminOrderDataSource(
        orders: [order],
        details: {'501': order},
      );
      await pumpOrders(tester, source);
      await tester.tap(find.text('Order #501'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this order?'), findsOneWidget);
      expect(source.statusUpdates, isEmpty);
      await tester.tap(find.text('Confirm cancellation'));
      await tester.pumpAndSettle();
      expect(source.statusUpdates, [('501', 'cancelled')]);
    });

    testWidgets('opens orders from dashboard without another nav destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order = _order();
      final source = _FakeAdminOrderDataSource(
        orders: [order],
        details: {'501': order},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(
                id: 'admin-1',
                role: 'admin',
              ),
            ),
            child: AdminDashboardScreen(
              dataSource: _FakeAdminDashboardDataSource(),
              orderDataSource: source,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View all'));
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Order #501'), findsOneWidget);
      expect(source.requestedFilters, [null]);
    });

    testWidgets('opens order details from dashboard recent orders', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order = _order(
        items: const [
          AdminOrderLine(
            productId: null,
            productName: 'Saved dashboard item',
            quantity: 1,
            unitPrice: 40,
          ),
        ],
      );
      final source = _FakeAdminOrderDataSource(
        orders: [order],
        details: {'501': order},
      );
      final assignmentDataSource = _FakeDashboardAssignmentDataSource(
        orders: [
          DeliveryManagedOrder(
            id: '501',
            createdAt: DateTime.utc(2026, 11, 2, 10),
            totalAmount: 450,
            status: 'placed',
            assignedPartnerId: 'partner-1',
          ),
        ],
        partners: const [
          DeliveryPartner(id: 'partner-1', name: 'Deva Partner'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(
                id: 'admin-1',
                role: 'admin',
              ),
            ),
            child: AdminDashboardScreen(
              dataSource: _FakeAdminDashboardDataSource(),
              orderDataSource: source,
              deliveryAssignmentDataSource: assignmentDataSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Details'));
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      expect(find.text('Saved dashboard item'), findsOneWidget);
      expect(find.text('Deva Partner'), findsOneWidget);
    });

    testWidgets('assigns a partner from the recent orders section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final assignmentDataSource = _FakeDashboardAssignmentDataSource(
        orders: [
          DeliveryManagedOrder(
            id: '501',
            createdAt: DateTime.utc(2026, 11, 2),
            totalAmount: 450,
            status: 'placed',
            assignedPartnerId: null,
            itemCount: 3,
          ),
        ],
        partners: const [DeliveryPartner(id: 'partner-1', name: 'Sam')],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider(
              isAuthenticatedForTesting: true,
              initialProfileForTesting: UserProfile(
                id: 'admin-1',
                role: 'admin',
              ),
            ),
            child: AdminDashboardScreen(
              dataSource: _FakeAdminDashboardDataSource(),
              deliveryAssignmentDataSource: assignmentDataSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Assign partner'));
      await tester.tap(find.text('Assign partner'));
      await tester.pumpAndSettle();
      expect(find.text('Assign delivery partner'), findsOneWidget);
      await tester.tap(find.text('Confirm assignment'));
      await tester.pumpAndSettle();

      expect(assignmentDataSource.assignments, [('501', 'partner-1')]);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Reassign partner'), findsOneWidget);
      expect(find.textContaining('3 items'), findsOneWidget);
    });
  });
}
