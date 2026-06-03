class ChatMessage {
  final int? messageId;
  final int? tripId;
  final int? senderEmpId;
  final String? senderName;
  final int? recipientEmpId;
  final String? chatText;
  final DateTime? sentAt;
  final bool? isRead;

  const ChatMessage({
    this.messageId,
    this.tripId,
    this.senderEmpId,
    this.senderName,
    this.recipientEmpId,
    this.chatText,
    this.sentAt,
    this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: _int(json, ['Id', 'id', 'messageId', 'MessageId']),
      tripId: _int(json, ['TripId', 'tripId']),
      senderEmpId: _int(json, [
        'SenderEmpId',
        'senderEmpId',
        'EmpId',
        'empId',
      ]),
      senderName: _string(json, [
        'SenderName',
        'senderName',
        'EmpName',
        'empName',
        'UserName',
        'userName',
        'name',
        'Name',
      ]),
      recipientEmpId: _int(json, [
        'RecepientEmpId',
        'recepientEmpId',
        'RecipientEmpId',
        'recipientEmpId',
      ]),
      chatText: _string(json, ['ChatText', 'chatText']),
      sentAt: _parseDate(json),
      isRead: json['readStatus'] as bool? ?? json['isRead'] as bool?,
    );
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static DateTime? _parseDate(Map<String, dynamic> json) {
    final raw = json['Date'] ??
        json['date'] ??
        json['sentAt'] ??
        json['SentAt'] ??
        json['CreatedAt'] ??
        json['createdAt'] ??
        json['Timestamp'] ??
        json['timestamp'] ??
        json['MessageDate'] ??
        json['messageDate'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool isMine(int myEmpId) =>
      senderEmpId != null && senderEmpId != 0 && senderEmpId == myEmpId;
}
