import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../domain/capture_session_payload.dart';

class FaceCaptureException implements Exception {
  FaceCaptureException(this.message);

  final String message;
}

class FaceCaptureService {
  FaceCaptureService({Dio? dio, String? baseUrl})
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

  Future<String> uploadFaceImage({
    required String filePath,
    required CaptureSessionPayload session,
    String? captureToken,
  }) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final image = 'data:image/jpeg;base64,$base64Image';

      return uploadFaceImageBytes(
        base64Image: image,
        session: session,
        captureToken: captureToken,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        throw FaceCaptureException('Session expired. Please sign in again.');
      }
      final responseMessage = error.response?.data;
      if (responseMessage is Map<String, dynamic>) {
        final message = responseMessage['message'] as String?;
        if (message != null && message.isNotEmpty) {
          throw FaceCaptureException(message);
        }
      }
      throw FaceCaptureException('Failed to mark attendance. Try again.');
    } catch (_) {
      throw FaceCaptureException('Unexpected error while marking attendance.');
    }
  }

  Future<String> uploadFaceImageBytes({
    required String base64Image,
    required CaptureSessionPayload session,
    String? captureToken,
  }) async {
    try {
      final payload = <String, dynamic>{
        'image': base64Image,
        'session': session.toJson(),
      };

      if (captureToken != null && captureToken.isNotEmpty) {
        payload['capture_token'] = captureToken;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance/mark',
        data: payload,
      );

      final data = response.data;
      final success = data?['success'] as bool? ?? false;
      final message = data?['message'] as String? ?? 'Attendance processed.';

      if (!success) {
        throw FaceCaptureException(message);
      }

      return message;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        throw FaceCaptureException('Session expired. Please sign in again.');
      }
      final responseMessage = error.response?.data;
      if (responseMessage is Map<String, dynamic>) {
        final message = responseMessage['message'] as String?;
        if (message != null && message.isNotEmpty) {
          throw FaceCaptureException(message);
        }
      }
      throw FaceCaptureException('Failed to mark attendance. Try again.');
    } catch (_) {
      throw FaceCaptureException('Unexpected error while marking attendance.');
    }
  }

  Future<void> notifyCapturePreview({
    required String token,
    required String base64Image,
  }) async {
    try {
      await _dio.post('/capture/upload/$token', data: {'image': base64Image});
    } catch (_) {
      // Ignore preview failures; core capture flow should continue.
    }
  }

  Future<CaptureSessionPayload> fetchCaptureSession(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/capture/session/$token',
      );

      final data = response.data;
      if (data == null) {
        throw FaceCaptureException('Capture session not found.');
      }

      return CaptureSessionPayload.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw FaceCaptureException('Capture session expired or invalid.');
      }
      throw FaceCaptureException('Unable to load capture session.');
    } catch (_) {
      throw FaceCaptureException('Unexpected error while loading session.');
    }
  }

  void updateBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty || _dio.options.baseUrl == normalized) {
      return;
    }
    _dio.options.baseUrl = normalized;
  }
}
