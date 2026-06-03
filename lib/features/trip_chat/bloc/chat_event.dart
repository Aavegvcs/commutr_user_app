import 'package:equatable/equatable.dart';
import '../data/model/chat_message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatLoadMessages extends ChatEvent {
  final int tripId;
  final int myEmpId;
  final int otherEmpId;

  const ChatLoadMessages({
    required this.tripId,
    required this.myEmpId,
    required this.otherEmpId,
  });

  @override
  List<Object?> get props => [tripId, myEmpId, otherEmpId];
}

class ChatSendMessage extends ChatEvent {
  final int tripId;
  final int myEmpId;
  final int recipientEmpId;
  final String text;

  const ChatSendMessage({
    required this.tripId,
    required this.myEmpId,
    required this.recipientEmpId,
    required this.text,
  });

  @override
  List<Object?> get props => [tripId, myEmpId, recipientEmpId, text];
}

/// Fired by the SignalR service when a new message arrives.
class ChatMessageReceived extends ChatEvent {
  final ChatMessage message;

  const ChatMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class ChatMarkRead extends ChatEvent {
  final int tripId;
  final int senderEmpId;
  final int recipientEmpId;

  const ChatMarkRead({
    required this.tripId,
    required this.senderEmpId,
    required this.recipientEmpId,
  });

  @override
  List<Object?> get props => [tripId, senderEmpId, recipientEmpId];
}

class ChatRefreshMessages extends ChatEvent {
  final int tripId;
  final int myEmpId;
  final int otherEmpId;

  const ChatRefreshMessages({
    required this.tripId,
    required this.myEmpId,
    required this.otherEmpId,
  });

  @override
  List<Object?> get props => [tripId, myEmpId, otherEmpId];
}
