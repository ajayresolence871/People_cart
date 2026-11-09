import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_cart/features/admin/models/admin_dashboard_data.dart';
import 'package:people_cart/features/admin/models/delivery_assignment_data.dart';
import 'package:people_cart/features/admin/providers/admin_dashboard_provider.dart';
import 'package:people_cart/features/admin/screens/admin_dashboard_screen.dart';
import 'package:people_cart/features/admin/services/admin_dashboard_service.dart';
import 'package:people_cart/features/admin/services/delivery_assignment_service.dart';
import 'package:people_cart/models/user_profile.dart';
import 'package:people_cart/providers/auth_provider.dart';

class _FakeAdminDashboardDataSource implements AdminDashboardDataSource {
  AdminOrderMetrics? metrics = AdminOrderMetrics(
    totalOrders: 12,
    ordersToday: 3,
    ordersByStatus: {
      'placed': 2,
      'preparing': 1,
      'out_for_delivery': 0,
      'delivered': 8,
      'cancelled': 1,
    },
    nonCancelledOrderValueToday: 12480,
    dailyOrderCounts: List.generate(
      7,
      (index) => AdminDailyOrderCount(
        date: DateTime(2026, 11, index + 1),
        count: index + 1,
      ),
    ),
  );
  List<AdminRecentOrder>? recentOrders = const [];
  Object? metricsFailure;
  Object? recentOrdersFailure;

  @override
  Future<AdminOrderMetrics> loadOrderMetrics() async {
    if (metricsFailure != null) throw metricsFailure!;
    return metrics!;
  }

  @override
  Future<List<AdminRecentOrder>> loadRecentOrders() async {
    if (recentOrdersFailure != null) throw recentOrdersFailure!;
    return recentOrders!;
  }
}

class _FakeDashboardAssignments implements DeliveryAssignmentDataSource {
  @override
  Future<List<DeliveryManagedOrder>> loadOrders() async => [
    const DeliveryManagedOrder(
      id: '9',
      createdAt: null,
      totalAmount: 120,
      status: 'placed',
      assignedPartnerId: 'partner-2-id',
    ),
  ];

  @override
  Future<List<DeliveryPartner>> loadPartners() async => const [
    DeliveryPartner(id: 'partner-2-id', name: 'Partner 2'),
  ];

  @override
  Future<void> assignOrder(String orderId, String? partnerId) async {}

  @override
  Future<List<DeliveryManagedOrder>> loadMyAssignedOrders() async => const [];

  @override
  Future<void> updateMyOrderStatus(String orderId, String status) async {}
}

void main() {
  group('AdminDashboardProvider', () {
    test('loads real-data section results independently', () async {
      final source = _FakeAdminDashboardDataSource()
        ..recentOrdersFailure = StateError('orders access denied');
      final provider = AdminDashboardProvider(dataSource: source);

      await provider.loadDashboard();

      expect(provider.metrics?.totalOrders, 12);
      expect(provider.recentOrders, isNull);
      expect(provider.recentOrdersError, contains('orders access denied'));
      expect(provider.isLoading, isFalse);
    });

    test('keeps honest empty lists from the data source', () async {
      final source = _FakeAdminDashboardDataSource();
      final provider = AdminDashboardProvider(dataSource: source);

      await provider.loadDashboard();

      expect(provider.recentOrders, isEmpty);
      expect(provider.metrics?.totalOrders, 12);
    });
  });

  group('AdminDashboardScreen access and states', () {
    testWidgets('blocks direct access for a non-admin profile', (tester) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(
          id: 'customer-1',
          role: 'customer',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin access required'), findsOneWidget);
      expect(find.text('Total orders'), findsNothing);
    });

    testWidgets('renders dashboard and navigates to unified inventory', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      final source = _FakeAdminDashboardDataSource();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: AdminDashboardScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Operations overview'), findsOneWidget);
      expect(find.text('Total orders'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Order value today'), findsOneWidget);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('7-day orders trend'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(
        find.textContaining(
          'If orders exist in Supabase, verify the admin SELECT policy.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();

      expect(find.text('Inventory'), findsWidgets);
      expect(find.text('Products & inventory'), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Stock'), findsNothing);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
    });

    testWidgets('resolves assigned partner name from the partner directory', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      final dashboardData = _FakeAdminDashboardDataSource()
        ..recentOrders = const [
          AdminRecentOrder(
            id: '9',
            createdAt: null,
            totalAmount: 120,
            status: 'placed',
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: AdminDashboardScreen(
              dataSource: dashboardData,
              deliveryAssignmentDataSource: _FakeDashboardAssignments(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Recent orders'),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Partner 2'), findsOneWidget);
      expect(find.text('Assigned partner unavailable'), findsNothing);
    });

    testWidgets('overview remains usable on a narrow phone layout', (
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
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: AdminDashboardScreen(
              dataSource: _FakeAdminDashboardDataSource(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('7-day orders trend'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('shows a dashboard error rather than a fabricated summary', (
      tester,
    ) async {
      final auth = AuthProvider(
        isAuthenticatedForTesting: true,
        initialProfileForTesting: UserProfile(id: 'admin-1', role: 'admin'),
      );
      final source = _FakeAdminDashboardDataSource()
        ..metricsFailure = StateError('orders permission denied');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: AdminDashboardScreen(dataSource: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('orders permission denied'), findsWidgets);
      expect(find.text('Total orders'), findsNothing);
    });
  });
}
