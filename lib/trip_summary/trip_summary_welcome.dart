import 'package:commutr_main/features/trip_detail/data/model/trip_home_response.dart';
import 'package:flutter/material.dart';

class TripSummaryWelcomeScreen extends StatelessWidget {
  const TripSummaryWelcomeScreen({super.key, required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      body: SafeArea(
        child: Column(
          children: [
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
                      color: Color(0xFF004128),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _MapCard(item: item),
                    const SizedBox(height: 16),
                    _TripDetailCard(item: item),
                    const SizedBox(height: 16),
                    _VehicleDetailCard(item: item),
                    const SizedBox(height: 16),
                    _PickupDropRow(item: item),
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

String? _formatShiftTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final period = h >= 12 ? 'PM' : 'AM';
  var hour12 = h % 12;
  if (hour12 == 0) hour12 = 12;
  final mm = m.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
}

String? _plannedPickupLabel(TripHomeItem item) {
  final pickTime = item.pickTime?.trim();
  if (pickTime != null && pickTime.isNotEmpty) {
    return _formatShiftTime(pickTime) ?? pickTime;
  }
  return _formatShiftTime(item.pickShift);
}

({String title, String? subtitle}) _splitAddress(String? address) {
  final cleaned = address?.trim();
  if (cleaned == null || cleaned.isEmpty) {
    return (title: 'Address not available', subtitle: null);
  }
  final idx = cleaned.indexOf(',');
  if (idx < 0) return (title: cleaned, subtitle: null);
  final title = cleaned.substring(0, idx).trim();
  final rest = cleaned.substring(idx + 1).trim();
  return (
    title: title.isEmpty ? cleaned : title,
    subtitle: rest.isEmpty ? null : rest,
  );
}

// ─── Map Card ────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  const _MapCard({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final pickupAddr = _splitAddress(
      isLogin ? item.userAddress : item.officeAddress,
    );
    final dropAddr = _splitAddress(
      isLogin ? item.officeAddress : item.userAddress,
    );
    final shiftTime =
        _formatShiftTime(item.pickShift) ?? item.pickShift ?? '--:--';
    final seqLabel = (item.paxOrder != null && item.paxCount != null)
        ? 'Sequence ${item.paxOrder}/${item.paxCount}'
        : null;
    final timeLabel = isLogin ? 'LOGIN TIME' : 'LOGOUT TIME';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                  _MapPlaceholder(
                    originLabel: pickupAddr.title,
                    destinationLabel: dropAddr.title,
                  ),
                  if (item.isCompleted)
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8C4E0).withOpacity(0.88),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Color(0xFF3A5BA0),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TRIP COMPLETED',
                              style: TextStyle(
                                color: Color(0xFF3A5BA0),
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

          // Login time & Sequence
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      shiftTime,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (seqLabel != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.accessible_forward,
                        color: Color(0xFF3E9B73),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        seqLabel,
                        style: const TextStyle(
                          color: Color(0xFF3E9B73),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map Placeholder (custom painted route) ──────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.originLabel,
    required this.destinationLabel,
  });

  final String originLabel;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(
        originLabel: originLabel,
        destinationLabel: destinationLabel,
      ),
      child: Container(
        color: Colors.transparent,
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.originLabel,
    required this.destinationLabel,
  });

  final String originLabel;
  final String destinationLabel;

  @override
  void paint(Canvas canvas, Size size) {
    // Sky / water background (top left)
    final waterPaint = Paint()..color = const Color(0xFFB8D8EA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.55, size.height * 0.7), waterPaint);

    // Land background
    final landPaint = Paint()..color = const Color(0xFFECECE0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // Water polygon (top-left coastal area)
    final coastPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.52, 0)
      ..lineTo(size.width * 0.38, size.height * 0.45)
      ..lineTo(size.width * 0.25, size.height * 0.65)
      ..lineTo(size.width * 0.18, size.height * 0.85)
      ..lineTo(0, size.height * 0.9)
      ..close();
    canvas.drawPath(coastPath, waterPaint);

    // Major roads (yellow)
    final roadPaint = Paint()
      ..color = const Color(0xFFE8CB6A)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Vertical road
    canvas.drawLine(
      Offset(size.width * 0.55, 0),
      Offset(size.width * 0.55, size.height),
      roadPaint,
    );
    // Diagonal road
    canvas.drawLine(
      Offset(size.width * 0.4, 0),
      Offset(size.width * 0.75, size.height),
      roadPaint,
    );
    // Horizontal roads
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.35),
      Offset(size.width, size.height * 0.35),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.65),
      Offset(size.width, size.height * 0.65),
      roadPaint,
    );

    // Minor roads (white/light)
    final minorRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 5; i++) {
      canvas.drawLine(
        Offset(size.width * 0.5 + i * 20, 0),
        Offset(size.width * 0.5 + i * 20, size.height),
        minorRoadPaint,
      );
    }
    for (int i = 1; i <= 4; i++) {
      canvas.drawLine(
        Offset(size.width * 0.4, size.height * 0.15 * i),
        Offset(size.width, size.height * 0.15 * i),
        minorRoadPaint,
      );
    }

    // Green area (park)
    final parkPaint = Paint()..color = const Color(0xFFBED8A0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.15, size.width * 0.2, size.height * 0.25),
        const Radius.circular(8),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.6, size.height * 0.5, size.width * 0.15, size.height * 0.15),
        const Radius.circular(6),
      ),
      parkPaint,
    );

    // Route path (dark blue, thick)
    final routePaint = Paint()
      ..color = const Color(0xFF1A3A8F)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePath = Path()
      ..moveTo(size.width * 0.52, size.height * 0.08) // top
      ..lineTo(size.width * 0.65, size.height * 0.10)
      ..lineTo(size.width * 0.72, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.78, size.height * 0.14,
        size.width * 0.74, size.height * 0.22,
      )
      ..lineTo(size.width * 0.65, size.height * 0.30)
      ..lineTo(size.width * 0.60, size.height * 0.35)
      ..lineTo(size.width * 0.52, size.height * 0.37)
      ..lineTo(size.width * 0.44, size.height * 0.40) // midpoint (origin pin)
      ..lineTo(size.width * 0.44, size.height * 0.50)
      ..lineTo(size.width * 0.44, size.height * 0.60)
      ..quadraticBezierTo(
        size.width * 0.44, size.height * 0.72,
        size.width * 0.42, size.height * 0.82,
      )
      ..lineTo(size.width * 0.40, size.height * 0.95); // bottom (destination)

    canvas.drawPath(routePath, routePaint);

    // Origin pin (blue circle)
    final originPinPaint = Paint()..color = const Color(0xFF1A3A8F);
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.08),
      6,
      originPinPaint,
    );
    final originInner = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.08),
      3,
      originInner,
    );

    // Mid stop pin (orange circle)
    final midPinPaint = Paint()..color = const Color(0xFFE87A3A);
    canvas.drawCircle(
      Offset(size.width * 0.44, size.height * 0.40),
      7,
      midPinPaint,
    );

    // Destination pin (teal/green)
    final destPinPaint = Paint()..color = const Color(0xFF2E8B6A);
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.95),
      7,
      destPinPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.95),
      4,
      Paint()..color = Colors.white,
    );

    // Map label texts
    final labelStyle = TextStyle(
      color: const Color(0xFF555555),
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    _drawText(
      canvas,
      _shortMapLabel(originLabel),
      Offset(size.width * 0.44, size.height * 0.43),
      labelStyle,
    );
    _drawText(
      canvas,
      _shortMapLabel(destinationLabel),
      Offset(size.width * 0.38, size.height * 0.98),
      labelStyle,
    );
  }

  String _shortMapLabel(String label) {
    if (label.length <= 18) return label;
    return '${label.substring(0, 16)}…';
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.originLabel != originLabel ||
      oldDelegate.destinationLabel != destinationLabel;
}

