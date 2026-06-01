import 'dart:convert';

class NotificationItem {
  final String userId;
  final String textSubject;
  final String textMessage;
  final String sentOn;

  const NotificationItem({
    required this.userId,
    required this.textSubject,
    required this.textMessage,
    required this.sentOn,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      userId: json['UserID']?.toString() ?? '',
      textSubject: json['TextSubject']?.toString() ?? '',
      textMessage: json['TextMessage']?.toString() ?? '',
      sentOn: json['SentON']?.toString() ?? '',
    );
  }
}

class NotificationResponse {
  final int errorCode;
  final String dbResponse;
  final List<NotificationItem> items;

  const NotificationResponse({
    required this.errorCode,
    required this.dbResponse,
    required this.items,
  });

  bool get isSuccess => errorCode == 0;

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final resultStr = json['result']?.toString() ?? '[]';
    List<NotificationItem> items = [];
    try {
      final decoded = jsonDecode(resultStr);
      if (decoded is List) {
        items = decoded
            .whereType<Map<String, dynamic>>()
            .map(NotificationItem.fromJson)
            .toList();
      }
    } catch (_) {}

    return NotificationResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      items: items,
    );
  }
}
