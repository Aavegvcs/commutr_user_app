import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/share_cab/data/model/share_cab_response.dart';
import 'package:flutter/foundation.dart';

class ShareCabRepository {
  final ApiClient _apiClient;

  ShareCabRepository(this._apiClient);

  Future<ShareCabResponse> shareCabToFamily({
    required int empId,
    required int tripId,
    required String name,
    required String userMobileNo,
    required String recepientMobileNo,
  }) async {
    debugPrint(
      '[SHARE_CAB] → POST /UserApp/SharingCabToFamily '
      'empId=$empId tripId=$tripId recipient=$recepientMobileNo',
    );

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/UserApp/SharingCabToFamily',
        data: {
          'Empid': empId,
          'TripId': tripId,
          'Name': name,
          'UserMobileNo': userMobileNo,
          'RecepientMobileNo': recepientMobileNo,
        },
      );

      debugPrint('[SHARE_CAB] ← status=${response.statusCode} data=${response.data}');

      final json = response.data as Map<String, dynamic>;
      return ShareCabResponse.fromJson(json);
    } catch (e, st) {
      debugPrint('[SHARE_CAB] ✖ exception=$e');
      debugPrint('[SHARE_CAB] ✖ stack=$st');
      rethrow;
    }
  }
}
