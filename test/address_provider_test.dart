import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:people_cart/features/address/models/address_model.dart';
import 'package:people_cart/features/address/providers/address_provider.dart';
import 'package:people_cart/features/address/services/address_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddressProvider Tests', () {
    late AddressProvider addressProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      addressProvider = AddressProvider(autoLoad: false);
      await addressProvider.loadAddresses();
    });

    test('Initial addresses are loaded with default Home address selected', () {
      expect(addressProvider.addresses.isNotEmpty, true);
      expect(addressProvider.selectedAddress, isNotNull);
      expect(addressProvider.selectedAddress!.tag, 'Home');
      expect(addressProvider.currentDeliverySpeed, '5 minutes');
    });

    test(
      'Selecting a different address updates active address and speed',
      () async {
        final workAddress = addressProvider.addresses.firstWhere(
          (a) => a.tag == 'Work',
        );
        await addressProvider.selectAddress(workAddress);

        expect(addressProvider.selectedAddress!.id, workAddress.id);
        expect(addressProvider.selectedAddress!.tag, 'Work');
        expect(addressProvider.currentDeliverySpeed, '8 minutes');
      },
    );

    test('Adding a new address adds to list and sets as active', () async {
      final newAddr = AddressModel(
        id: 'addr_parents',
        tag: 'Other',
        houseNo: 'Villa 14, Royal Palm',
        area: 'Jubilee Hills',
        recipientName: 'K. Reddy',
        phoneNumber: '+91 91234 56789',
        deliveryTimeMinutes: 10,
      );

      await addressProvider.addAddress(newAddr);

      expect(
        addressProvider.addresses.any((a) => a.id == 'addr_parents'),
        true,
      );
      expect(addressProvider.selectedAddress!.id, 'addr_parents');
      expect(addressProvider.currentDeliverySpeed, '10 minutes');
    });

    test('Deleting an address removes it from list', () async {
      final initialCount = addressProvider.addresses.length;
      final toDeleteId = addressProvider.addresses.last.id;

      await addressProvider.deleteAddress(toDeleteId);

      expect(addressProvider.addresses.length, initialCount - 1);
      expect(addressProvider.addresses.any((a) => a.id == toDeleteId), false);
    });

    test('New authenticated user starts with clean empty address list and no cross-user leakage', () async {
      final dataSource = _FakeAddressDataSource();
      final newProv = AddressProvider(autoLoad: false, dataSource: dataSource);

      // 1. User A logs in and adds an address
      await newProv.loadAddressesForUser('user_a_123');
      expect(newProv.addresses, isEmpty);
      expect(newProv.selectedAddress, isNull);

      final userAAddress = AddressModel(
        id: 'addr_user_a',
        tag: 'Home',
        houseNo: 'House 1A',
        area: 'Cyber City',
        recipientName: 'User A',
        phoneNumber: '+91 99999 11111',
      );
      await newProv.addAddress(userAAddress);
      expect(newProv.addresses.length, 1);
      expect(newProv.selectedAddress?.id, 'addr_user_a');
      expect(newProv.hasValidSelectedAddressFor('user_a_123'), isTrue);

      // 2. User logs out: clearAddresses clears state
      newProv.clearAddresses();
      expect(newProv.addresses, isEmpty);
      expect(newProv.selectedAddress, isNull);
      expect(newProv.currentUserId, isNull);
      expect(newProv.hasValidSelectedAddressFor('user_a_123'), isFalse);

      // 3. User B (e.g. Deva) signs up / logs in
      await newProv.loadAddressesForUser('user_b_456');
      expect(
        newProv.addresses,
        isEmpty,
        reason: 'New user must NOT inherit User A addresses',
      );
      expect(newProv.selectedAddress, isNull);
      expect(newProv.currentShortDisplay, 'Select Delivery Location');

      // 4. Switch back to User A
      await newProv.loadAddressesForUser('user_a_123');
      expect(newProv.addresses.length, 1);
      expect(newProv.addresses.first.recipientName, 'User A');
    });

    test(
      'Authenticated selected address must be complete and persisted',
      () async {
        final provider = AddressProvider(
          autoLoad: false,
          dataSource: _FakeAddressDataSource(
            addresses: [
              AddressModel(
                id: 'incomplete',
                tag: 'Home',
                houseNo: '',
                area: 'Downtown',
                recipientName: 'Customer',
                phoneNumber: '1234567890',
              ),
            ],
          ),
        );
        await provider.loadAddressesForUser('user_c');

        expect(provider.hasValidSelectedAddressFor('user_c'), isFalse);
      },
    );
  });
}

class _FakeAddressDataSource implements AddressDataSource {
  final List<AddressModel> _initialAddresses;
  final Map<String, List<AddressModel>> _addressesByUser = {};
  bool _hasSeededInitialAddresses = false;

  _FakeAddressDataSource({List<AddressModel> addresses = const []})
    : _initialAddresses = [...addresses];

  @override
  Future<List<AddressModel>> loadAddresses({
    required String expectedUserId,
  }) async {
    if (!_hasSeededInitialAddresses) {
      _addressesByUser[expectedUserId] = [..._initialAddresses];
      _hasSeededInitialAddresses = true;
    }
    return [...?_addressesByUser[expectedUserId]];
  }

  @override
  Future<AddressModel> saveAddress(
    AddressModel address, {
    required String expectedUserId,
  }) async {
    final addresses = _addressesByUser.putIfAbsent(expectedUserId, () => []);
    addresses.removeWhere((item) => item.id == address.id);
    addresses.add(address);
    return address;
  }

  @override
  Future<void> deleteAddress(
    String addressId, {
    required String expectedUserId,
  }) async {
    _addressesByUser[expectedUserId]?.removeWhere(
      (address) => address.id == addressId,
    );
  }
}
