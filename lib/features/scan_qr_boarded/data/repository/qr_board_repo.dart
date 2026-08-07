import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_constants.dart';
import '../model/qr_board_response.dart';

/// Boards the user by posting the scanned cab QR to `{appBasePath}/qr-board`.
///
/// NOTE: this endpoint sits at the host root, *not* under the `/api/v1` prefix
/// the rest of the app APIs use, so the full URL is passed explicitly. The
/// injected [ApiClient] is still used so the request picks up the shared auth
/// header + token-refresh interceptor.
class QrBoardRepo {
  final ApiClient _apiClient;

  QrBoardRepo(this._apiClient);

  static const String _url = '${ApiConstants.qrBoardBaseUrl}/qr-board';

  Future<QrBoardResponse> qrBoard({
    required int dsId,
    required int empId,
    required String qrCode,
    required double lat,
    required double lng,
  }) async {
    final body = {
      'dsId': dsId,
      'empId': empId,
      'qrCode': qrCode,
      'lat': lat,
      'lng': lng,
    };

    debugPrint('[QR_BOARD] → POST $_url body=$body');

    final response = await _apiClient.dio.post<dynamic>(_url, data: body);

    debugPrint(
      '[QR_BOARD] ← status=${response.statusCode} data=${response.data}',
    );

    return QrBoardResponse.fromRaw(
      response.data,
      statusCode: response.statusCode,
    );
  }
}
