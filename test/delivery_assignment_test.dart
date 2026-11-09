import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/features/admin/models/delivery_assignment_data.dart';
import 'package:people_cart/features/admin/providers/delivery_assignment_provider.dart';
import 'package:people_cart/features/admin/screens/delivery_partner_order_details_screen.dart';
import 'package:people_cart/features/admin/screens/admin_delivery_assignments_screen.dart';
import 'package:people_cart/features/admin/screens/delivery_partner_placeholder_screen.dart';
import 'package:people_cart/features/admin/services/delivery_assignment_service.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';

class _FakeDeliverySource implements DeliveryAssignmentDataSource {
  List<DeliveryManagedOrder> orders = [];
  List<DeliveryPartner> partners = [];
  Object? failure;
  Object? assignmentFailure;
  Object? ordersFailure;
  Completer<void>? assignmentCompleter;
  Completer<void>? updateCompleter;
  final List<Completer<List<DeliveryManagedOrder>>> orderLoadCompleters = [];
  int adminOrderLoads = 0;
  int assignmentCalls = 0;
  final List<(String, String?)> assignments = [];
  final List<(String, String)> statusUpdates = [];
  int partnerOrderLoads = 0;

  @override
  Future<List<DeliveryManagedOrder>> loadOrders() {
    final requestIndex = adminOrderLoads++;
    if (requestIndex < orderLoadCompleters.length) {
      return orderLoadCompleters[requestIndex].future;
    }
    if (failure != null) throw failure!;
    if (ordersFailure != null) throw ordersFailure!;
    return Future.value(orders);
  }

  @override
  Future<List<DeliveryPartner>> loadPartners() async {
    if (failure != null) throw failure!;
    return partners;
  }

  @override
  Future<void> assignOrder(String orderId, String? partnerId) async {
    assignmentCalls++;
    if (assignmentFailure != null) throw assignmentFailure!;
    if (failure != null) throw failure!;
    await assignmentCompleter?.future;
    assignments.add((orderId, partnerId));
    orders = orders
        .map(
          (order) => order.id == orderId
              ? DeliveryManagedOrder(
                  id: order.id,
                  createdAt: order.createdAt,
                  totalAmount: order.totalAmount,
                  status: order.status,
                  assignedPartnerId: partnerId,
                  assignedPartnerName: partners
                      .where((partner) => partner.id == partnerId)
                      .firstOrNull
                      ?.displayName,
                  itemCount: order.itemCount,
                  items: order.items,
                  deliveryAddress: order.deliveryAddress,
                )
              : order,
        )
        .toList();
  }

  @override
  Future<List<DeliveryManagedOrder>> loadMyAssignedOrders() async {
    partnerOrderLoads++;
    if (failure != null) throw failure!;
    return orders;
  }

  @override
  Future<void> updateMyOrderStatus(String orderId, String status) async {
    if (failure != null) throw failure!;
    statusUpdates.add((orderId, status));
    await updateCompleter?.future;
    orders = orders
        .map(
          (order) => order.id == orderId
              ? DeliveryManagedOrder(
                  id: order.id,
                  createdAt: order.createdAt,
                  totalAmount: order.totalAmount,
                  status: status,
                  assignedPartnerId: order.assignedPartnerId,
                  assignedPartnerName: order.assignedPartnerName,
                  itemCount: order.itemCount,
                  items: order.items,
                  deliveryAddress: order.deliveryAddress,
                )
              : order,
        )
        .toList();
  }
}

DeliveryManagedOrder _order({
  String id = '45',
  String status = 'preparing',
  String? partnerId,
  bool includePartnerName = true,
}) => DeliveryManagedOrder(
  id: id,
  createdAt: DateTime(2026, 11, 2),
  totalAmount: 120,
  status: status,
  assignedPartnerId: partnerId,
  assignedPartnerName: partnerId == null || !includePartnerName ? null : 'Sam',
  itemCount: 12,
);

