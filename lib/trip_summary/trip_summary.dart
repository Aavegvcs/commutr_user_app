import 'package:commutr_main/features/trip_detail/data/model/trip_history_response.dart';
import 'package:flutter/material.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key, required this.tripItem});

  final TripHistoryItem tripItem;

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static const List<String> _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const Map<String, int> _monthIndex = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parses `"21-May-2026"` → `DateTime`.
  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final parts = raw.trim().split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _monthIndex[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _formatDate(String? raw) {
    final d = _parseDate(raw);
    if (d == null) return raw ?? '--';
    return '${d.day} ${_monthAbbrev[d.month - 1]} ${d.year}';
  }

  /// `"09:30"` → `"9:30 AM"`.
  String _formatTime(String? raw) {
    if (raw == null) return '--';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '--';
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return trimmed;
    final period = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  String _tripTypeLabel() => tripItem.isLogin ? 'Login' : 'Logout';

  String _statusLabel() {
    if (tripItem.isNoShow) return 'No Show';
    if (tripItem.isCancelled) return 'Cancelled';
    if (tripItem.isCompleted) return 'Completed';
    final s = (tripItem.tripStatus ?? '').trim();
    return s.isEmpty ? '--' : s;
  }

  Color _statusColor() {
    if (tripItem.isNoShow || tripItem.isCancelled) return const Color(0xFFDC2626);
    if (tripItem.isCompleted) return const Color(0xFF2563EB);
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1B5E3B),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Trip Detail',
                    style: TextStyle(
                      color: Color(0xFF1B5E3B),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Map Card
                    _MapCard(status: _statusLabel(), statusColor: _statusColor()),
                    const SizedBox(height: 16),

                    // Trip Detail Card
                    _TripDetailCard(
                      tripDate: _formatDate(tripItem.tripDate),
                      tripType: _tripTypeLabel(),
                      shiftTime: _formatTime(tripItem.shiftTime),
                      pickTime: _formatTime(tripItem.pickTime),
                      pickupAddress: tripItem.pickupAddress,
                      officeAddress: tripItem.officeAddress,
                      status: _statusLabel(),
                      statusColor: _statusColor(),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Detail Card
                    _VehicleDetailCard(
                      vehicleNo: tripItem.vehicleRegistrationNo,
                    ),
                    const SizedBox(height: 16),

                    // Pickup & Drop Row
                    _PickupDropRow(
                      pickTime: _formatTime(tripItem.pickTime),
                      shiftTime: _formatTime(tripItem.shiftTime),
                      isLogin: tripItem.isLogin,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map Card ────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  const _MapCard({required this.status, required this.statusColor});

  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Map area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  _MapPlaceholder(),

                  // Status Badge
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: statusColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ─── Map Placeholder (custom painted route) ──────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(),
      child: Container(color: Colors.transparent),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()..color = const Color(0xFFECECE0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    final waterPaint = Paint()..color = const Color(0xFFB8D8EA);
    final coastPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.52, 0)
      ..lineTo(size.width * 0.38, size.height * 0.45)
      ..lineTo(size.width * 0.25, size.height * 0.65)
      ..lineTo(size.width * 0.18, size.height * 0.85)
      ..lineTo(0, size.height * 0.9)
      ..close();
    canvas.drawPath(coastPath, waterPaint);

    final roadPaint = Paint()
      ..color = const Color(0xFFE8CB6A)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.55, 0), Offset(size.width * 0.55, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.75, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.35), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.65), Offset(size.width, size.height * 0.65), roadPaint);

    final parkPaint = Paint()..color = const Color(0xFFBED8A0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.65, size.height * 0.15, size.width * 0.2, size.height * 0.25), const Radius.circular(8)), parkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.6, size.height * 0.5, size.width * 0.15, size.height * 0.15), const Radius.circular(6)), parkPaint);

    final routePaint = Paint()
      ..color = const Color(0xFF1A3A8F)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final routePath = Path()
      ..moveTo(size.width * 0.52, size.height * 0.08)
      ..lineTo(size.width * 0.65, size.height * 0.10)
      ..lineTo(size.width * 0.72, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.14, size.width * 0.74, size.height * 0.22)
      ..lineTo(size.width * 0.65, size.height * 0.30)
      ..lineTo(size.width * 0.60, size.height * 0.35)
      ..lineTo(size.width * 0.52, size.height * 0.37)
      ..lineTo(size.width * 0.44, size.height * 0.40)
      ..lineTo(size.width * 0.44, size.height * 0.60)
      ..quadraticBezierTo(size.width * 0.44, size.height * 0.72, size.width * 0.42, size.height * 0.82)
      ..lineTo(size.width * 0.40, size.height * 0.95);
    canvas.drawPath(routePath, routePaint);

    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.08), 6, Paint()..color = const Color(0xFF1A3A8F));
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.08), 3, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.40), 7, Paint()..color = const Color(0xFFE87A3A));
    canvas.drawCircle(Offset(size.width * 0.40, size.height * 0.95), 7, Paint()..color = const Color(0xFF2E8B6A));
    canvas.drawCircle(Offset(size.width * 0.40, size.height * 0.95), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Trip Detail Card ─────────────────────────────────────────────────────────

class _TripDetailCard extends StatelessWidget {
  const _TripDetailCard({
    required this.tripDate,
    required this.tripType,
    required this.shiftTime,
    required this.pickTime,
    required this.pickupAddress,
    required this.officeAddress,
    required this.status,
    required this.statusColor,
  });

  final String tripDate;
  final String tripType;
  final String shiftTime;
  final String pickTime;
  final String? pickupAddress;
  final String? officeAddress;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E8DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRIP DETAIL',
                style: TextStyle(
                  color: Color(0xFF596064),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date + Type + Shift
          Row(
            children: [
              _infoChip(Icons.calendar_today_outlined, tripDate),
              const SizedBox(width: 10),
              _infoChip(
                tripType == 'Login' ? Icons.login : Icons.logout,
                tripType,
              ),
              const SizedBox(width: 10),
              _infoChip(Icons.access_time, shiftTime),
            ],
          ),
          const SizedBox(height: 16),

          // Route
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/pre_location.png',
                  width: 19,
                  height: 88,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _addressBlock(
                        'PICKUP',
                        pickupAddress?.isNotEmpty == true
                            ? pickupAddress!
                            : 'Address not available',
                      ),
                      const SizedBox(height: 20),
                      _addressBlock(
                        'OFFICE / DROP',
                        officeAddress?.isNotEmpty == true
                            ? officeAddress!
                            : 'Address not available',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF596064)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3437),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressBlock(String label, String address) {
    final idx = address.indexOf(',');
    final title = idx < 0 ? address : address.substring(0, idx).trim();
    final sub = idx < 0 ? null : address.substring(idx + 1).trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3437),
          ),
        ),
        if (sub != null && sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 12, color: Color(0xFF596064)),
          ),
        ],
      ],
    );
  }
}

// ─── Vehicle Detail Card ──────────────────────────────────────────────────────

class _VehicleDetailCard extends StatelessWidget {
  const _VehicleDetailCard({required this.vehicleNo});

  final String? vehicleNo;

  @override
  Widget build(BuildContext context) {
    final hasVehicle = vehicleNo != null && vehicleNo!.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Color(0xFF555555), size: 26),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VEHICLE DETAIL',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasVehicle ? vehicleNo!.trim() : 'Not available',
                style: TextStyle(
                  color: hasVehicle
                      ? const Color(0xFF1B5E3B)
                      : const Color(0xFF9E9E9E),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pickup & Drop Row ────────────────────────────────────────────────────────

class _PickupDropRow extends StatelessWidget {
  const _PickupDropRow({
    required this.pickTime,
    required this.shiftTime,
    required this.isLogin,
  });

  final String pickTime;
  final String shiftTime;
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TimeCard(label: 'Pickup Time', time: pickTime)),
        const SizedBox(width: 14),
        Expanded(
          child: _TimeCard(
            label: isLogin ? 'Login Shift' : 'Logout Shift',
            time: shiftTime,
          ),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
