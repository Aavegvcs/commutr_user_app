import 'package:flutter/material.dart';

class TripProgressBottomSheet extends StatelessWidget {
  const TripProgressBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
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
          // Drag handle
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

          // Header row
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

          // Title
          const Text(
            'Passengers Picked (2/3)',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A5C38),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 16),

          // Passenger list with timeline
          _PassengerTimeline(),

          const SizedBox(height: 20),

          // Chat CTA
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 30,
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
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: const Text(
                'Chat with your group',
                style: TextStyle(color: Colors.black54, fontSize: 13),
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
  final List<_PassengerStop> stops = const [
    _PassengerStop(
      initials: 'AL',
      name: 'Alex L. (You)',
      time: '10:25 AM',
      avatarColor: Color(0xFF1A3A5C),
      isPickedUp: true,
      isYou: true,
    ),
    _PassengerStop(
      initials: 'SM',
      name: 'Sarah M.',
      time: '10:25 AM',
      avatarColor: Color(0xFF6B8DD6),
      isPickedUp: true,
      isYou: false,
    ),
    _PassengerStop(
      initials: 'RJ',
      name: 'Ryan J.',
      time: '10:25 AM',
      avatarColor: Color(0xFFCCCCCC),
      isPickedUp: false,
      isYou: false,
    ),
    _PassengerStop(
      initials: '',
      name: 'Office',
      time: '01:00 PM',
      avatarColor: Color(0xFF1A5C38),
      isPickedUp: false,
      isYou: false,
      isDestination: true,
    ),
  ];

  const _PassengerTimeline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stops.length, (i) {
        final stop = stops[i];
        final isLast = i == stops.length - 1;
        return _TimelineRow(stop: stop, isLast: isLast);
      }),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _PassengerStop stop;
  final bool isLast;

  const _TimelineRow({required this.stop, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar + vertical line column
          SizedBox(
            width: 64,
            child: Column(
              children: [
                // Avatar
                stop.isDestination
                    ? Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: stop.avatarColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                )
                    : CircleAvatar(
                  radius: 26,
                  backgroundColor: stop.avatarColor,
                  child: Text(
                    stop.initials,
                    style: TextStyle(
                      color: stop.isPickedUp
                          ? Colors.white
                          : Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFB5D5C5),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Name + time
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : 16,
                top: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: stop.isPickedUp || stop.isDestination
                          ? Colors.black87
                          : Colors.black54,
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
      ),
    );
  }
}

class _PassengerStop {
  final String initials;
  final String name;
  final String time;
  final Color avatarColor;
  final bool isPickedUp;
  final bool isYou;
  final bool isDestination;

  const _PassengerStop({
    required this.initials,
    required this.name,
    required this.time,
    required this.avatarColor,
    required this.isPickedUp,
    required this.isYou,
    this.isDestination = false,
  });
}