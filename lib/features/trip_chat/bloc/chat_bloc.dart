import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/chat_message.dart';
import '../data/model/chat_message_request.dart';
import '../data/repository/chat_repository.dart';
import '../service/chat_signalr_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  final ChatSignalRService _signalR;

  ChatBloc({
    required ChatRepository repository,
    required ChatSignalRService signalRService,
  })  : _repository = repository,
        _signalR = signalRService,
        super(const ChatInitial()) {
    on<ChatLoadMessages>(_onLoad);
    on<ChatSendMessage>(_onSend);
    on<ChatMessageReceived>(_onReceived);
    on<ChatMarkRead>(_onMarkRead);

    _signalR.addListener(_onSignalRMessage);
  }

  void _onSignalRMessage(ChatMessage msg) {
    add(ChatMessageReceived(msg));
  }

  Future<void> _onLoad(
    ChatLoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    final messages = await _repository.getMessages(
      tripId: event.tripId,
      empId1: event.myEmpId,
      empId2: event.otherEmpId,
    );
    emit(ChatLoaded(messages: messages));

    // Mark messages sent by the other party as read
    add(ChatMarkRead(
      tripId: event.tripId,
      senderEmpId: event.otherEmpId,
      recipientEmpId: event.myEmpId,
    ));
  }

  Future<void> _onSend(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    final current = state;
    if (current is! ChatLoaded) return;

    // Optimistically show the message immediately
    final optimistic = ChatMessage(
      tripId: event.tripId,
      senderEmpId: event.myEmpId,
      recipientEmpId: event.recipientEmpId,
      chatText: event.text,
      sentAt: DateTime.now(),
      isRead: false,
    );

    emit(current.copyWith(
      messages: [...current.messages, optimistic],
      isSending: true,
    ));

    final request = ChatMessageRequest(
      tripId: event.tripId,
      empId: event.myEmpId,
      chatText: event.text,
      recepientEmpId: event.recipientEmpId,
    );

    await _repository.sendMessage(request);
    emit(current.copyWith(
      messages: [...current.messages, optimistic],
      isSending: false,
    ));
  }

  void _onReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    final current = state;
    if (current is! ChatLoaded) return;
    emit(current.copyWith(
      messages: [...current.messages, event.message],
    ));
  }

  Future<void> _onMarkRead(
    ChatMarkRead event,
    Emitter<ChatState> emit,
  ) async {
    await _repository.markMessagesRead(
      tripId: event.tripId,
      senderEmpId: event.senderEmpId,
      recipientEmpId: event.recipientEmpId,
    );
  }

  @override
  Future<void> close() {
    _signalR.removeListener(_onSignalRMessage);
    return super.close();
  }
}
