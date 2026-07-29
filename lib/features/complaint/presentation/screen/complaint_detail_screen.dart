import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../bloc/complaint_bloc.dart';
import '../../bloc/complaint_event.dart';
import '../../bloc/complaint_state.dart';
import '../../data/model/complaint_response.dart';

const _kGreen = Color(0xFF006C49);
const _kBg = Color(0xFFF5F5F4);
const _kMuted = Color(0xFF9AA0A6);
const _kTrackIdle = Color(0xFFD9DDE1);

/// Refresh FAB background — the feature's informational blue, kept distinct
/// from the primary green used for the app bar and main actions.
const _kFabBlue = Color(0xFF2563EB);

class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.empId,
    required this.complaintId,
    required this.complaintType,
  });

  final int empId;
  final int complaintId;
  final String complaintType;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ComplaintBloc>(
      create: (_) => sl<ComplaintBloc>()
        ..add(FetchComplaintDetail(empId: empId, complaintId: complaintId)),
      child: _ComplaintDetailView(
        empId: empId,
        complaintId: complaintId,
        complaintType: complaintType,
      ),
    );
  }
}

class _ComplaintDetailView extends StatefulWidget {
  const _ComplaintDetailView({
    required this.empId,
    required this.complaintId,
    required this.complaintType,
  });

  final int empId;
  final int complaintId;
  final String complaintType;

  @override
  State<_ComplaintDetailView> createState() => _ComplaintDetailViewState();
}

class _ComplaintDetailViewState extends State<_ComplaintDetailView> {
  /// Last successfully loaded detail, kept so a refresh doesn't blank the screen.
  ComplaintDetailItem? _lastDetail;

  void _refresh(BuildContext context) {
    context.read<ComplaintBloc>().add(
          FetchComplaintDetail(
            empId: widget.empId,
            complaintId: widget.complaintId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kGreen, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Complaint Detail',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kGreen,
          ),
        ),
      ),
      floatingActionButton: BlocBuilder<ComplaintBloc, ComplaintState>(
        builder: (context, state) => _RefreshFab(
          busy: state is ComplaintDetailLoading,
          onPressed: () => _refresh(context),
        ),
      ),
      body: BlocConsumer<ComplaintBloc, ComplaintState>(
        listener: (context, state) {
          if (state is ComplaintDetailError) {
            AppSnackbar.error(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is ComplaintDetailLoaded) {
            _lastDetail = state.detail;
          }
          // Only blank the screen on the very first load; a refresh keeps the
          // current detail visible while the FAB spins.
          if (state is ComplaintDetailLoading && _lastDetail == null) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9AA0A6)),
                strokeWidth: 3,
              ),
            );
          }
          if (state is ComplaintDetailError && _lastDetail == null) {
            return _ErrorBody(message: state.message);
          }
          final detail = _lastDetail;
          if (detail == null) return const SizedBox.shrink();
          return RefreshIndicator(
            color: _kGreen,
            onRefresh: () async => _refresh(context),
            child: _DetailBody(detail: detail),
          );
        },
      ),
    );
  }
}