void main() {
  group('Delivery assignment providers', () {
    test(
      'parses only the saved item and address snapshots returned by RPC',
      () {
        final order = DeliveryManagedOrder.fromJson({
          'order_id': 45,
          'created_at': '2026-11-02T10:00:00Z',
          'total_amount': 120,
          'status': 'out_for_delivery',
          'assigned_delivery_partner_id': 'partner-1',
          'items': [
            {
              'product_id': 7,
              'product_name': 'Fresh Apples',
              'quantity': 2,
              'unit_price': 40,
            },
          ],
          'delivery_address_snapshot': {
            'tag': 'Home',
            'house_no': '12 Main Street',
            'area': 'Downtown',
            'landmark': 'City Park',
          },
        });

        expect(order.itemCount, 2);
        expect(order.items.single.productName, 'Fresh Apples');
        expect(order.items.single.productId, '7');
        expect(order.items.single.lineTotal, 80);
        expect(
          order.deliveryAddress,
          'Home · 12 Main Street, Downtown, Near City Park',
        );
      },
    );

    test('loads orders and partners and refreshes after assignment', () async {
      final source = _FakeDeliverySource()
        ..orders = [_order(status: 'placed')]
        ..partners = [const DeliveryPartner(id: 'partner-1', name: 'Sam')];
      final provider = AdminDeliveryAssignmentProvider(dataSource: source);

      await provider.load();
      expect(provider.orders?.single.id, '45');
      expect(provider.partners?.single.displayName, 'Sam');

      expect(await provider.assign('45', 'partner-1'), isTrue);
      expect(source.assignments, [('45', 'partner-1')]);
      expect(provider.orders?.single.status, 'placed');
      expect(provider.actionError, isNull);
    });

    test('keeps assignment permission errors visible', () async {
      final source = _FakeDeliverySource()
        ..assignmentFailure = StateError('admin only');
      final provider = AdminDeliveryAssignmentProvider(dataSource: source);

      expect(await provider.assign('45', 'partner-1'), isFalse);
      expect(provider.actionError, contains('admin only'));
    });

    test(
      'blocks assignment locally after pickup and terminal statuses',
      () async {
        final source = _FakeDeliverySource()
          ..orders = [
            _order(id: '45', status: 'out_for_delivery'),
            _order(id: '46', status: 'delivered'),
            _order(id: '47', status: 'cancelled'),
            _order(id: '48', status: 'preparing'),
          ];
        final provider = AdminDeliveryAssignmentProvider(dataSource: source);
        await provider.load();

        expect(await provider.assign('45', 'partner-1'), isFalse);
        expect(provider.actionError, contains('locked after pickup'));
        expect(await provider.assign('46', 'partner-1'), isFalse);
        expect(await provider.assign('47', 'partner-1'), isFalse);
        expect(source.assignmentCalls, 0);

        expect(await provider.assign('48', 'partner-1'), isTrue);
        expect(source.assignments, [('48', 'partner-1')]);
      },
    );

    test('prevents duplicate assignments for the same order', () async {
      final source = _FakeDeliverySource()
        ..orders = [_order()]
        ..assignmentCompleter = Completer<void>()
        ..partners = [const DeliveryPartner(id: 'partner-1', name: 'Sam')];
      final provider = AdminDeliveryAssignmentProvider(dataSource: source);

      final first = provider.assign('45', 'partner-1');
      await Future<void>.delayed(Duration.zero);
      expect(await provider.assign('45', 'partner-1'), isFalse);
      expect(source.assignmentCalls, 1);
      expect(provider.actionError, contains('already in progress'));

      source.assignmentCompleter!.complete();
      expect(await first, isTrue);
      expect(source.assignments, [('45', 'partner-1')]);
    });

    test('assignment succeeds even when the follow-up refresh fails', () async {
      final source = _FakeDeliverySource()
        ..orders = [_order()]
        ..partners = [const DeliveryPartner(id: 'partner-1', name: 'Sam')];
      final provider = AdminDeliveryAssignmentProvider(dataSource: source);
      await provider.load();
      source.ordersFailure = StateError('refresh unavailable');

      expect(await provider.assign('45', 'partner-1'), isTrue);
      expect(source.assignments, [('45', 'partner-1')]);
      expect(provider.orders?.single.assignedPartnerId, isNull);
      expect(provider.error, contains('refresh unavailable'));
      expect(provider.actionMessage, contains('Assignment saved'));
      expect(provider.actionMessage, contains('could not be refreshed'));
    });

    test(
      'latest overlapping refresh wins when requests finish out of order',
      () async {
        final source = _FakeDeliverySource()
          ..orderLoadCompleters.addAll([
            Completer<List<DeliveryManagedOrder>>(),
            Completer<List<DeliveryManagedOrder>>(),
          ]);
        final provider = AdminDeliveryAssignmentProvider(dataSource: source);

        final firstLoad = provider.load();
        final secondLoad = provider.load();
        source.orderLoadCompleters[1].complete([_order(id: 'newer')]);
        await secondLoad;
        source.orderLoadCompleters[0].complete([_order(id: 'older')]);
        await firstLoad;

        expect(provider.orders?.single.id, 'newer');
        expect(provider.isLoading, isFalse);
      },
    );

    test('disposed provider does not notify when a load completes', () async {
      final source = _FakeDeliverySource()
        ..orderLoadCompleters.add(Completer<List<DeliveryManagedOrder>>());
      final provider = AdminDeliveryAssignmentProvider(dataSource: source);
      var notifications = 0;
      provider.addListener(() => notifications++);

      final pendingLoad = provider.load();
      final notificationsBeforeDispose = notifications;
      provider.dispose();
      source.orderLoadCompleters.single.complete([_order()]);
      await pendingLoad;

      expect(notifications, notificationsBeforeDispose);
    });

    test(
      'delivery partner can advance an assigned order and refresh',
      () async {
        final source = _FakeDeliverySource()..orders = [_order()];
        final provider = DeliveryPartnerOrdersProvider(dataSource: source);

        await provider.load();
        expect(await provider.updateStatus('45', 'out_for_delivery'), isTrue);
        expect(source.statusUpdates, [('45', 'out_for_delivery')]);
        expect(provider.orders, hasLength(1));
        expect(provider.orders?.single.status, 'out_for_delivery');
      },
    );

    test(
      'assigned partner can complete both delivery transitions in sequence',
      () async {
        final source = _FakeDeliverySource()
          ..orders = [_order(status: 'preparing', partnerId: 'partner-1')];
        final provider = DeliveryPartnerOrdersProvider(dataSource: source);

        await provider.load();
        expect(await provider.updateStatus('45', 'out_for_delivery'), isTrue);
        expect(provider.orders?.single.status, 'out_for_delivery');

        expect(await provider.updateStatus('45', 'delivered'), isTrue);
        expect(source.statusUpdates, [
          ('45', 'out_for_delivery'),
          ('45', 'delivered'),
        ]);
        expect(provider.orders?.single.status, 'delivered');
      },
    );

    test(
      'rejects invalid local status transitions without calling RPC',
      () async {
        final source = _FakeDeliverySource()..orders = [_order()];
        final provider = DeliveryPartnerOrdersProvider(dataSource: source);
        await provider.load();

        expect(await provider.updateStatus('45', 'delivered'), isFalse);
        expect(source.statusUpdates, isEmpty);
        expect(provider.actionError, contains('cannot be moved'));
      },
    );

    test(
      'pickup cannot start until admin moves the assigned order to preparing',
      () async {
        final source = _FakeDeliverySource()
          ..orders = [_order(status: 'placed', partnerId: 'partner-1')];
        final provider = DeliveryPartnerOrdersProvider(dataSource: source);
        await provider.load();

        expect(await provider.updateStatus('45', 'out_for_delivery'), isFalse);
        expect(source.statusUpdates, isEmpty);
        expect(provider.actionError, contains('cannot be moved'));
      },
    );

    test(
      'ignores a duplicate update while the first request is pending',
      () async {
        final source = _FakeDeliverySource()
          ..orders = [_order()]
          ..updateCompleter = Completer<void>();
        final provider = DeliveryPartnerOrdersProvider(dataSource: source);
        await provider.load();

        final firstUpdate = provider.updateStatus('45', 'out_for_delivery');
        await Future<void>.delayed(Duration.zero);
        expect(await provider.updateStatus('45', 'out_for_delivery'), isFalse);
        expect(source.statusUpdates, [('45', 'out_for_delivery')]);

        source.updateCompleter!.complete();
        expect(await firstUpdate, isTrue);
        expect(provider.orders?.single.status, 'out_for_delivery');
      },
    );

    test('keeps assigned-order load errors visible for retry', () async {
      final source = _FakeDeliverySource()..failure = StateError('offline');
      final provider = DeliveryPartnerOrdersProvider(dataSource: source);

      await provider.load();

      expect(provider.orders, isNull);
      expect(provider.error, contains('offline'));
    });

    group('Delivery order activity', () {
      test('only known non-terminal statuses count as active', () {
        expect(_order(status: 'placed').isActive, isTrue);
        expect(_order(status: 'preparing').isActive, isTrue);
        expect(_order(status: 'out_for_delivery').isActive, isTrue);
        expect(_order(status: 'delivered').isActive, isFalse);
        expect(_order(status: 'cancelled').isActive, isFalse);
        expect(_order(status: 'unexpected_status').isActive, isFalse);
      });
    });

    test(
      'refreshes assigned orders after a stale status update is rejected',
      () async {
        final source = _FakeDeliverySource()..orders = [_order()];
        final provider = DeliveryPartnerOrdersProvider(dataSource: source);
        await provider.load();
        source.failure = StateError('stale status');

        expect(await provider.updateStatus('45', 'out_for_delivery'), isFalse);
        expect(provider.actionError, contains('stale status'));
        expect(source.partnerOrderLoads, 2);
      },
    );
  });

  group('Delivery assignment screens', () {
    testWidgets('admin sees summaries, filters, and confirmed assignments', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      final source = _FakeDeliverySource()
        ..orders = [
          _order(),
          _order(id: '46', partnerId: 'partner-1'),
          _order(id: '47', status: 'out_for_delivery', partnerId: 'partner-1'),
          _order(id: '48', status: 'delivered'),
        ]
        ..partners = [const DeliveryPartner(id: 'partner-1', name: 'Sam')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: AdminDeliveryAssignmentsScreen(dataSource: source),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Delivery assignments'), findsOneWidget);
      expect(find.text('Order #45'), findsOneWidget);
      expect(find.text('1 orders need a delivery partner'), findsOneWidget);
      expect(find.text('Out for delivery'), findsWidgets);
      expect(find.text('Sam'), findsWidgets);
      await tester.tap(find.text('Unassigned').at(1));
      await tester.pumpAndSettle();
      expect(find.text('Order #45'), findsOneWidget);
      expect(find.text('Order #46'), findsNothing);

      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign partner').first);
      await tester.pumpAndSettle();
      expect(find.text('Assign delivery partner'), findsOneWidget);
      await tester.tap(find.text('Confirm assignment'));
      await tester.pumpAndSettle();
      expect(source.assignments, [('45', 'partner-1')]);
    });

    testWidgets(
      'recognizes missing lookup assignments and permits changing them',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
        );
        final source = _FakeDeliverySource()
          ..orders = [
            _order(id: '51', partnerId: 'partner-1'),
            _order(
              id: '52',
              partnerId: 'former-partner',
              includePartnerName: false,
            ),
            _order(id: '53'),
          ]
          ..partners = [
            const DeliveryPartner(id: 'partner-1', name: 'Sam'),
            const DeliveryPartner(id: 'partner-2', name: 'Alex'),
          ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<AuthProvider>.value(
                value: auth,
                child: AdminDeliveryAssignmentsScreen(dataSource: source),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sam'), findsOneWidget);
        expect(find.text('Assigned partner unavailable'), findsOneWidget);
        expect(find.text('Unassigned'), findsWidgets);
        expect(find.text('partner-1'), findsNothing);
        expect(find.text('former-partner'), findsNothing);

        await tester.tap(
          find.widgetWithText(FilledButton, 'Change partner').last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alex').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm assignment'));
        await tester.pumpAndSettle();

        expect(source.assignments, [('52', 'partner-2')]);
        expect(find.text('Alex'), findsOneWidget);
        expect(find.text('Assigned partner unavailable'), findsNothing);
      },
    );

    testWidgets('customer cannot access delivery partner orders', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'customer-1',
          role: 'customer',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const DeliveryPartnerPlaceholderScreen(),
          ),
        ),
      );

      expect(find.text('Delivery partner access required.'), findsOneWidget);
      expect(find.text('Active deliveries'), findsNothing);
    });

    testWidgets('partner can see assigned orders and valid next step', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'partner-1',
          role: 'delivery_partner',
        ),
      );
      final source = _FakeDeliverySource()..orders = [_order()];

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: DeliveryPartnerPlaceholderScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order #45'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();
      expect(find.text('Order Picked Up'), findsOneWidget);
      await tester.tap(find.text('Order Picked Up'));
      await tester.pumpAndSettle();
      expect(find.text('Order Picked Up!'), findsOneWidget);
      expect(source.statusUpdates, [('45', 'out_for_delivery')]);
    });

    testWidgets('placed order waits for store preparation before pickup', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'partner-1',
          role: 'delivery_partner',
        ),
      );
      final source = _FakeDeliverySource()
        ..orders = [_order(status: 'placed', partnerId: 'partner-1')];

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: DeliveryPartnerPlaceholderScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for store'), findsOneWidget);
      expect(find.text('Pick Up Order'), findsNothing);
      expect(source.statusUpdates, isEmpty);
    });

    testWidgets(
      'opening and refreshing partner orders does not update status',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(
            id: 'partner-1',
            role: 'delivery_partner',
          ),
        );
        final source = _FakeDeliverySource()
          ..orders = [_order(partnerId: 'partner-1')];

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: DeliveryPartnerPlaceholderScreen(dataSource: source),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(source.statusUpdates, isEmpty);

        await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(source.statusUpdates, isEmpty);
      },
    );

    testWidgets('admin cannot reassign an order after pickup', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      final source = _FakeDeliverySource()
        ..orders = [_order(status: 'out_for_delivery', partnerId: 'partner-1')]
        ..partners = [const DeliveryPartner(id: 'partner-1', name: 'Sam')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: AdminDeliveryAssignmentsScreen(dataSource: source),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Partner assignment is locked after pickup.'),
        findsOneWidget,
      );
      expect(find.text('Change partner'), findsNothing);
      expect(find.text('Assign partner'), findsNothing);
    });

    testWidgets(
      'partner history filters and order details use returned fields',
      (tester) async {
        final auth = AuthProvider(
          isAuthenticatedForTesting: true,
          initialProfileForTesting: UserProfile(
            id: 'partner-1',
            fullName: 'Sam',
            role: 'delivery_partner',
          ),
        );
        final source = _FakeDeliverySource()
          ..orders = [
            _order(),
            _order(id: '46', status: 'delivered', partnerId: 'partner-1'),
            _order(id: '47', status: 'cancelled', partnerId: 'partner-1'),
            _order(
              id: '48',
              status: 'out_for_delivery',
              partnerId: 'partner-1',
            ),
            _order(
              id: '49',
              status: 'unexpected_status',
              partnerId: 'partner-1',
            ),
          ];

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: DeliveryPartnerPlaceholderScreen(dataSource: source),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hi, Sam'), findsOneWidget);
        expect(find.text('Assigned'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        final assignedMetric = find
            .ancestor(
              of: find.text('Assigned'),
              matching: find.byType(Container),
            )
            .first;
        final activeMetric = find
            .ancestor(of: find.text('Active'), matching: find.byType(Container))
            .first;
        expect(
          find.descendant(of: assignedMetric, matching: find.text('5')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: activeMetric, matching: find.text('2')),
          findsOneWidget,
        );
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text('Order #46'), findsOneWidget);
        expect(find.text('Order #47'), findsOneWidget);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Delivered'));
        await tester.pumpAndSettle();
        expect(find.text('Order #46'), findsOneWidget);
        expect(find.text('Order #47'), findsNothing);

        await tester.tap(find.text('Order #46'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).last, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text('Order details'), findsOneWidget);
        expect(find.textContaining('does not currently return'), findsNothing);
        expect(
          find.textContaining('Item details are unavailable for this order.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('No saved delivery address is available.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('partner detail screen renders returned items and address', (
      tester,
    ) async {
      final order = DeliveryManagedOrder.fromJson({
        'order_id': 50,
        'created_at': '2026-11-02T10:00:00Z',
        'total_amount': 120,
        'status': 'preparing',
        'assigned_delivery_partner_id': 'partner-1',
        'item_count': 3,
        'items': [
          {'product_name': 'Fresh Apples', 'quantity': 2, 'unit_price': 40},
          {'product_name': 'Milk', 'quantity': 1, 'unit_price': 40},
        ],
        'delivery_address_snapshot': {
          'tag': 'Home',
          'house_no': '12 Main Street',
          'area': 'Downtown',
        },
      });

      await tester.pumpWidget(
        MaterialApp(home: DeliveryPartnerOrderDetailsScreen(order: order)),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.textContaining('Fresh Apples'), findsOneWidget);
      expect(find.text('2 × ₹40.00'), findsOneWidget);
      expect(find.text('₹80.00'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Home · 12 Main Street, Downtown'), findsOneWidget);
      expect(find.textContaining('payment'), findsNothing);
    });

    testWidgets('partner profile signs out through AuthProvider', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'partner-1',
          fullName: 'Partner One',
          role: 'delivery_partner',
        ),
      );
      final source = _FakeDeliverySource();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: DeliveryPartnerPlaceholderScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Partner profile'));
      await tester.pumpAndSettle();
      expect(find.text('Partner One'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      if (find.text('Logout').evaluate().isNotEmpty) {
        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();
      }

      expect(auth.isAuthenticated, isFalse);
      expect(find.text('Delivery partner access required.'), findsOneWidget);
    });
  });
}
