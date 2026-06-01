class ChatMessageRequest {
  final int tripId;
  final int empId;
  final String chatText;
  final int recepientEmpId;

  const ChatMessageRequest({
    required this.tripId,
    required this.empId,
    required this.chatText,
    required this.recepientEmpId,
  });

  Map<String, dynamic> toJson() => {
        'TripId': tripId,
        'EmpId': empId,
        'ChatText': chatText,
        'RecepientEmpId': recepientEmpId,
      };
}
