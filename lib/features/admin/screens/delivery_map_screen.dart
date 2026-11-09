import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../models/delivery_assignment_data.dart';
import '../services/delivery_navigation_service.dart';

class DeliveryMapScreen extends StatefulWidget {
  final DeliveryManagedOrder order;

  const DeliveryMapScreen({super.key, required this.order});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  Position? _position;
  bool _loading = true;
  String? _locationError;
  bool _permanentlyDenied = false;
  bool _serviceDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _locationError = null;
      _permanentlyDenied = false;
      _serviceDisabled = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _serviceDisabled = true;
        throw const _LocationIssue('Location services are turned off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _permanentlyDenied = true;
        throw const _LocationIssue(
          'Location permission is blocked in settings.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationIssue('Location permission was not granted.');
      }
      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on _LocationIssue catch (error) {
      _locationError = error.message;
    } catch (_) {
      _locationError = 'Could not get your location. Check GPS and try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final latitude = order.destinationLatitude;
    final longitude = order.destinationLongitude;
    final navigationAddress = order.navigationAddress ?? order.deliveryAddress;
    final destination = latitude != null && longitude != null
        ? LatLng(latitude, longitude)
        : null;
    final current = _position == null
        ? null
        : LatLng(_position!.latitude, _position!.longitude);
    final markers = <Marker>[
      if (current case final point?)
        Marker(
          point: point,
          width: 48,
          height: 48,
          child: const _MapPin(
            icon: Icons.my_location,
            color: AppColors.primary,
          ),
        ),
      if (destination case final point?)
        Marker(
          point: point,
          width: 48,
          height: 48,
          child: const _MapPin(
            icon: Icons.location_on,
            color: AppColors.accentPink,
          ),
        ),
    ];
    final center = current ?? destination ?? const LatLng(20, 0);
    final coordinates = [?current, ?destination];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Delivery map • Order #${order.id}'),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(color: AppColors.accentPink),
          if (_locationError != null)
            MaterialBanner(
              content: Text(_locationError!),
              actions: [
                if (_permanentlyDenied)
                  TextButton(
                    onPressed: Geolocator.openAppSettings,
                    child: const Text('Settings'),
                  )
                else if (_serviceDisabled)
                  TextButton(
                    onPressed: Geolocator.openLocationSettings,
                    child: const Text('Turn on'),
                  )
                else
                  TextButton(
                    onPressed: _loadLocation,
                    child: const Text('Retry'),
                  ),
              ],
            ),
          Expanded(
            child: markers.isEmpty
                ? _NoMapCoordinates(
                    hasAddress: navigationAddress?.isNotEmpty == true,
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                      initialCameraFit: coordinates.length > 1
                          ? CameraFit.coordinates(
                              coordinates: coordinates,
                              padding: const EdgeInsets.all(54),
                              maxZoom: 16,
                            )
                          : null,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.people_cart',
                      ),
                      MarkerLayer(markers: markers),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            '© OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.https('www.openstreetmap.org', '/copyright'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (destination == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Text(
                navigationAddress?.isNotEmpty == true
                    ? 'This order has no saved map coordinates. Navigate will use its delivery address.'
                    : 'No destination coordinates or delivery address were returned for this order.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    navigationAddress?.isNotEmpty == true || destination != null
                    ? _navigate
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigate'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigate() async {
    final opened = await DeliveryNavigationService.open(
      latitude: widget.order.destinationLatitude,
      longitude: widget.order.destinationLongitude,
      address: widget.order.navigationAddress ?? widget.order.deliveryAddress,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a navigation app.')),
      );
    }
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Icon(icon, color: color, size: 40);
}

class _NoMapCoordinates extends StatelessWidget {
  final bool hasAddress;

  const _NoMapCoordinates({required this.hasAddress});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: AppColors.primary, size: 54),
          const SizedBox(height: 12),
          Text(
            hasAddress
                ? 'Your current location is unavailable. The delivery address has no saved coordinates.'
                : 'Location and destination coordinates are unavailable.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _LocationIssue implements Exception {
  final String message;
  const _LocationIssue(this.message);
}
