import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_local_storage.dart';
import '../model/address_change_response.dart';
import '../model/user_profile_response.dart';

/// Wraps `GET /Users/global/{userId}`.
class ProfileRepository {
  /// When `true`, [submitAddressChange] ignores form/profile values and sends
  /// [_staticAddressChangeTestBody] (debug / QA only).
  /// Set to `true` to send [_staticAddressChangeTestBody] instead of form data.
  static const useStaticAddressChangeTestPayload = false;

  final ApiClient _apiClient;
  final AuthLocalStorage _authStorage;

  const ProfileRepository({
    required ApiClient apiClient,
    required AuthLocalStorage authStorage,
  }) : _apiClient = apiClient,
       _authStorage = authStorage;

  Future<UserProfileResponse> getUserProfile() async {
    final userId = _authStorage.getAuthData()?.data?.user?.userId;

    if (userId == null || userId.isEmpty) {
      throw Exception('User ID not found in local storage');
    }

    debugPrint('[PROFILE_REPO] getUserProfile → GET /Users/global/$userId');

    final response = await _apiClient.dio.get<dynamic>(
      '/Users/global/$userId',
    );

    debugPrint(
      '[PROFILE_REPO] ← status=${response.statusCode} '
      'dataType=${response.data.runtimeType}',
    );

    final raw = response.data;
    Map<String, dynamic>? json;

    if (raw is Map<String, dynamic>) {
      json = raw;
    } else if (raw is Map) {
      json = Map<String, dynamic>.from(raw);
    }

    if (json == null) {
      throw Exception('Unexpected response format from profile API');
    }

    final profile = UserProfileResponse.fromJson(json);
    debugPrint(
      '[PROFILE_REPO] parsed → userId=${profile.userId} '
      'name=${profile.fullName} empId=${profile.empId}',
    );

    return profile;
  }

  /// `PUT /Users/{userId}` — update profile fields from edit form.
  Future<void> updateUserProfile({
    required UserProfileResponse profile,
    required String firstName,
    required String lastName,
    required String genderCode,
    required String address,
    required String city,
    required String pin,
    required String emailId,
    required String mobileNo,
    String? depCode,
    String? proCode,
    String? lobCode,
    double? empLat,
    double? empLng,
  }) async {
    final userId =
        profile.userId ?? _authStorage.getAuthData()?.data?.user?.userId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User ID not found in local storage');
    }

    final lat = empLat ?? profile.empLat ?? 0;
    final lng = empLng ?? profile.empLng ?? 0;
    final mobileDigits = mobileNo.replaceAll(RegExp(r'\D'), '');
    final resolvedMobileNo = mobileDigits.isNotEmpty
        ? mobileDigits
        : (profile.mobileNo ?? '').replaceAll(RegExp(r'\D'), '');

    final body = <String, dynamic>{
      'firstName': firstName.trim(),
      'middleName': '',
      'lastName': lastName.trim(),
      'gender': genderCode,
      'address': address.trim(),
      'city': city.trim(),
      'stateCode': profile.stateCode ?? 1,
      'pin': pin.trim(),
      'mobileNo': resolvedMobileNo,
      'emercontactNo': profile.emerContactNo,
      'phoneNo': null,
      'emailId': emailId.trim(),
      'employeeId': profile.employeeId ?? '',
      'special_Needs': 1,
      'locCode': profile.locCode ?? 1,
      'depCode': depCode ?? profile.depCode ?? '',
      'proCode': proCode ?? profile.proCode ?? '',
      'lobCode': lobCode ?? profile.lobCode ?? '',
      'supId': null,
      'supEmployeeId': null,
      'spoc': null,
      'spocEmployeeId': null,
      'empTypeId': 1,
      'emp_Lat': lat,
      'emp_Lng': lng,
      'nodal_Pick': profile.nodalPick,
      'nodal_Drop': profile.nodalDrop,
      'geocodeId': profile.geocodeId,
    };

    debugPrint('[PROFILE_REPO] updateUserProfile → PUT /Users/$userId');
    debugPrint(
      '[PROFILE_REPO] updateUserProfile REQUEST body:\n'
      '${const JsonEncoder.withIndent('  ').convert(body)}',
    );

    final response = await _apiClient.dio.put<dynamic>(
      '/Users/$userId',
      data: body,
    );

