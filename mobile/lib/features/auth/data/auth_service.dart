import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../domain/teacher.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;
}

class AuthService {
  AuthService({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.defaultBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;
  List<Teacher>? _cachedTeachers;
  DateTime? _lastFetched;

  Future<Teacher> login({required String name, required String cin}) async {
    final normalizedName = _normalizeName(name);
    final normalizedCin = cin.trim().toUpperCase();

    if (normalizedName.isEmpty || normalizedCin.isEmpty) {
      throw AuthException('Both name and CIN are required.');
    }

    final teachers = await _loadTeachers();

    for (final teacher in teachers) {
      final teacherName = _normalizeName(teacher.nom);
      final teacherCin = teacher.cin.trim().toUpperCase();
      if (teacherName == normalizedName && teacherCin == normalizedCin) {
        return teacher;
      }
    }

    final refreshed = await _loadTeachers(forceRefresh: true);
    for (final teacher in refreshed) {
      final teacherName = _normalizeName(teacher.nom);
      final teacherCin = teacher.cin.trim().toUpperCase();
      if (teacherName == normalizedName && teacherCin == normalizedCin) {
        return teacher;
      }
    }

    throw AuthException('No teacher matched the provided name and CIN.');
  }

  Future<Teacher?> getTeacherById(String id) async {
    if (id.isEmpty) {
      return null;
    }

    final teachers = await _loadTeachers();
    for (final teacher in teachers) {
      if (teacher.id == id) {
        return teacher;
      }
    }

    final refreshed = await _loadTeachers(forceRefresh: true);
    for (final teacher in refreshed) {
      if (teacher.id == id) {
        return teacher;
      }
    }

    return null;
  }

  Future<List<Teacher>> _loadTeachers({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _cachedTeachers != null && _lastFetched != null) {
      final age = now.difference(_lastFetched!);
      if (age.inMinutes < 10) {
        return _cachedTeachers!;
      }
    }

    final teachers = await _fetchTeachers();
    _cachedTeachers = teachers;
    _lastFetched = now;
    return teachers;
  }

  Future<List<Teacher>> _fetchTeachers() async {
    try {
      final response = await _dio.get<List<dynamic>>('/teachers');
      final raw = response.data ?? const [];

      final teachers =
          raw
              .whereType<Map<String, dynamic>>()
              .map(Teacher.fromJson)
              .where(
                (teacher) =>
                    teacher.id.isNotEmpty &&
                    teacher.cin.trim().isNotEmpty &&
                    teacher.nom.trim().isNotEmpty,
              )
              .toList();

      if (teachers.isEmpty) {
        throw AuthException('No teachers available. Contact an administrator.');
      }

      return teachers;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) {
        throw AuthException('No teacher directory configured.');
      }

      final detail = error.response?.data;
      if (detail is Map<String, dynamic>) {
        final message = detail['detail'] as String?;
        if (message != null && message.isNotEmpty) {
          throw AuthException(message);
        }
      }

      throw AuthException('Unable to reach the teacher directory.');
    } catch (error) {
      if (error is AuthException) {
        rethrow;
      }
      throw AuthException('Unexpected error while loading teachers.');
    }
  }

  void clearCache() {
    _cachedTeachers = null;
    _lastFetched = null;
  }

  void updateBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty || _dio.options.baseUrl == normalized) {
      return;
    }
    _dio.options.baseUrl = normalized;
    clearCache();
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
