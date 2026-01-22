import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../capture/domain/capture_session_payload.dart';

class SessionServiceException implements Exception {
  SessionServiceException(this.message);

  final String message;
}

class SessionService extends ChangeNotifier {
  SessionService({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.defaultBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final Dio _dio;

  Future<List<CaptureSessionPayload>> fetchSessions({
    String? professorId,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/sessions',
        queryParameters: professorId == null ? null : {'prof': professorId},
      );

      final rawList = response.data ?? [];
      final sessions =
          rawList
              .whereType<Map<String, dynamic>>()
              .map(CaptureSessionPayload.fromJson)
              .toList();

      sessions.sort((a, b) => b.date.compareTo(a.date));
      return sessions;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) {
        return [];
      }
      final message = error.response?.data;
      if (message is Map<String, dynamic>) {
        final detail = message['detail'] as String?;
        if (detail != null && detail.isNotEmpty) {
          throw SessionServiceException(detail);
        }
      }
      throw SessionServiceException(
        'Failed to load sessions. Please try again.',
      );
    } catch (_) {
      throw SessionServiceException('Unexpected error while loading sessions.');
    }
  }

  void updateBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty || _dio.options.baseUrl == normalized) {
      return;
    }
    _dio.options.baseUrl = normalized;
    notifyListeners();
  }
}
