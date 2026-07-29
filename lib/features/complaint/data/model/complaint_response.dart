import 'dart:convert';

class ComplaintListApiResponse {
  final bool isSuccess;
  final String message;
  final List<ComplaintEnvelope> envelopes;

  const ComplaintListApiResponse({
    required this.isSuccess,
    required this.message,
    this.envelopes = const [],
  });

  ComplaintEnvelope? get firstEnvelope =>
      envelopes.isNotEmpty ? envelopes.first : null;

  factory ComplaintListApiResponse.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final envelopes = <ComplaintEnvelope>[];
    if (rawResult is List) {
      for (final entry in rawResult) {
        if (entry is Map<String, dynamic>) {
          envelopes.add(ComplaintEnvelope.fromJson(entry));
        } else if (entry is Map) {
          envelopes.add(
            ComplaintEnvelope.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return ComplaintListApiResponse(
      isSuccess: json['isSuccess'] == true,
      message: json['message']?.toString() ?? '',
      envelopes: envelopes,
    );
  }
}

class ComplaintEnvelope {
  final int errorCode;
  final String dbResponse;
  final List<ComplaintItem> complaints;

  const ComplaintEnvelope({
    required this.errorCode,
    required this.dbResponse,
    this.complaints = const [],
  });

  bool get isSuccess =>
      errorCode == 0 && dbResponse.toLowerCase() == 'success';

  factory ComplaintEnvelope.fromJson(Map<String, dynamic> json) {
    return ComplaintEnvelope(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      complaints: _parseComplaints(json['result']),
    );
  }

  static List<ComplaintItem> _parseComplaints(Object? raw) {
    if (raw == null) return const [];
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ComplaintItem.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

class ComplaintItem {
  final int? complaintId;
  final String? complaintType;
  final String? complaintDetail;
  final String? complaintDate;
  final String? tripType;
  final String? tripDate;
  final String? status;

  const ComplaintItem({
    this.complaintId,
    this.complaintType,
    this.complaintDetail,
    this.complaintDate,
    this.tripType,
    this.tripDate,
    this.status,
  });

  factory ComplaintItem.fromJson(Map<String, dynamic> json) {
    return ComplaintItem(
      complaintId: (json['ComplaintId'] as num?)?.toInt(),
      complaintType: json['ComplaintType']?.toString(),
      complaintDetail: json['ComplaintDetail']?.toString(),
      complaintDate: json['ComplaintDate']?.toString(),
      tripType: json['TripType']?.toString(),
      tripDate: json['TripDate']?.toString(),
      status: json['Status']?.toString(),
    );
  }
}

class ComplaintListItem {
  final int complaintId;
  final String complaintType;
  final String complainDate;
  final String complainMessage;
  final String complainStatus;

  const ComplaintListItem({
    required this.complaintId,
    required this.complaintType,
    required this.complainDate,
    required this.complainMessage,
    required this.complainStatus,
  });

  factory ComplaintListItem.fromJson(Map<String, dynamic> json) {
    return ComplaintListItem(
      complaintId: (json['ComplaintId'] as num?)?.toInt() ?? 0,
      complaintType: json['ComplaintType']?.toString() ?? '',
      complainDate: json['ComplainDate']?.toString() ?? '',
      complainMessage: json['ComplainMessage']?.toString() ?? '',
      complainStatus: json['ComplainStatus']?.toString() ?? '',
    );
  }
}

class ComplaintListApiV2Response {
  final int errorCode;
  final String dbResponse;
  final List<ComplaintListItem> items;

  const ComplaintListApiV2Response({
    required this.errorCode,
    required this.dbResponse,
    required this.items,
  });

  bool get isSuccess => errorCode == 0;

  factory ComplaintListApiV2Response.fromJson(Map<String, dynamic> json) {
    return ComplaintListApiV2Response(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      items: _parseItems(json['result']),
    );
  }

  static List<ComplaintListItem> _parseItems(Object? raw) {
    if (raw == null) return const [];
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ComplaintListItem.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// A single message in a complaint's conversation thread.
class ComplaintThreadItem {
  final String message;
  final String threadBy;
  final String threadOn;
  final String roleName;

  const ComplaintThreadItem({
    required this.message,
    required this.threadBy,
    required this.threadOn,
    required this.roleName,
  });

  /// True when [roleName] is `Employee` — the user's own message. These render
  /// on the right of the thread; everyone else (the transport management team)
  /// renders on the left.
  bool get isFromEmployee => roleName.trim().toLowerCase() == 'employee';

  factory ComplaintThreadItem.fromJson(Map<String, dynamic> json) {
    return ComplaintThreadItem(
      message: json['Message']?.toString() ?? '',
      threadBy: json['ThreadBy']?.toString() ?? '',
      threadOn: json['ThreadOn']?.toString() ?? '',
      roleName: json['RoleName']?.toString() ?? '',
    );
  }
}

class ComplaintDetailItem {
  final int complaintId;
  final String complaintType;
  final String complainDate;
  final String complainMessage;
  final String transportReply;
  final String status;
  final List<ComplaintThreadItem> threads;

  const ComplaintDetailItem({
    required this.complaintId,
    required this.complaintType,
    required this.complainDate,
    required this.complainMessage,
    required this.transportReply,
    required this.status,
    this.threads = const [],
  });

  factory ComplaintDetailItem.fromJson(Map<String, dynamic> json) {
    return ComplaintDetailItem(
      complaintId: (json['ComplaintId'] as num?)?.toInt() ?? 0,
      complaintType: json['ComplaintType']?.toString() ?? '',
      complainDate: json['ComplainDate']?.toString() ?? '',
      complainMessage: json['ComplainMessage']?.toString() ?? '',
      transportReply: json['TransportReply']?.toString() ?? '',
      status: json['STATUS']?.toString() ?? '',
      threads: _parseThreads(json['ComplaintThreads']),
    );
  }

  static List<ComplaintThreadItem> _parseThreads(Object? raw) {
    if (raw == null) return const [];
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ComplaintThreadItem.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

class ComplaintDetailApiResponse {
  final int errorCode;
  final String dbResponse;
  final List<ComplaintDetailItem> items;

  const ComplaintDetailApiResponse({
    required this.errorCode,
    required this.dbResponse,
    required this.items,
  });

  bool get isSuccess => errorCode == 0;

  factory ComplaintDetailApiResponse.fromJson(Map<String, dynamic> json) {
    return ComplaintDetailApiResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      items: _parseItems(json['result']),
    );
  }

  static List<ComplaintDetailItem> _parseItems(Object? raw) {
    if (raw == null) return const [];
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ComplaintDetailItem.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

class ComplaintLookupItem {
  final int complaintType;
  final String complainName;

  const ComplaintLookupItem({
    required this.complaintType,
    required this.complainName,
  });

  factory ComplaintLookupItem.fromJson(Map<String, dynamic> json) {
    return ComplaintLookupItem(
      complaintType: (json['ComplaintType'] as num?)?.toInt() ?? 0,
      complainName: json['ComplainName']?.toString() ?? '',
    );
  }
}

class ComplaintLookupApiResponse {
  final int errorCode;
  final String dbResponse;
  final List<ComplaintLookupItem> items;

  const ComplaintLookupApiResponse({
    required this.errorCode,
    required this.dbResponse,
    required this.items,
  });

  bool get isSuccess =>
      errorCode == 0 && dbResponse.toLowerCase() == 'success';

  factory ComplaintLookupApiResponse.fromJson(Map<String, dynamic> json) {
    return ComplaintLookupApiResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      items: _parseItems(json['result']),
    );
  }

  static List<ComplaintLookupItem> _parseItems(Object? raw) {
    if (raw == null) return const [];
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ComplaintLookupItem.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

class RaiseComplaintApiResponse {
  final bool isSuccess;
  final String message;
  final int errorCode;
  final String dbResponse;

  const RaiseComplaintApiResponse({
    required this.isSuccess,
    required this.message,
    required this.errorCode,
    required this.dbResponse,
  });

  factory RaiseComplaintApiResponse.fromJson(Map<String, dynamic> json) {
    int errorCode = -1;
    String dbResponse = '';

    final rawResult = json['result'];
    if (rawResult is List && rawResult.isNotEmpty) {
      final first = rawResult.first;
      final map = first is Map<String, dynamic>
          ? first
          : (first is Map ? Map<String, dynamic>.from(first) : null);
      if (map != null) {
        errorCode = (map['errorCode'] as num?)?.toInt() ?? -1;
        dbResponse = map['dB_Response']?.toString() ?? '';
      }
    }

    return RaiseComplaintApiResponse(
      isSuccess: json['isSuccess'] == true,
      message: json['message']?.toString() ?? '',
      errorCode: errorCode,
      dbResponse: dbResponse,
    );
  }
}
