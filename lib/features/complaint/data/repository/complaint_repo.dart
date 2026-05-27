import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/complaint_response.dart';

class ComplaintRepository {
  final ApiClient _apiClient;

  const ComplaintRepository(this._apiClient);

  Future<List<ComplaintItem>> getComplaints({required int empId}) async {
    debugPrint(
      '[COMPLAINT_REPO] getComplaints → POST /UserApp/GetUserComplaints empId=$empId',
    );

    final response = await _apiClient.dio.post<dynamic>(
      '/UserApp/GetUserComplaints',
      data: {'Empid': empId},
    );

    debugPrint(
      '[COMPLAINT_REPO] ← status=${response.statusCode} '
      'dataType=${response.data.runtimeType}',
    );

    final raw = response.data;
    Map<String, dynamic>? root;

    if (raw is Map<String, dynamic>) {
      root = raw;
    } else if (raw is Map) {
      root = Map<String, dynamic>.from(raw);
    }

    if (root == null) {
      debugPrint('[COMPLAINT_REPO] ✖ unrecognized response shape');
      return const [];
    }

    final apiResponse = ComplaintListApiResponse.fromJson(root);
    if (!apiResponse.isSuccess) return const [];

    final envelope = apiResponse.firstEnvelope;
    if (envelope == null || !envelope.isSuccess) return const [];

    return envelope.complaints;
  }

  Future<List<ComplaintLookupItem>> getComplaintLookup() async {
    debugPrint(
      '[COMPLAINT_REPO] getComplaintLookup → GET /UserApp/ComplaintLookup',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/ComplaintLookup',
    );

    debugPrint(
      '[COMPLAINT_REPO] ← status=${response.statusCode} '
      'dataType=${response.data.runtimeType}',
    );

    final raw = response.data;
    List<dynamic>? list;

    if (raw is List) {
      list = raw;
    }

    if (list == null || list.isEmpty) return const [];

    final first = list.first;
    Map<String, dynamic>? envelope;
    if (first is Map<String, dynamic>) {
      envelope = first;
    } else if (first is Map) {
      envelope = Map<String, dynamic>.from(first);
    }

    if (envelope == null) return const [];

    final parsed = ComplaintLookupApiResponse.fromJson(envelope);
    if (!parsed.isSuccess) return const [];

    return parsed.items;
  }

  Future<ComplaintDetailItem?> getComplaintDetail({
    required int empId,
    required int complaintId,
  }) async {
    debugPrint(
      '[COMPLAINT_REPO] getComplaintDetail → GET /UserApp/ComplaintDetail empId=$empId complaintId=$complaintId',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/ComplaintDetail',
      queryParameters: {'EmpID': empId, 'ComplaintId': complaintId},
    );

    final raw = response.data;
    List<dynamic>? list;
    if (raw is List) list = raw;
    if (list == null || list.isEmpty) return null;

    final first = list.first;
    Map<String, dynamic>? envelope;
    if (first is Map<String, dynamic>) {
      envelope = first;
    } else if (first is Map) {
      envelope = Map<String, dynamic>.from(first);
    }
    if (envelope == null) return null;

    final parsed = ComplaintDetailApiResponse.fromJson(envelope);
    debugPrint('[COMPLAINT_REPO] getComplaintDetail ✓ items=${parsed.items.length}');
    return parsed.items.isNotEmpty ? parsed.items.first : null;
  }

  Future<List<ComplaintListItem>> getComplaintList({
    required int empId,
    required String fromDate,
    required String toDate,
  }) async {
    debugPrint(
      '[COMPLAINT_REPO] getComplaintList → GET /UserApp/ComplaintList empId=$empId fromDate=$fromDate toDate=$toDate',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/ComplaintList',
      queryParameters: {
        'EmpID': empId,
        'FromDate': fromDate,
        'ToDate': toDate,
        'ComplaintId': 0,
      },
    );

    final raw = response.data;
    List<dynamic>? list;
    if (raw is List) list = raw;

    if (list == null || list.isEmpty) return const [];

    final first = list.first;
    Map<String, dynamic>? envelope;
    if (first is Map<String, dynamic>) {
      envelope = first;
    } else if (first is Map) {
      envelope = Map<String, dynamic>.from(first);
    }
    if (envelope == null) return const [];

    final parsed = ComplaintListApiV2Response.fromJson(envelope);
    debugPrint('[COMPLAINT_REPO] getComplaintList ✓ items=${parsed.items.length}');
    return parsed.items;
  }

  Future<void> raiseComplaint({
    required int empId,
    required int tripType,
    required String tripDate,
    required int complaintType,
    required String complaintDetail,
  }) async {
    debugPrint(
      '[COMPLAINT_REPO] raiseComplaint → POST /UserApp/CreateComplaint '
      'empId=$empId tripType=$tripType tripDate=$tripDate',
    );

    final response = await _apiClient.dio.post<dynamic>(
      '/UserApp/CreateComplaint',
      data: {
        'EmpId': empId,
        'TripType': tripType,
        'TripDate': tripDate,
        'ComplaintType': complaintType,
        'ComplainMessage': complaintDetail,
      },
    );

    final raw = response.data;

    Map<String, dynamic>? root;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        root = first;
      } else if (first is Map) {
        root = Map<String, dynamic>.from(first);
      }
    } else if (raw is Map<String, dynamic>) {
      root = raw;
    } else if (raw is Map) {
      root = Map<String, dynamic>.from(raw);
    }

    debugPrint('[COMPLAINT_REPO] CreateComplaint raw=$raw parsed root=$root');

    if (root == null) {
      debugPrint('[COMPLAINT_REPO] ✖ unrecognized response shape, treating as success (HTTP 2xx)');
      return;
    }

    final errorCode = (root['errorCode'] as num?)?.toInt() ?? 0;
    final dbResponse = root['dB_Response']?.toString() ?? '';
    debugPrint('[COMPLAINT_REPO] errorCode=$errorCode dB_Response=$dbResponse');

    if (errorCode != 0) {
      throw Exception(dbResponse.isNotEmpty ? dbResponse : 'Failed to submit complaint.');
    }
  }
}
