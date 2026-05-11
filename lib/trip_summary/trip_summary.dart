import 'package:flutter/material.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key});

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
                    _MapCard(),
                    const SizedBox(height: 16),

                    // Trip Detail Card
                    _TripDetailCard(),
                    const SizedBox(height: 16),

                    // Vehicle Detail Card
                    _VehicleDetailCard(),
                    const SizedBox(height: 16),

                    // Pickup & Drop Row
                    _PickupDropRow(),
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
  @override
  Widget build(BuildContext context) {
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
                  // Map placeholder with route drawing
                  _MapPlaceholder(),

                  // Trip Completed Badge
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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
                  children: const [
                    Text(
                      'LOGIN TIME',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '9:03 AM',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Icon(
                      Icons.accessible_forward,
                      color: Color(0xFF3E9B73),
                      size: 22,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Sequence 2/3',
                      style: TextStyle(
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
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(),
      child: Container(
        color: Colors.transparent,
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
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
    _drawText(canvas, 'Shastri Nagar', Offset(size.width * 0.44, size.height * 0.43), labelStyle);
    _drawText(canvas, 'DLF Gurugram', Offset(size.width * 0.38, size.height * 0.98), labelStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Trip Detail Card ─────────────────────────────────────────────────────────

class _TripDetailCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                          const Text(
                            'Shastri Nagar, Phase 2',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3437),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Main Entrance Gate, Pune',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff596064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DLF Gurugram',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3437),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Main Entrance Gate, Pune',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff596064),
                            ),
                          ),
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
  @override
  Widget build(BuildContext context) {
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
            children: const [
              Text(
                'VEHICLE DETAIL',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'HR-55-AW-0640',
                style: TextStyle(
                  color: Color(0xFF1B5E3B),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'SEDAN_EV',
                style: TextStyle(
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
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TimeCard(label: 'Pickup', time: '06:42 AM')),
        const SizedBox(width: 14),
        Expanded(child: _TimeCard(label: 'Drop Timing', time: '08:00 AM')),
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