    debugPrint(
      '[PROFILE_REPO] updateUserProfile ← status=${response.statusCode}',
    );
    debugPrint(
      '[PROFILE_REPO] updateUserProfile RESPONSE body: ${_formatLogJson(response.data)}',
    );
  }

  /// `POST /AddressChanges` via [http] package (not Dio).
  ///
  /// [address], [city], [state], [pin] and map coordinates come from the edit
  /// dialog; all other fields are taken from [profile] (fetch profile API).
  Future<AddressChangeResponse> submitAddressChange({
    required UserProfileResponse profile,
    required String address,
    required String city,
    required String state,
    required String pin,
    double? empLat,
    double? empLng,
  }) async {
    final body = useStaticAddressChangeTestPayload
        ? _staticAddressChangeTestBody()
        : _buildAddressChangeBody(
            profile: profile,
            address: address,
            city: city,
            state: state,
            pin: pin,
            empLat: empLat,
            empLng: empLng,
          );

    if (useStaticAddressChangeTestPayload) {
      debugPrint(
        '[PROFILE_REPO] submitAddressChange → using STATIC test payload',
      );
    } else {
      debugPrint(
        '[PROFILE_REPO] submitAddressChange → profile + dialog fields',
      );
      debugPrint(
        '[PROFILE_REPO] profile → empId=${profile.empId} locCode=${profile.locCode} '
        'stateCode=${profile.stateCode} mobileNo=${profile.mobileNo}',
      );
      debugPrint(
        '[PROFILE_REPO] dialog → city=$city state=$state pin=$pin '
        'lat=$empLat lng=$empLng',
      );
    }

    debugPrint('[PROFILE_REPO] submitAddressChange → POST /AddressChanges');
    debugPrint(
      '[PROFILE_REPO] submitAddressChange REQUEST body:\n'
      '${const JsonEncoder.withIndent('  ').convert(body)}',
    );

    final response = await _apiClient.dio.post<dynamic>(
      '/AddressChanges',
      data: body,
    );

    debugPrint(
      '[PROFILE_REPO] submitAddressChange ← status=${response.statusCode}',
    );
    debugPrint(
      '[PROFILE_REPO] submitAddressChange RESPONSE body: '
      '${_formatLogJson(response.data)}',
    );

    final raw = response.data;
    Map<String, dynamic>? json;
    if (raw is Map<String, dynamic>) {
      json = raw;
    } else if (raw is Map) {
      json = Map<String, dynamic>.from(raw);
    }

    if (json == null) {
      throw Exception('Unexpected response format from address change API');
    }

    return AddressChangeResponse.fromJson(json);
  }

  /// Builds POST body: dialog supplies address/city/state/pin + lat/lng;
  /// everything else from [UserProfileResponse].
  static Map<String, dynamic> _buildAddressChangeBody({
    required UserProfileResponse profile,
    required String address,
    required String city,
    required String state,
    required String pin,
    double? empLat,
    double? empLng,
  }) {
    final empId = profile.empId;
    if (empId == null) {
      throw Exception('Employee ID not found in profile');
    }

    final lat = empLat ?? profile.empLat;
    final lng = empLng ?? profile.empLng;
    if (lat == null || lng == null) {
      throw Exception('Location coordinates are required');
    }

    final mobileDigits =
        (profile.mobileNo ?? '').replaceAll(RegExp(r'\D'), '');

    return _withoutNullValues(<String, dynamic>{
      // ── From fetch profile ──────────────────────────────────────────────
      'empID': empId,
      'locCode': profile.locCode,
      'stateCode': profile.stateCode,
      'mobileNo': mobileDigits.isNotEmpty ? mobileDigits : profile.mobileNo,
      'emerContactNo': profile.emerContactNo ?? '',
      if (profile.geocodeId != null) 'geocodeID': profile.geocodeId,
      if (profile.nodalPick != null && profile.nodalPick!.trim().isNotEmpty)
        'nodal_Pick': profile.nodalPick,
      if (profile.nodalDrop != null && profile.nodalDrop!.trim().isNotEmpty)
        'nodal_Drop': profile.nodalDrop,
      // ── From location dialog (user edit) ────────────────────────────────
      'city': city.trim(),
      'pin': pin.trim(),
      'state': state.trim(),
      'address': address.trim(),
      'emp_Lat': double.parse(lat.toStringAsFixed(6)),
      'emp_Lng': double.parse(lng.toStringAsFixed(6)),
    });
  }

  /// Fixed sample from API docs / Postman — used when
  /// [useStaticAddressChangeTestPayload] is `true`.
  static Map<String, dynamic> _staticAddressChangeTestBody() {
    return <String, dynamic>{
      'empID': 578,
      'locCode': 183,
      'City': 'Dwarka',
      'Pin': '110975',
      'State': 'Delhi',
      'stateCode': 2,
      'mobileNo': '9179419377',
      'emerContactNo': '',
      'emp_Lat': 29.577326,
      'emp_Lng': 70.048855,
      'Address':
          'Demo Address',
    };
  }

  static Map<String, dynamic> _withoutNullValues(
    Map<String, dynamic> source,
  ) {
    return Map<String, dynamic>.fromEntries(
      source.entries.where((e) => e.value != null),
    );
  }

  static String formatLogJson(dynamic data) => _formatLogJson(data);

  static String _formatLogJson(dynamic data) {
    if (data == null) return 'null';
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map || decoded is List) {
          return const JsonEncoder.withIndent('  ').convert(decoded);
        }
      } catch (_) {}
      return data;
    }
    try {
      if (data is Map || data is List) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
      return data.toString();
    } catch (_) {
      return data.toString();
    }
  }
}
