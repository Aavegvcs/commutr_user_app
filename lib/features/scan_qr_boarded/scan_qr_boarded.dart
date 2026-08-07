import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/di/injection.dart';
import '../../core/utils/error_message.dart';
import 'data/repository/qr_board_repo.dart';

/// Outcome of the `/qr-board` call, returned by [ScanQr] to its caller.
///
/// Both outcomes are handed back so the welcome screen owns the result popup
/// and (on success) the trip-list refetch. [ScanQr] pops with `null` only when
/// the user backs out without a completed attempt.
class QrBoardResult {
  final bool success;
  final String message;

  const QrBoardResult({required this.success, required this.message});
}

class ScanQr extends StatefulWidget {
  /// Trip id of the trip being boarded (`TripHomeItem.tripId`).
  final int? dsId;

  /// Employee id of the passenger boarding (`TripHomeItem.empId`).
  final int? empId;

  const ScanQr({super.key, this.dsId, this.empId});

  @override
  State<ScanQr> createState() => _ScanQrState();
}

class _ScanQrState extends State<ScanQr> {
  static const Color _darkGreen = Color(0xFF1B5E4B);

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _torchOn = false;
  bool _handled = false;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    _handled = true;
    _submitQrBoard(value.trim());
  }

  /// Posts the scanned QR to `/qr-board`, then pops back to the caller with a
  /// [QrBoardResult] describing the outcome (success or failure).
  Future<void> _submitQrBoard(String qrCode) async {
    final dsId = widget.dsId;
    final empId = widget.empId;

    if (dsId == null || empId == null) {
      debugPrint('[QR_BOARD] missing trip context — dsId=$dsId empId=$empId');
      _showMessage('Trip details unavailable. Please try again.');
      _resumeScanning();
      return;
    }

    setState(() => _submitting = true);
    await _controller.stop();

    final location = await _resolveLocation();

    try {
      final response = await sl<QrBoardRepo>().qrBoard(
        dsId: dsId,
        empId: empId,
        qrCode: qrCode,
        lat: location.$1,
        lng: location.$2,
      );

      if (!mounted) return;

      // Both outcomes go back to the welcome screen, which shows the result
      // popup — this route's Navigator/ScaffoldMessenger is torn down by the
      // pop, so the dialog cannot live here.
      _popWithResult(
        success: response.isSuccess,
        message: response.message.isNotEmpty
            ? response.message
            : (response.isSuccess
                ? 'Boarded successfully.'
                : 'Boarding failed. Please try again.'),
      );
    } catch (e) {
      debugPrint('[QR_BOARD] ✖ $e');
      if (!mounted) return;
      _popWithResult(
        success: false,
        message:
            ErrorMessage.from(e, fallback: 'Boarding failed. Please try again.'),
      );
    }
  }

  void _popWithResult({required bool success, required String message}) {
    Navigator.of(context).pop(
      QrBoardResult(success: success, message: message),
    );
  }

  /// Current (lat, lng); falls back to `(0, 0)` when unavailable so boarding
  /// still reaches the server — matching the ReachedHome flow.
  Future<(double, double)> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (0.0, 0.0);
      }

      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && lastKnown != null) {
        return (lastKnown.latitude, lastKnown.longitude);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return (pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[QR_BOARD] location error: $e');
      return (0.0, 0.0);
    }
  }

  /// Re-arms the scanner after a failed attempt.
  Future<void> _resumeScanning() async {
    if (!mounted) return;
    setState(() => _submitting = false);
    _handled = false;
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR',
          style: TextStyle(
            color: _darkGreen,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Slight dark overlay for contrast.
          Container(color: Colors.black.withValues(alpha: 0.15)),
          _buildScanFrame(),
          _buildBottomContent(),
          if (_submitting)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -60),
        child: SizedBox(
          width: 260,
          height: 260,
          child: CustomPaint(
            painter: _ScanFramePainter(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan QR Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Align the QR code within the frame to scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 64),
            _buildFlashlightButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashlightButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _submitting ? null : _toggleTorch,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              const Text(
                'Flashlight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws four rounded white corner brackets around the scan area.
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double corner = 44; // length of each corner arm
    const double radius = 20; // rounded corner radius

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, corner)
        ..lineTo(0, radius)
        ..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))
        ..lineTo(corner, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - corner, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))
        ..lineTo(size.width, corner),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - corner)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(Offset(size.width - radius, size.height),
            radius: const Radius.circular(radius))
        ..lineTo(size.width - corner, size.height),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(corner, size.height)
        ..lineTo(radius, size.height)
        ..arcToPoint(Offset(0, size.height - radius),
            radius: const Radius.circular(radius))
        ..lineTo(0, size.height - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
