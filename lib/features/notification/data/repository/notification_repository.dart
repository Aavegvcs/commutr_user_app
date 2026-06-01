import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/notification/data/model/notification_model.dart';
import 'package:flutter/foundation.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<NotificationResponse> fetchNotifications({required String userId}) async {
    debugPrint('[NOTIF_REPO] → GET /UserApp/GetTransNotificationMessages?UserID=$userId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/UserApp/GetTransNotificationMessages',
        queryParameters: {'UserID': userId},
      );

      debugPrint('[NOTIF_REPO] ← status=${response.statusCode}');
      debugPrint('[NOTIF_REPO] ← raw=${response.data}');

      final raw = response.data;

      Map<String, dynamic>? payload;
      if (raw is Map<String, dynamic>) {
        payload = raw;
      } else if (raw is Map) {
        payload = Map<String, dynamic>.from(raw);
      } else if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
        payload = raw.first as Map<String, dynamic>;
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        payload = Map<String, dynamic>.from(raw.first as Map);
      }

      if (payload == null) {
        debugPrint('[NOTIF_REPO] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = NotificationResponse.fromJson(payload);
      debugPrint('[NOTIF_REPO] parsed → errorCode=${parsed.errorCode} count=${parsed.items.length}');

      return parsed;
    } catch (e, st) {
      debugPrint('[NOTIF_REPO] ✖ exception=$e');
      debugPrint('[NOTIF_REPO] ✖ stack=$st');
      rethrow;
    }
  }
}
