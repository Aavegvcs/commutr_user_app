import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/storage/auth_local_storage.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../data/model/chat_message.dart';
import '../service/chat_signalr_service.dart';

/// [tripId]       — the active trip's ID
/// [myEmpId]      — the logged-in user's employee ID
/// [otherEmpId]   — the other participant's employee ID (driver or fellow rider)
/// [otherName]    — display name shown in the app bar
/// [participants] — subtitle shown under the title (e.g. "Marcus, Sarah, David +2")
class TripGroupChatScreen extends StatelessWidget {
  final int tripId;
  final int myEmpId;
  final int otherEmpId;
  final String otherName;
  final String participants;

  const TripGroupChatScreen({
    super.key,
    required this.tripId,
    required this.myEmpId,
    required this.otherEmpId,
    required this.otherName,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    // Each chat screen gets its own SignalR connection + BLoC
    final signalR = sl<ChatSignalRService>();
    final accessToken = sl<AuthLocalStorage>().getAccessToken() ?? '';

    return BlocProvider(
      create: (_) {
        final bloc = ChatBloc(
          repository: sl(),
          signalRService: signalR,
        );

        // Connect SignalR then load history
        signalR
            .connect(
              hubUrl: ApiConstants.chatHubUrl,
              accessToken: accessToken,
            )
            .then((_) => bloc.add(ChatLoadMessages(
                  tripId: tripId,
                  myEmpId: myEmpId,
                  otherEmpId: otherEmpId,
                )))
            .catchError((_) => bloc.add(ChatLoadMessages(
                  tripId: tripId,
                  myEmpId: myEmpId,
                  otherEmpId: otherEmpId,
                )));

        return bloc;
      },
      child: _ChatView(
        tripId: tripId,
        myEmpId: myEmpId,
        otherEmpId: otherEmpId,
        otherName: otherName,
        participants: participants,
        signalR: signalR,
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  final int tripId;
  final int myEmpId;
  final int otherEmpId;
  final String otherName;
  final String participants;
  final ChatSignalRService signalR;

  const _ChatView({
    required this.tripId,
    required this.myEmpId,
    required this.otherEmpId,
    required this.otherName,
    required this.participants,
    required this.signalR,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    widget.signalR.disconnect();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatSendMessage(
          tripId: widget.tripId,
          myEmpId: widget.myEmpId,
          recipientEmpId: widget.otherEmpId,
          text: text,
        ));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A5C38)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.otherName,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A5C38),
            ),
          ),
          Text(
            widget.participants,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatLoaded) _scrollToBottom();
      },
      builder: (context, state) {
        if (state is ChatLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A5C38)),
          );
        }
        if (state is ChatError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red, fontFamily: 'Manrope'),
            ),
          );
        }
        if (state is ChatLoaded) {
          if (state.messages.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet. Say hello!',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Color(0xFF8E8E93),
                ),
              ),
            );
          }
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: state.messages.length,
            itemBuilder: (context, index) {
              final msg = state.messages[index];
              final prev =
                  index > 0 ? state.messages[index - 1] : null;
              final showLabel = prev == null ||
                  prev.senderEmpId != msg.senderEmpId;
              return _MessageBubble(
                message: msg,
                isMine: msg.isMine(widget.myEmpId),
                showSenderLabel: showLabel,
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(
                    fontFamily: 'Manrope',
                    color: Color(0xFFAEAEB2),
                    fontSize: 15,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final sending =
                  state is ChatLoaded && state.isSending;
              return GestureDetector(
                onTap: sending ? null : () => _send(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sending
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF1A5C38),
                    shape: BoxShape.circle,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSenderLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine && showSenderLabel && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                message.senderName!.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFF1A5C38)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.chatText ?? '',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      color: isMine ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
              if (isMine) const SizedBox(width: 4),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isMine ? 0 : 4,
              right: isMine ? 4 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.sentAt),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead == true
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: message.isRead == true
                        ? const Color(0xFF1A5C38)
                        : const Color(0xFF8E8E93),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$m $period';
  }
}