// ─── Trip Detail Card ─────────────────────────────────────────────────────────

class _TripDetailCard extends StatelessWidget {
  const _TripDetailCard({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final pickup = _splitAddress(
      isLogin ? item.userAddress : item.officeAddress,
    );
    final drop = _splitAddress(
      isLogin ? item.officeAddress : item.userAddress,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E8DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),

          // Origin
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Image.asset(
                      'assets/images/pre_location.png',
                      width: 19,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3437),
                            ),
                          ),
                          if (pickup.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              pickup.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff596064),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drop.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3437),
                            ),
                          ),
                          if (drop.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              drop.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff596064),
                              ),
                            ),
                          ],
                        ],
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
}

// ─── Vehicle Detail Card ──────────────────────────────────────────────────────

class _VehicleDetailCard extends StatelessWidget {
  const _VehicleDetailCard({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final vehicle = item.vehicleInfo?.trim();
    final hasVehicle = vehicle != null && vehicle.isNotEmpty;
    final tripType = item.tripType?.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                hasVehicle ? vehicle : 'Not assigned',
                style: TextStyle(
                  color: hasVehicle
                      ? const Color(0xFF1B5E3B)
                      : const Color(0xFF9AA0A6),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              if (tripType != null && tripType.isNotEmpty)
                Text(
                  tripType,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
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
  const _PickupDropRow({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final plannedPickup = _plannedPickupLabel(item) ?? '--:--';
    final shiftTime = _formatShiftTime(item.pickShift) ?? '--:--';
    final pickupTime = isLogin ? plannedPickup : shiftTime;
    final dropTime = isLogin ? shiftTime : plannedPickup;
    final pickupLabel = isLogin ? 'Pickup' : 'Drop Time';
    final dropLabel = isLogin ? 'Drop Timing' : 'Pickup Time';

    return Row(
      children: [
        Expanded(child: _TimeCard(label: pickupLabel, time: pickupTime)),
        const SizedBox(width: 14),
        Expanded(child: _TimeCard(label: dropLabel, time: dropTime)),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final String time;

  const _TimeCard({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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