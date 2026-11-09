import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address_model.dart';

abstract class AddressDataSource {
  Future<List<AddressModel>> loadAddresses({required String expectedUserId});

  Future<AddressModel> saveAddress(
    AddressModel address, {
    required String expectedUserId,
  });

  Future<void> deleteAddress(
    String addressId, {
    required String expectedUserId,
  });
}

class AddressService implements AddressDataSource {
  final SupabaseClient? _explicitClient;

  AddressService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase is not initialized.');
    }
  }

  String _verifiedUserId(String expectedUserId) {
    final actualUserId = _client.auth.currentUser?.id;
    if (actualUserId == null || actualUserId != expectedUserId) {
      throw StateError('Sign in to manage delivery addresses.');
    }
    return actualUserId;
  }

  @override
  Future<List<AddressModel>> loadAddresses({
    required String expectedUserId,
  }) async {
    final userId = _verifiedUserId(expectedUserId);
    final rows = await _client
        .from('customer_addresses')
        .select(
          'id, tag, house_no, area, landmark, recipient_name, phone_number, '
          'is_default',
        )
        .eq('user_id', userId)
        .order('created_at');
    return rows.map((row) => AddressModel.fromJson(row)).toList();
  }

  @override
  Future<AddressModel> saveAddress(
    AddressModel address, {
    required String expectedUserId,
  }) async {
    final userId = _verifiedUserId(expectedUserId);
    final addressJson = address.toJson()..remove('delivery_time_minutes');
    final row = await _client
        .from('customer_addresses')
        .upsert({...addressJson, 'user_id': userId}, onConflict: 'user_id,id')
        .select(
          'id, tag, house_no, area, landmark, recipient_name, phone_number, '
          'is_default',
        )
        .single();
    return AddressModel.fromJson(row);
  }

  @override
  Future<void> deleteAddress(
    String addressId, {
    required String expectedUserId,
  }) async {
    final userId = _verifiedUserId(expectedUserId);
    await _client
        .from('customer_addresses')
        .delete()
        .eq('user_id', userId)
        .eq('id', addressId);
  }
}
