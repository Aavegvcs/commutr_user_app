import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/team_cab/bloc/team_cab_bloc.dart';
import 'package:commutr_main/features/team_cab/bloc/team_cab_event.dart';
import 'package:commutr_main/features/team_cab/bloc/team_cab_state.dart';
import 'package:commutr_main/features/team_cab/data/model/team_tracking_panel_response.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_event.dart';
import 'package:commutr_main/ride_tracking/ride_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TeamCabScreen extends StatelessWidget {
  const TeamCabScreen({super.key});

  static const Color _bg = Color(0xFFF5F5F4);
  static const Color _primary = Color(0xFF1A6B3C);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<RosterBloc>()..add(const FetchRosterUserDetails()),
        ),
        BlocProvider(create: (_) => sl<TeamCabBloc>()),
      ],
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text(
            'Team Cab',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primary,
              fontFamily: 'Manrope',
            ),
          ),
        ),
        body: const _TeamCabBody(),
      ),
    );
  }
}

/// Bridges the roster details (source of `empId`) into the team-cab fetch,
/// then renders the team-cab state. Owns the currently-selected filter date.
class _TeamCabBody extends StatefulWidget {
  const _TeamCabBody();

  @override
  State<_TeamCabBody> createState() => _TeamCabBodyState();
}

