import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:flutter/material.dart';

class TripProgressBottomSheet extends StatelessWidget {
  final CabTrackingData tracking;
  final String? currentUserName;

  const TripProgressBottomSheet({
    super.key,
    required this.tracking,
    this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final picked = tracking.currentSequenceOrder;
    final total = tracking.passengerCount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 22, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              const Text(
                'Trip Progress',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Passengers Picked ($picked/$total)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF004D32),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 16),
          _PassengerTimeline(
            tracking: tracking,
            currentUserName: currentUserName,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Stack(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 24,
                    color: Color(0xFF1A5C38),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              title: const Text(
                'Need Cab Update?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Chat with your group',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.black45, size: 22),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerTimeline extends StatelessWidget {
  final CabTrackingData tracking;
  final String? currentUserName;

  const _PassengerTimeline({
    required this.tracking,
    this.currentUserName,
  });

  static const _avatarColors = [
    Color(0xFF1A3A5C),
    Color(0xFF6B8DD6),
    Color(0xFF8B6B4A),
    Color(0xFF4A8B6B),
    Color(0xFF7A5C9E),
  ];

  @override
  Widget build(BuildContext context) {
    final orderedPassengers =
        tracking.passengersForDisplay(currentUserName);
    final stops = <_PassengerStop>[];

    for (var i = 0; i < orderedPassengers.length; i++) {
      final p = orderedPassengers[i];
      final name = p.empName?.trim() ?? 'Passenger';
      final isYou = _isCurrentUser(name);
      stops.add(
        _PassengerStop(
          sequenceNumber: i + 1,
          initials: _initials(name),
          name: isYou ? '$name (You)' : name,
          time: _formatPickTime(p.pickTime),
          avatarColor: _avatarColors[i % _avatarColors.length],
          isPickedUp: tracking.isPassengerPickedUp(i),
          isCurrentInSequence: tracking.isPassengerCurrentInSequence(i),
          isYou: isYou,
        ),
      );
    }

    stops.add(
      _PassengerStop(
        sequenceNumber: orderedPassengers.length + 1,
        initials: '',
        name: 'Office',
        time: '—',
        avatarColor: const Color(0xFF1A5C38),
        isPickedUp: false,
        isYou: false,
        isDestination: true,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (stops.length > 1)
          Positioned(
            left: (_TimelineRow.timelineColumnWidth - 2) / 2,
            top: _TimelineRow.avatarVisualHeight(stops.first),
            bottom: _TimelineRow.avatarVisualHeight(stops.last),
            child: const SizedBox(
              width: 2,
              child: ColoredBox(color: _TimelineRow.connectorColor),
            ),
          ),
        Column(
          children: List.generate(stops.length, (i) {
            final stop = stops[i];
            final isLast = i == stops.length - 1;
            return _TimelineRow(stop: stop, isLast: isLast);
          }),
        ),
      ],
    );
  }

  bool _isCurrentUser(String passengerName) {
    final current = currentUserName?.trim().toLowerCase();
    if (current == null || current.isEmpty) return false;
    return passengerName.trim().toLowerCase() == current;
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _formatPickTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final trimmed = raw.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(trimmed);
    if (match == null) return trimmed;
    final hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = match.group(2)!;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }
}

class _TimelineRow extends StatelessWidget {
  final _PassengerStop stop;
  final bool isLast;

  const _TimelineRow({required this.stop, required this.isLast});

  static const timelineColumnWidth = 38.0;
  static const connectorColor = Color(0xFFB5D5C5);
  static const _passengerAvatarSize = 42.0;
  static const _destinationAvatarSize = 42.0;
  static const _currentBorderWidth = 3.0;

  static double avatarVisualHeight(_PassengerStop stop) {
    if (stop.isDestination) return _destinationAvatarSize;
    final border =
        stop.isCurrentInSequence ? _currentBorderWidth * 2 : 0.0;
    return _passengerAvatarSize + border;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: timelineColumnWidth,
          child: Center(child: _buildAvatar()),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : 16,
                top: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (!stop.isDestination && stop.sequenceNumber > 0)
                          Container(
                            width: 0,
                            height: 0,
                            // margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            // decoration: BoxDecoration(
                            //   color: stop.isCurrentInSequence
                            //       ? const Color(0xFF1A5C38)
                            //       : const Color(0xFFE8E8E8),
                            //   shape: BoxShape.circle,
                            // ),
                            child: Text(
                              '',
                              // '${stop.sequenceNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: stop.isCurrentInSequence
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            stop.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: stop.isCurrentInSequence
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: stop.isPickedUp ||
                                      stop.isCurrentInSequence ||
                                      stop.isDestination
                                  ? Colors.black87
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stop.time,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: stop.isDestination
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: stop.isDestination
                                ? const Color(0xFF1A5C38)
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (stop.isDestination)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            'Expected Arrival',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A5C38),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (stop.isDestination) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: stop.avatarColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.corporate_fare,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    return Container(
      decoration: stop.isCurrentInSequence
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1A5C38),
                width: 3,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: 26,
        backgroundColor: stop.avatarColor,
        child: Text(
          stop.initials,
          style: TextStyle(
            color: stop.isPickedUp || stop.isCurrentInSequence
                ? Colors.white
                : Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PassengerStop {
  final int sequenceNumber;
  final String initials;
  final String name;
  final String time;
  final Color avatarColor;
  final bool isPickedUp;
  final bool isCurrentInSequence;
  final bool isYou;
  final bool isDestination;

  const _PassengerStop({
    this.sequenceNumber = 0,
    required this.initials,
    required this.name,
    required this.time,
    required this.avatarColor,
    required this.isPickedUp,
    this.isCurrentInSequence = false,
    required this.isYou,
    this.isDestination = false,
  });
}