/// Circular refresh button shared by the complaint screens. Shows a spinner
/// while its fetch is in flight and ignores taps until it completes.
///
/// Deliberately not green — refresh is a secondary action, so it uses the
/// feature's informational blue instead of competing with the primary green.
class _RefreshFab extends StatelessWidget {
  const _RefreshFab({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: busy ? null : onPressed,
      backgroundColor: _kFabBlue,
      foregroundColor: Colors.white,
      elevation: 2,
      tooltip: 'Refresh',
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.refresh, size: 26),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Color(0xFFBA1A1A)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in the chat-style "Updates" thread.
class _Update {
  const _Update({
    required this.text,
    required this.time,
    required this.author,
    required this.fromUser,
  });

  final String text;
  final String time;

  /// Who posted the update. Empty when the API didn't supply a name.
  final String author;

  /// Employee messages sit on the left; transport-desk replies sit on the
  /// right.
  final bool fromUser;
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ComplaintDetailItem detail;

  String get _statusLabel =>
      detail.status.isNotEmpty ? detail.status : 'Pending';

  Color get _statusColor {
    switch (_statusLabel.trim().toLowerCase()) {
      case 'complete':
      case 'resolved':
      case 'closed':
        return const Color(0xFF2563EB);
      case 'pending':
      case 'open':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF888888);
    }
  }

  Color get _statusBg {
    switch (_statusLabel.trim().toLowerCase()) {
      case 'complete':
      case 'resolved':
      case 'closed':
        return const Color(0xFFEFF6FF);
      case 'pending':
      case 'open':
        return const Color(0xFFFFF7E6);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  /// Replies from the transport management team — any entry not posted by the
  /// employee.
  Iterable<ComplaintThreadItem> get _teamReplies => detail.threads
      .where((t) => !t.isFromEmployee && t.message.trim().isNotEmpty);

  /// The complaint is only finished once the API reports status `Complete`.
  bool get _isComplete => _statusLabel.trim().toLowerCase() == 'complete';

  /// 0 = raised only, 1 = in review, 2 = resolved.
  int get _activeStep {
    // "Resolved" is reached only on status `Complete` — no other status, and no
    // amount of replies, advances the timeline to the final step.
    if (_isComplete) return 2;
    // Any reply from the transport team means the complaint is being looked at.
    // `TransportReply` can echo the status (e.g. "Pending"), so it isn't used.
    if (_teamReplies.isNotEmpty) return 1;
    return 0;
  }

  bool get _isResolved => _activeStep == 2;

  /// `24-Jul-2026 13:10` -> `24 Jul, 13:10`
  String _shortDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '-';
    final parts = value.split(RegExp(r'\s+'));
    final datePart = parts.first.split('-');
    final time = parts.length > 1 ? parts[1] : '';
    if (datePart.length < 2) return value;
    final day = datePart[0];
    final month = datePart[1];
    return time.isEmpty ? '$day $month' : '$day $month, $time';
  }

  List<_Update> get _updates {
    // Prefer the real conversation thread from the API.
    if (detail.threads.isNotEmpty) {
      return detail.threads
          .where((t) => t.message.trim().isNotEmpty)
          .map(
            (t) => _Update(
              text: t.message.trim(),
              time: _shortDate(t.threadOn),
              author: t.threadBy,
              fromUser: t.isFromEmployee,
            ),
          )
          .toList(growable: false);
    }

    // Fallback for responses that predate ComplaintThreads.
    final items = <_Update>[];
    final message = detail.complainMessage.trim();
    if (message.isNotEmpty) {
      items.add(
        _Update(
          text: message,
          time: _shortDate(detail.complainDate),
          author: '',
          fromUser: true,
        ),
      );
    }
    final reply = detail.transportReply.trim();
    if (reply.isNotEmpty && reply.toLowerCase() != _statusLabel.toLowerCase()) {
      items.add(
        _Update(
          text: reply,
          time: _shortDate(detail.complainDate),
          author: '',
          fromUser: false,
        ),
      );
    }
    return items;
  }

  /// Timestamp of the transport team's first reply, used for "In Review".
  String get _reviewTime {
    final first = _teamReplies.isNotEmpty ? _teamReplies.first : null;
    return _shortDate(first?.threadOn ?? detail.complainDate);
  }

  /// Timestamp of the last update, used for the "Resolved" step.
  String get _resolvedTime => _shortDate(
        detail.threads.isNotEmpty
            ? detail.threads.last.threadOn
            : detail.complainDate,
      );

  /// Timestamp of the message the user raised, used for the "Raised" step.
  String get _raisedTime {
    final own = detail.threads.where(
      (t) => t.isFromEmployee && t.message.trim().isNotEmpty,
    );
    return _shortDate(
      own.isNotEmpty ? own.first.threadOn : detail.complainDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final updates = _updates;

    return SingleChildScrollView(
      // Always scrollable so pull-to-refresh works on short content too.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ───────────────────────────────────────────────
          _Card(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            leftAccent: true,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.complaintType.isNotEmpty
                            ? detail.complaintType
                            : '—',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'ID: ${detail.complaintId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF737785),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            '  •  ',
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                          const Icon(
                            Icons.schedule,
                            size: 13,
                            color: _kMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              detail.complainDate.isNotEmpty
                                  ? detail.complainDate
                                  : '—',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF737785),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tracker + Updates + composer ──────────────────────────────
          _Card(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusTracker(
                  activeStep: _activeStep,
                  raisedTime: _raisedTime,
                  reviewTime: _activeStep >= 1 ? _reviewTime : '-',
                  resolvedTime: _isResolved ? _resolvedTime : '-',
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFECEEF0)),
                const SizedBox(height: 16),
                const Text(
                  'Updates',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                if (updates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No updates yet.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9AA0A6)),
                    ),
                  )
                else
                  for (final update in updates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UpdateBubble(update: update),
                    ),
                const SizedBox(height: 6),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    required this.padding,
    this.leftAccent = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool leftAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // border: leftAccent
        //     ? const Border(left: BorderSide(color: _kGreen, width: 4))
        //     : Border.all(color: const Color(0xFFEDEFF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({
    required this.activeStep,
    required this.raisedTime,
    required this.reviewTime,
    required this.resolvedTime,
  });

  /// 0 = raised, 1 = in review, 2 = resolved.
  final int activeStep;
  final String raisedTime;
  final String reviewTime;
  final String resolvedTime;

  @override
  Widget build(BuildContext context) {
    const labels = ['Raised', 'In Review', 'Resolved'];
    final times = [raisedTime, reviewTime, resolvedTime];

    return Column(
      children: [
        // Dots and connectors.
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= activeStep ? _kGreen : _kTrackIdle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              _StepDot(
                done: i < activeStep,
                current: i == activeStep,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Labels + timestamps, aligned under their dots.
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Column(
                  crossAxisAlignment: i == 0
                      ? CrossAxisAlignment.start
                      : (i == 1
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.end),
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            i == activeStep ? FontWeight.w700 : FontWeight.w600,
                        color: i <= activeStep
                            ? (i == activeStep
                                ? _kGreen
                                : const Color(0xFF1A1A1A))
                            : const Color(0xFF9AA0A6),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      times[i],
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9AA0A6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done, required this.current});

  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 17, color: Colors.white),
      );
    }
    if (current) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _kGreen, width: 3),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _kTrackIdle, width: 3),
      ),
    );
  }
}

class _UpdateBubble extends StatelessWidget {
  const _UpdateBubble({required this.update});

  final _Update update;

  @override
  Widget build(BuildContext context) {
    final fromUser = update.fromUser;
    return Row(
      // The user's own messages sit on the right, replies from the transport
      // team on the left.
      mainAxisAlignment:
          fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.68,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  fromUser ? const Color(0xFFEFF1F4) : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(fromUser ? 12 : 2),
                bottomRight: Radius.circular(fromUser ? 2 : 12),
              ),
            ),
            child: Column(
              crossAxisAlignment: fromUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  update.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  update.author.isNotEmpty
                      ? '${update.author} • ${update.time}'
                      : update.time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA0A6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({required this.enabled});

  final bool enabled;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Reply API is not wired yet; keep the field responsive without losing text.
    AppSnackbar.error(
      context,
      'Replying to a complaint is not available yet.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              controller: _controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                hintText:
                    enabled ? 'Type a message...' : 'This complaint is closed',
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9AA0A6),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: enabled && _hasText ? _send : null,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: enabled && _hasText ? _kGreen : const Color(0xFFC9CDD2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
