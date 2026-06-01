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
      messageId: (json['id'] ?? json['messageId']) as int?,
      tripId: json['tripId'] as int?,
      senderEmpId: (json['empId'] ?? json['senderEmpId']) as int?,
      senderName: json['senderName'] as String?,
      recipientEmpId: (json['recepientEmpId'] ?? json['recipientEmpId']) as int?,
      chatText: json['chatText'] as String?,
      sentAt: (json['date'] ?? json['sentAt']) != null
          ? DateTime.tryParse((json['date'] ?? json['sentAt']).toString())
          : null,
      isRead: (json['readStatus'] ?? json['isRead']) as bool?,
    );
  }

  bool isMine(int myEmpId) => senderEmpId == myEmpId;
}
