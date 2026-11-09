import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class DeliveryNavigationService {
  static Uri? destinationUri({
    required double? latitude,
    required double? longitude,
    required String? address,
    required bool isAndroid,
  }) {
    final hasCoordinates =
        latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    final destination = hasCoordinates
        ? '$latitude,$longitude'
        : address?.trim();
    if (destination == null || destination.isEmpty) return null;
    if (isAndroid) {
      final query = hasCoordinates
          ? '$destination ($address)'.trim()
          : destination;
      return Uri(
        scheme: 'geo',
        path: hasCoordinates ? destination : '0,0',
        queryParameters: {'q': query},
      );
    }
    return Uri.https('maps.apple.com', '/', {
      'daddr': destination,
      'dirflg': 'd',
    });
  }

  static Future<bool> open({
    required double? latitude,
    required double? longitude,
    required String? address,
  }) async {
    final uri = destinationUri(
      latitude: latitude,
      longitude: longitude,
      address: address,
      isAndroid: Platform.isAndroid,
    );
    return uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