class _TeamCabBodyState extends State<_TeamCabBody> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  /// Returns the current `empId` if the roster is loaded, else null.
  int? _empId() {
    final r = context.read<RosterBloc>().state;
    return r is RosterLoaded ? r.details.empId : null;
  }

  void _fetch() {
    final empId = _empId();
    if (empId != null) {
      context
          .read<TeamCabBloc>()
          .add(FetchTeamCab(empId: empId, date: _selectedDate));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: TeamCabScreen._primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && !_isSameDate(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      _fetch();
    }
  }

  Future<void> _onRefresh() async {
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RosterBloc, RosterState>(
      listener: (context, state) {
        if (state is RosterLoaded) {
          context.read<TeamCabBloc>().add(
                FetchTeamCab(
                  empId: state.details.empId,
                  date: _selectedDate,
                ),
              );
        }
      },
      child: Column(
        children: [
          _FilterBar(date: _selectedDate, onPickDate: _pickDate),
          Expanded(
            child: RefreshIndicator(
              color: TeamCabScreen._primary,
              onRefresh: _onRefresh,
              child: BlocBuilder<RosterBloc, RosterState>(
                builder: (context, rosterState) {
                  if (rosterState is RosterError) {
                    return _ScrollableFill(
                      child: _ErrorView(
                        title: 'Something went wrong',
                        message:
                            "We couldn't load your details right now. "
                            'Please try again in a moment.',
                        onRetry: () => context
                            .read<RosterBloc>()
                            .add(const FetchRosterUserDetails()),
                      ),
                    );
                  }
                  if (rosterState is RosterUnauthorized) {
                    return _ScrollableFill(
                      child: _ErrorView(
                        title: 'Session expired',
                        message: rosterState.message,
                      ),
                    );
                  }

                  // Roster is loading / loaded → defer to team-cab state.
                  return BlocBuilder<TeamCabBloc, TeamCabState>(
                    builder: (context, state) {
                      if (state is TeamCabLoaded) {
                        return _TeamCabContent(data: state.data);
                      }
                      if (state is TeamCabError) {
                        return _ScrollableFill(
                          child: _ErrorView(
                            title: state.title,
                            message: state.message,
                            onRetry: _fetch,
                          ),
                        );
                      }
                      return _ScrollableFill(
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that always scrolls so [RefreshIndicator] can be triggered even when
/// the content (error / empty / loading) would otherwise not be scrollable.
class _ScrollableFill extends StatelessWidget {
  final Widget child;

  const _ScrollableFill({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPickDate;

  const _FilterBar({required this.date, required this.onPickDate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Text(
            'Date',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              fontFamily: 'Manrope',
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: TeamCabScreen._primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateLong(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded,
                      size: 20, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCabContent extends StatelessWidget {
  final TeamTrackingPanelResponse data;

  const _TeamCabContent({required this.data});

  @override
  Widget build(BuildContext context) {
    // Server-reported failure (isSuccess == false) → show its message.
    if (!data.isSuccess) {
      final msg = data.message.trim();
      return _ScrollableFill(
        child: _ErrorView(
          title: 'Unable to load',
          message: msg.isNotEmpty
              ? msg
              : 'Something went wrong while loading team cab.',
        ),
      );
    }

    final trips = data.trips;

    if (trips.isEmpty) {
      return _ScrollableFill(child: _EmptyView(date: data.requestedDate));
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: trips.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HeaderBar(date: data.requestedDate, count: trips.length);
        }
        return _TripCard(trip: trips[index - 1]);
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final DateTime? date;
  final int count;

  const _HeaderBar({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded,
              size: 20, color: TeamCabScreen._primary),
          const SizedBox(width: 8),
          Text(
            _formatDateLong(date),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              fontFamily: 'Manrope',
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TeamCabScreen._primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count ${count == 1 ? 'trip' : 'trips'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TeamCabScreen._primary,
                fontFamily: 'Manrope',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TeamTripModel trip;

  const _TripCard({required this.trip});

  bool get _isPickup => trip.tripType == 1;

  /// Live tracking is only available while the cab is actively running, i.e.
  /// the trip status is one of: Boarded, Not-Boarded, or En-Route.
  /// Matching is done on the status name, normalised so spacing/hyphen/case
  /// variants ("En Route", "en-route", "Not Boarded"…) all resolve correctly.
  bool get _canTrack {
    final normalised = trip.tripStatusName
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
    const trackableStatuses = {'boarded', 'notboarded', 'enroute'};
    return trackableStatuses.contains(normalised);
  }

  void _openLiveTracking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CabTrackingBloc>()
            ..add(FetchCabTracking(empId: trip.empId, tripId: trip.dsId)),
          child: RideTrackingScreen(
            tripId: trip.dsId,
            empId: trip.empId,
            userName: trip.fullName,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TripTypeBadge(isPickup: _isPickup, label: trip.tripTypeName),
                const Spacer(),
                _StatusChip(
                  statusCode: trip.tripStatusCode,
                  label: trip.tripStatusName,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: TeamCabScreen._primary.withOpacity(0.12),
                  child: Text(
                    _initials(trip.fullName),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: TeamCabScreen._primary,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.fullName.isEmpty ? 'Unknown' : trip.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          fontFamily: 'Manrope',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Trip #${trip.dsId}  •  Emp ${trip.empId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEFEFEF)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeBlock(
                    icon: Icons.schedule_rounded,
                    label: 'Schedule Time',
                    value: _formatTime(trip.scheduledStartTime),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFEFEFEF),
                ),
                SizedBox(width: 16,),
                Expanded(
                  child: _TimeBlock(
                    icon: Icons.event_rounded,
                    label: 'Trip Date',
                    value: _formatDateShort(trip.dsDate),
                  ),
                ),
              ],
            ),
            if (_canTrack) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openLiveTracking(context),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: const Text(
                    'Live Tracking',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeamCabScreen._primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripTypeBadge extends StatelessWidget {
  final bool isPickup;
  final String label;

  const _TripTypeBadge({required this.isPickup, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = isPickup ? const Color(0xFF1A6B3C) : const Color(0xFF1D4ED8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPickup ? Icons.north_east_rounded : Icons.south_west_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label.isEmpty ? (isPickup ? 'Pickup' : 'Drop') : label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int statusCode;
  final String label;

  const _StatusChip({required this.statusCode, required this.label});

  /// Colour keyed on the status NAME so it matches the server's
  /// human-readable status. Names are normalised (lowercase, no
  /// spaces/hyphens/underscores) so "En Route", "en-route", "Not-Boarded"
  /// etc. all map correctly.
  Color get _color {
    final normalised =
        label.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    switch (normalised) {
      case 'cancelled':
      case 'noshow':
        return const Color(0xFFDC2626); // red
      case 'tripcompleted':
      case 'reachedhome':
        return const Color(0xFF1A6B3C); // green
      case 'deboarded':
        return const Color(0xFF0E7490); // teal
      case 'boarded':
        return const Color(0xFFB45309); // amber
      case 'enroute':
        return const Color(0xFF1D4ED8); // blue
      case 'notboarded':
        return const Color(0xFF7C3AED); // purple
      case 'pending':
        return const Color(0xFF6B7280); // grey
      default:
        return const Color(0xFF6B7280); // grey
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.isEmpty ? 'Unknown' : label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimeBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              fontFamily: 'Manrope',
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final DateTime? date;

  const _EmptyView({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_filled_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No team trips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no trips for ${_formatDateLong(date)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF6B7280),
                fontFamily: 'Manrope',
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeamCabScreen._primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDateLong(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String _formatDateShort(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]}';
}

String _formatTime(DateTime? d) {
  if (d == null) return '—';
  final h24 = d.hour;
  final period = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}
