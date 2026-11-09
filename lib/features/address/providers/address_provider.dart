import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';

class AddressProvider extends ChangeNotifier {
  static const String _storageKey = 'pc_saved_addresses';
  static const String _selectedIdKey = 'pc_selected_address_id';

  final AddressDataSource _dataSource;
  final List<AddressModel> _addresses = [];
  final Set<String> _persistedAddressIds = {};
  AddressModel? _selectedAddress;
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _loadError;
  String? _currentUserId;

  AddressProvider({bool autoLoad = true, AddressDataSource? dataSource})
    : _dataSource = dataSource ?? AddressService() {
    if (autoLoad) {
      loadAddresses();
    }
  }

  List<AddressModel> get addresses => [..._addresses];
  AddressModel? get selectedAddress => _selectedAddress;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  String? get currentUserId => _currentUserId;

  String get currentDeliverySpeed {
    final mins = _selectedAddress?.deliveryTimeMinutes ?? 5;
    return '$mins minutes';
  }

  String get currentShortDisplay {
    if (_selectedAddress != null) {
      return _selectedAddress!.shortDisplay;
    }
    return 'Select Delivery Location';
  }

  void clearAddresses() {
    _loadGeneration++;
    _addresses.clear();
    _selectedAddress = null;
    _persistedAddressIds.clear();
    _currentUserId = null;
    _isLoaded = false;
    _isLoading = false;
    _loadError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> loadAddressesForUser(
    String userId, {
    String? defaultName,
    String? defaultPhone,
  }) async {
    _currentUserId = userId;
    final generation = ++_loadGeneration;
    _isLoading = true;
    _isLoaded = false;
    _loadError = null;
    notifyListeners();

    try {
      final cachedAddresses = await _readCachedAddresses(userId);
      var addresses = await _dataSource.loadAddresses(expectedUserId: userId);
      if (addresses.isEmpty && cachedAddresses.isNotEmpty) {
        addresses = [
          for (final address in cachedAddresses)
            await _dataSource.saveAddress(address, expectedUserId: userId),
        ];
      }

      if (generation != _loadGeneration || _currentUserId != userId) return;
      _addresses
        ..clear()
        ..addAll(addresses);
      _persistedAddressIds
        ..clear()
        ..addAll(addresses.map((address) => address.id));
      await _restoreSelectedAddress(userId);
      await _saveToStorage();
      _isLoaded = true;
    } catch (error) {
      if (generation != _loadGeneration || _currentUserId != userId) return;
      _addresses.clear();
      _persistedAddressIds.clear();
      _selectedAddress = null;
      _isLoaded = true;
      _loadError = error.toString();
    } finally {
      if (generation == _loadGeneration && _currentUserId == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  int _loadGeneration = 0;

  Future<void> loadAddresses({
    String? userId,
    String? defaultName,
    String? defaultPhone,
  }) async {
    if (userId != null) {
      await loadAddressesForUser(
        userId,
        defaultName: defaultName,
        defaultPhone: defaultPhone,
      );
      return;
    }

    final activeKey = _currentUserId != null
        ? '${_storageKey}_$_currentUserId'
        : _storageKey;
    final activeSelectedKey = _currentUserId != null
        ? '${_selectedIdKey}_$_currentUserId'
        : _selectedIdKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(activeKey);
      final selectedId = prefs.getString(activeSelectedKey);

      _addresses.clear();

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        for (final item in decoded) {
          _addresses.add(AddressModel.fromJson(item as Map<String, dynamic>));
        }
      }

      // If no saved addresses exist:
      // For unauthenticated / standalone test environments (_currentUserId == null),
      // populate standard demo addresses.
      // Authenticated accounts start clean and only contain addresses the user adds.
      if (_addresses.isEmpty) {
        if (_currentUserId == null) {
          _addresses.addAll(_defaultAddresses());
          await _saveToStorage();
        }
      }

      // Select active address
      if (selectedId != null) {
        final found = _addresses.where((a) => a.id == selectedId).toList();
        if (found.isNotEmpty) {
          _selectedAddress = found.first;
        } else {
          _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
        }
      } else {
        _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
      }

      _isLoaded = true;
      _isLoading = false;
      _loadError = null;
      _persistedAddressIds.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('AddressProvider.loadAddresses error: $e');
      if (_addresses.isEmpty && _currentUserId == null) {
        _addresses.addAll(_defaultAddresses());
        _selectedAddress = _addresses.first;
      }
      _isLoaded = true;
      _isLoading = false;
      _loadError = e.toString();
      notifyListeners();
    }
  }

  Future<void> selectAddress(AddressModel address) async {
    final matchingAddresses = _addresses.where(
      (candidate) => candidate.id == address.id,
    );
    if (matchingAddresses.isEmpty) return;
    _selectedAddress = matchingAddresses.first;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final activeSelectedKey = _currentUserId != null
          ? '${_selectedIdKey}_$_currentUserId'
          : _selectedIdKey;
      await prefs.setString(activeSelectedKey, address.id);
    } catch (e) {
      debugPrint('AddressProvider.selectAddress error: $e');
    }
  }

  Future<void> addAddress(AddressModel newAddress) async {
    final userId = _currentUserId;
    final savedAddress = userId == null
        ? newAddress
        : await _dataSource.saveAddress(newAddress, expectedUserId: userId);
    _loadError = null;
    _addresses.removeWhere((address) => address.id == savedAddress.id);
    _addresses.add(savedAddress);
    _selectedAddress = savedAddress;
    if (userId != null) _persistedAddressIds.add(savedAddress.id);
    notifyListeners();

    await _saveToStorage();

    try {
      final prefs = await SharedPreferences.getInstance();
      final activeSelectedKey = _currentUserId != null
          ? '${_selectedIdKey}_$_currentUserId'
          : _selectedIdKey;
      await prefs.setString(activeSelectedKey, savedAddress.id);
    } catch (_) {}
  }

  Future<void> deleteAddress(String id) async {
    final userId = _currentUserId;
    if (userId != null) {
      await _dataSource.deleteAddress(id, expectedUserId: userId);
    }
    _addresses.removeWhere((a) => a.id == id);
    _persistedAddressIds.remove(id);
    if (_selectedAddress?.id == id) {
      _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
    }
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> reload() async {
    final userId = _currentUserId;
    if (userId == null) {
      await loadAddresses();
    } else {
      await loadAddressesForUser(userId);
    }
  }

  bool hasValidSelectedAddressFor(String userId) =>
      _isLoaded &&
      !_isLoading &&
      _loadError == null &&
      _currentUserId == userId &&
      _selectedAddress != null &&
      _selectedAddress!.isValidForDelivery &&
      _persistedAddressIds.contains(_selectedAddress!.id) &&
      _addresses.any((address) => address.id == _selectedAddress!.id);

  Future<List<AddressModel>> _readCachedAddresses(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('${_storageKey}_$userId');
    if (jsonString == null || jsonString.isEmpty) return [];
    final decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((item) => AddressModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _restoreSelectedAddress(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString('${_selectedIdKey}_$userId');
    _selectedAddress = _addresses
        .where((address) => address.id == selectedId)
        .firstOrNull;
    _selectedAddress ??= _addresses
        .where((address) => address.isDefault)
        .firstOrNull;
    _selectedAddress ??= _addresses.firstOrNull;
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeKey = _currentUserId != null
          ? '${_storageKey}_$_currentUserId'
          : _storageKey;
      final encoded = jsonEncode(_addresses.map((a) => a.toJson()).toList());
      await prefs.setString(activeKey, encoded);
      if (_currentUserId != null && _selectedAddress != null) {
        await prefs.setString(
          '${_selectedIdKey}_$_currentUserId',
          _selectedAddress!.id,
        );
      }
    } catch (e) {
      debugPrint('AddressProvider._saveToStorage error: $e');
    }
  }

  List<AddressModel> _defaultAddresses() {
    return [
      AddressModel(
        id: 'addr_home',
        tag: 'Home',
        houseNo: 'Plot 12, Floor 2',
        area: 'Tech Zone, Hitech City',
        landmark: 'Opposite Cyber Towers',
        recipientName: 'Ajay Reddy',
        phoneNumber: '+91 98765 43210',
        deliveryTimeMinutes: 5,
        isDefault: true,
      ),
      AddressModel(
        id: 'addr_work',
        tag: 'Work',
        houseNo: 'Suite 404, Building 3',
        area: 'Mindspace IT Park, Madhapur',
        landmark: 'Near Inorbit Mall',
        recipientName: 'Ajay Reddy',
        phoneNumber: '+91 98765 43210',
        deliveryTimeMinutes: 8,
        isDefault: false,
      ),
    ];
  }
}
