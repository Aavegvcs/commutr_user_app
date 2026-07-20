import 'dart:convert';

/// Wraps the `POST /TransRoster/CancelScheduleConfirmation` response.
///
/// The API is the single source of truth for the cancel / no-show confirmation
/// popup. It decides whether the popup is a "Cancel Schedule" confirmation or a
/// "Mark No Show" confirmation, and returns the icon, title, message and the
/// buttons (with their actions) to render.
///
/// The response is an envelope (identical in shape to `CancelSchedules`): the
/// outer `result[0]` carries `errorCode` / `dB_Response`, and its inner
/// `result` value is a **JSON-encoded string** holding the popup config array.
///
/// Success shape:
/// ```json
/// {
///   "result": [
///     {
///       "errorCode": 0,
///       "dB_Response": "Success",
///       "result": "[{\"popupId\":\"cancel_schedule\",\"icon\":\"warning\",\"title\":\"Cancel Schedule\",\"message\":\"Are you sure you want to cancel this schedule?\",\"buttons\":[{\"id\":\"cancel_schedule\",\"text\":\"Cancel Schedule\",\"action\":\"cancelSchedule\",\"order\":1},{\"id\":\"go_back\",\"text\":\"Go Back\",\"action\":\"dismiss\",\"order\":2}]}]"
///     }
///   ],
///   "isSuccess": true,
///   "message": "Success"
/// }
/// ```
///
/// Failure shape (do not open the dialog — surface [dbResponse] instead), e.g.:
/// ```json
/// { "result": [ { "errorCode": 1, "dB_Response": "Schedule cancellation not permitted, TAT over.", "result": "[]" } ], "isSuccess": false, "message": "..." }
/// ```
class CancelScheduleConfirmationResponse {
  /// `0` means the popup config is valid and the dialog should be shown.
  final int errorCode;

  /// Human-readable message. On failure (`errorCode != 0`) this is what should
  /// be surfaced to the user instead of opening the dialog.
  final String dbResponse;

  /// The popup configuration; `null` on failure / empty result.
  final CancelSchedulePopup? popup;

  const CancelScheduleConfirmationResponse({
    required this.errorCode,
    required this.dbResponse,
    this.popup,
  });

  /// `true` when the backend returned a usable popup config.
  bool get isSuccess => errorCode == 0 && popup != null;

  factory CancelScheduleConfirmationResponse.fromJson(
      Map<String, dynamic> json) {
    // Unwrap the outer envelope: prefer `result[0]`, fall back to the top-level
    // map for flat/legacy shapes.
    Map<String, dynamic> inner = json;
    final rawEnvelope = json['result'] ?? json['Result'];
    if (rawEnvelope is List &&
        rawEnvelope.isNotEmpty &&
        rawEnvelope.first is Map) {
      inner = Map<String, dynamic>.from(rawEnvelope.first as Map);
    } else if (rawEnvelope is Map) {
      inner = Map<String, dynamic>.from(rawEnvelope);
    }

    final rawError = inner['errorCode'] ?? inner['ErrorCode'];
    final errorCode = rawError is num
        ? rawError.toInt()
        : int.tryParse(rawError?.toString() ?? '') ?? -1;
    final dbResponse = (inner['dB_Response'] ??
            inner['DB_Response'] ??
            inner['dbResponse'] ??
            '')
        .toString()
        .trim();

    // The inner `result` is a JSON-encoded string holding the popup config
    // array (may also arrive already-decoded as a List/Map).
    final popup = _parsePopup(inner['result'] ?? inner['Result']);

    return CancelScheduleConfirmationResponse(
      errorCode: errorCode,
      dbResponse: dbResponse,
      popup: popup,
    );
  }

  /// Decodes the nested popup config from a JSON string (or an
  /// already-decoded List/Map) into a [CancelSchedulePopup].
  static CancelSchedulePopup? _parsePopup(Object? raw) {
    if (raw == null) return null;
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (decoded is List) {
      if (decoded.isEmpty || decoded.first is! Map) return null;
      return CancelSchedulePopup.fromJson(
          Map<String, dynamic>.from(decoded.first as Map));
    }
    if (decoded is Map) {
      return CancelSchedulePopup.fromJson(Map<String, dynamic>.from(decoded));
    }
    return null;
  }
}

/// A single popup configuration (from `Result[0]`).
class CancelSchedulePopup {
  final String popupId;
  final String icon;
  final String title;
  final String message;

  /// Buttons already sorted by ascending [CancelScheduleButton.order].
  final List<CancelScheduleButton> buttons;

  const CancelSchedulePopup({
    required this.popupId,
    required this.icon,
    required this.title,
    required this.message,
    required this.buttons,
  });

  factory CancelSchedulePopup.fromJson(Map<String, dynamic> json) {
    final rawButtons = json['buttons'] ?? json['Buttons'];
    final buttons = <CancelScheduleButton>[];
    if (rawButtons is List) {
      for (final b in rawButtons) {
        if (b is Map) {
          buttons.add(
              CancelScheduleButton.fromJson(Map<String, dynamic>.from(b)));
        }
      }
    }
    // Render in ascending `order`. Stable so equal orders keep API order.
    buttons.sort((a, b) => a.order.compareTo(b.order));

    return CancelSchedulePopup(
      popupId: (json['popupId'] ?? json['PopupId'] ?? '').toString(),
      icon: (json['icon'] ?? json['Icon'] ?? '').toString(),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      message: (json['message'] ?? json['Message'] ?? '').toString(),
      buttons: buttons,
    );
  }
}

/// The action a [CancelScheduleButton] triggers.
enum CancelScheduleAction {
  cancelSchedule,
  markNoShow,
  dismiss,

  /// Any action string the app doesn't recognise. Treated as a no-op so a new
  /// backend action never crashes the dialog.
  unknown;

  static CancelScheduleAction fromString(String raw) {
    // Normalise so backend variants (case / snake_case / alternate wording)
    // can never silently fall through to `unknown` and skip the cancel API.
    final normalised = raw.trim().toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');
    switch (normalised) {
      case 'cancelschedule':
      case 'cancel':
      case 'canceltrip':
      case 'cancelride':
      case 'confirm':
        return CancelScheduleAction.cancelSchedule;
      case 'marknoshow':
      case 'noshow':
        return CancelScheduleAction.markNoShow;
      case 'dismiss':
      case 'goback':
      case 'keeptrip':
      case 'cancel_dismiss':
        return CancelScheduleAction.dismiss;
      default:
        return CancelScheduleAction.unknown;
    }
  }
}

/// A single dialog button returned by the API.
class CancelScheduleButton {
  final String id;
  final String text;
  final CancelScheduleAction action;
  final int order;

  const CancelScheduleButton({
    required this.id,
    required this.text,
    required this.action,
    required this.order,
  });

  factory CancelScheduleButton.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'] ?? json['Order'];
    final order = rawOrder is num
        ? rawOrder.toInt()
        : int.tryParse(rawOrder?.toString() ?? '') ?? 0;
    return CancelScheduleButton(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      text: (json['text'] ?? json['Text'] ?? '').toString(),
      action: CancelScheduleAction.fromString(
          (json['action'] ?? json['Action'] ?? '').toString()),
      order: order,
    );
  }
}
