import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../model/chat_message.dart';
import '../model/chat_message_request.dart';

class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository(this._apiClient);

  /// POST /ApiChatting/CreateChatMessage
  Future<bool> sendMessage(ChatMessageRequest request) async {
    const path = '/ApiChatting/CreateChatMessage';
    debugPrint('[ChatRepo] sendMessage → $path body=${request.toJson()}');
    try {
      await _apiClient.post(path, data: request.toJson());
      return true;
    } on NetworkException catch (e) {
      debugPrint('[ChatRepo] sendMessage NetworkException: ${e.message}');
      return false;
    } on BadRequestException catch (e) {
      debugPrint('[ChatRepo] sendMessage BadRequestException: ${e.message}');
      return false;
    } on ServerException catch (e) {
      debugPrint('[ChatRepo] sendMessage ServerException: ${e.title}');
      return false;
    } catch (e) {
      debugPrint('[ChatRepo] sendMessage error: $e');
      return false;
    }
  }

  /// GET /ApiChatting/ViewChatMessage/{tripId}/{empId1}/{empId2}
  Future<List<ChatMessage>> getMessages({
    required int tripId,
    required int empId1,
    required int empId2,
  }) async {
    final path = '/ApiChatting/ViewChatMessage/$tripId/$empId1/$empId2';
    debugPrint('[ChatRepo] getMessages → GET $path');
    try {
      final response = await _apiClient.dio.get<dynamic>(path);
      final raw = response.data;
      final list = raw is List ? raw : (raw is Map ? raw['data'] : null);
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } on NetworkException catch (e) {
      debugPrint('[ChatRepo] getMessages NetworkException: ${e.message}');
      return [];
    } on ServerException catch (e) {
      debugPrint('[ChatRepo] getMessages ServerException: ${e.title}');
      return [];
    } catch (e) {
      debugPrint('[ChatRepo] getMessages error: $e');
      return [];
    }
  }

  /// GET /ApiChatting/unread/{empId}
  Future<int> getUnreadCount(int empId) async {
    final path = '/ApiChatting/unread/$empId';
    debugPrint('[ChatRepo] getUnreadCount → GET $path');
    try {
      final json = await _apiClient.get(path);
      return (json['data'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[ChatRepo] getUnreadCount error: $e');
      return 0;
    }
  }

  /// PUT /ApiChatting/markread/{tripId}/{senderEmpId}/{recipientEmpId}
  Future<void> markMessagesRead({
    required int tripId,
    required int senderEmpId,
    required int recipientEmpId,
  }) async {
    final path = '/ApiChatting/markread/$tripId/$senderEmpId/$recipientEmpId';
    debugPrint('[ChatRepo] markMessagesRead → PUT $path');
    try {
      await _apiClient.dio.put<dynamic>(path);
    } catch (e) {
      debugPrint('[ChatRepo] markMessagesRead error: $e');
    }
  }
}
