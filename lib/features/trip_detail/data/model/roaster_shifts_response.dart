import 'dart:convert';

// ─── shift_models.dart ───────────────────────────────────────────────────────

// Top-level API response wrapper
class RoasterShiftResponse {
  final int errorCode;
  final String dBResponse;
  final ShiftResult result;

  const RoasterShiftResponse({
    required this.errorCode,
    required this.dBResponse,
    required this.result,
  });

  bool get isSuccess =>
      errorCode == 0 && dBResponse.toLowerCase() == 'success';

  factory RoasterShiftResponse.fromJson(Map<String, dynamic> json) {
    return RoasterShiftResponse(
      errorCode: json['errorCode'] as int,
      dBResponse: json['dB_Response'] as String,
      result: ShiftResult.fromJson(
        (json['result'] is String)
            ? Map<String, dynamic>.from(
            _parseJsonString(json['result'] as String))
            : json['result'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'errorCode': errorCode,
    'dB_Response': dBResponse,
    'result': result.toJson(),
  };

  static Map<String, dynamic> _parseJsonString(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;
}

// ─── ShiftResult ─────────────────────────────────────────────────────────────

class ShiftResult {
  final List<PickShift> pickShifts;
  final List<DropShift> dropShifts;
  final int empId;

  const ShiftResult({
    required this.pickShifts,
    required this.dropShifts,
    required this.empId,
  });

  factory ShiftResult.fromJson(Map<String, dynamic> json) {
    return ShiftResult(
      pickShifts: (json['PickShifts'] as List<dynamic>)
          .map((e) => PickShift.fromJson(e as Map<String, dynamic>))
          .toList(),
      dropShifts: (json['DropShifts'] as List<dynamic>)
          .map((e) => DropShift.fromJson(e as Map<String, dynamic>))
          .toList(),
      empId: json['EmpId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'PickShifts': pickShifts.map((e) => e.toJson()).toList(),
    'DropShifts': dropShifts.map((e) => e.toJson()).toList(),
    'EmpId': empId,
  };
}

// ─── PickShift ────────────────────────────────────────────────────────────────
// DropShift is a nullable String ("" means no associated drop time).

class PickShift {
  final int shiftId;
  final String shiftTime;
  final String? dropShift; // null or empty string → no drop shift assigned

  const PickShift({
    required this.shiftId,
    required this.shiftTime,
    this.dropShift,
  });

  /// Returns true when this pick shift has an associated drop shift time.
  bool get hasDropShift => dropShift != null && dropShift!.isNotEmpty;

  factory PickShift.fromJson(Map<String, dynamic> json) {
    final raw = json['DropShift'] as String?;
    return PickShift(
      shiftId: json['SHIFTID'] as int,
      shiftTime: json['SHIFTTIME'] as String,
      dropShift: (raw == null || raw.isEmpty) ? null : raw,
    );
  }

  Map<String, dynamic> toJson() => {
    'SHIFTID': shiftId,
    'SHIFTTIME': shiftTime,
    'DropShift': dropShift ?? '',
  };

  @override
  String toString() =>
      'PickShift(shiftId: $shiftId, shiftTime: $shiftTime, dropShift: $dropShift)';
}

// ─── DropShift ────────────────────────────────────────────────────────────────

class DropShift {
  final int shiftId;
  final String shiftTime;

  const DropShift({
    required this.shiftId,
    required this.shiftTime,
  });

  factory DropShift.fromJson(Map<String, dynamic> json) {
    return DropShift(
      shiftId: json['SHIFTID'] as int,
      shiftTime: json['SHIFTTIME'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'SHIFTID': shiftId,
    'SHIFTTIME': shiftTime,
  };

  @override
  String toString() =>
      'DropShift(shiftId: $shiftId, shiftTime: $shiftTime)';
}