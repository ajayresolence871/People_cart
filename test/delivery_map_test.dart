import 'package:flutter_test/flutter_test.dart';
import 'package:people_cart/features/admin/models/delivery_assignment_data.dart';
import 'package:people_cart/features/admin/services/delivery_navigation_service.dart';

void main() {
  group('Delivery map destination data', () {
    test('reads valid destination coordinates and address from snapshot', () {
      final order = DeliveryManagedOrder.fromJson({
        'order_id': 9,
        'status': 'preparing',
        'delivery_address_snapshot': {
          'tag': 'Home',
          'house_no': 'Flat 202',
          'area': 'Kondapur',
          'landmark': 'Market',
          'latitude': 17.46,
          'longitude': '78.36',
        },
      });

      expect(order.destinationLatitude, 17.46);
      expect(order.destinationLongitude, 78.36);
      expect(order.navigationAddress, 'Flat 202, Kondapur, Market');
    });

    test(
      'uses plain delivery address returned by the order RPC as fallback',
      () {
        final order = DeliveryManagedOrder.fromJson({
          'order_id': 13,
          'status': 'out_for_delivery',
          'delivery_address': 'Home - Flat 202, Kondapur',
        });

        expect(order.deliveryAddress, 'Home - Flat 202, Kondapur');
        expect(order.navigationAddress, 'Home - Flat 202, Kondapur');
      },
    );

    test(
      'rejects incomplete, malformed, non-finite and out-of-range coordinates',
      () {
        expect(
          DeliveryManagedOrder.coordinatesFromSnapshot({'latitude': 17.4}),
          isNull,
        );
        expect(
          DeliveryManagedOrder.coordinatesFromSnapshot({
            'latitude': 91,
            'longitude': 78,
          }),
          isNull,
        );
        expect(
          DeliveryManagedOrder.coordinatesFromSnapshot({
            'latitude': 'NaN',
            'longitude': 78,
          }),
          isNull,
        );
      },
    );
  });

  group('External navigation destination', () {
    test('uses coordinates for Android geo navigation', () {
      final uri = DeliveryNavigationService.destinationUri(
        latitude: 17.46,
        longitude: 78.36,
        address: 'Flat 202, Kondapur',
        isAndroid: true,
      );

      expect(uri?.scheme, 'geo');
      expect(uri?.path, '17.46,78.36');
      expect(uri?.queryParameters['q'], contains('Flat 202, Kondapur'));
    });

    test('uses saved address if coordinates are unavailable', () {
      final uri = DeliveryNavigationService.destinationUri(
        latitude: null,
        longitude: null,
        address: 'Flat 202, Kondapur',
        isAndroid: true,
      );

      expect(uri?.scheme, 'geo');
      expect(uri?.path, '0,0');
      expect(uri?.queryParameters['q'], 'Flat 202, Kondapur');
    });

    test('returns null if neither coordinates nor an address is usable', () {
      expect(
        DeliveryNavigationService.destinationUri(
          latitude: null,
          longitude: null,
          address: '  ',
          isAndroid: true,
        ),
        isNull,
      );
    });
  });
}
