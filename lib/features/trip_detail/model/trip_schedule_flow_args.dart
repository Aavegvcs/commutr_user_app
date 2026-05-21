import '../data/model/schedule_home_response.dart';

/// Carries schedule-home data through the create/update roster flow so each
/// step can pre-fill selections when the user taps Edit on the welcome screen.
class TripScheduleFlowArgs {
  /// `true` when opened from welcome schedule card edit (update existing).
  final bool isEdit;

  /// Login (pickup) vs logout (drop) trip being edited.
  final bool isLogIn;

  final int locCode;
  final int empId;

  /// API date format `yyyy-MM-dd`.
  final String fromDate;
  final String toDate;

  /// Shift time from schedule home (`LoginShiftTime` / `LogoutShiftTime`),
  /// e.g. `"09:45"`.
  final String? preselectedShiftTime;

  const TripScheduleFlowArgs({
    required this.isEdit,
    required this.isLogIn,
    required this.locCode,
    required this.empId,
    required this.fromDate,
    required this.toDate,
    this.preselectedShiftTime,
  });

  /// Builds edit args from a [ScheduleItem] and roster [locCode].
  factory TripScheduleFlowArgs.fromScheduleItem({
    required ScheduleItem item,
    required bool isLogIn,
    required int locCode,
  }) {
    final dateRaw =
        isLogIn ? item.loginScheduleDate : item.logoutScheduleDate;
    final iso = scheduleDateToIso(dateRaw) ?? '';
    final shift =
        isLogIn ? item.loginShiftTime : item.logoutShiftTime;

    return TripScheduleFlowArgs(
      isEdit: true,
      isLogIn: isLogIn,
      locCode: locCode,
      empId: item.empId ?? 0,
      fromDate: iso,
      toDate: iso,
      preselectedShiftTime: shift,
    );
  }

  bool get hasValidDates => fromDate.isNotEmpty && toDate.isNotEmpty;
}

/// Parses schedule-home dates like `"21-May-2026"` → `yyyy-MM-dd`.
String? scheduleDateToIso(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  const monthIndex = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  final parts = trimmed.split('-');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = monthIndex[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }
  }

  // Already ISO-shaped.
  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (isoMatch != null) return trimmed;

  return null;
}

DateTime? parseIsoDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Normalizes shift times for matching (`"9:45"` vs `"09:45"`).
String normalizeShiftTime(String? raw) {
  if (raw == null) return '';
  final t = raw.trim();
  if (t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return t;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}';
}

bool shiftTimesMatch(String? a, String? b) =>
    normalizeShiftTime(a) == normalizeShiftTime(b) &&
    normalizeShiftTime(a).isNotEmpty;
