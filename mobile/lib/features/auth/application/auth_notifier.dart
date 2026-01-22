import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../domain/teacher.dart';
import 'auth_storage.dart';

enum AuthStatus { initializing, unauthenticated, loading, authenticated, error }

class AuthController extends ChangeNotifier {
  AuthController({required AuthService authService, AuthStorage? storage})
    : _authService = authService,
      _storage = storage ?? SecureAuthStorage() {
    _restoreSession();
  }

  AuthService _authService;
  final AuthStorage _storage;

  AuthStatus _status = AuthStatus.initializing;
  String? _token;
  String? _errorMessage;
  Teacher? _teacher;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get token => _token;
  Teacher? get teacher => _teacher;

  Future<void> login({required String name, required String cin}) async {
    _setStatus(AuthStatus.loading);
    _errorMessage = null;
    _token = null;
    _teacher = null;
    notifyListeners();

    try {
      final teacher = await _authService.login(name: name, cin: cin);
      _teacher = teacher;
      _token = teacher.id;
      await _storage.writeToken(teacher.id);
      _setStatus(AuthStatus.authenticated);
    } on AuthException catch (error) {
      _errorMessage = error.message;
      _setStatus(AuthStatus.error);
    } catch (_) {
      _errorMessage = 'Unexpected error, please try again.';
      _setStatus(AuthStatus.error);
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _teacher = null;
    await _storage.clearToken();
    _setStatus(AuthStatus.unauthenticated);
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      final storedToken = await _storage.readToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        final teacher = await _authService.getTeacherById(storedToken);
        if (teacher != null) {
          _teacher = teacher;
          _token = storedToken;
          _setStatus(AuthStatus.authenticated);
        } else {
          await _storage.clearToken();
          _setStatus(AuthStatus.unauthenticated);
        }
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (_) {
      _setStatus(AuthStatus.unauthenticated);
    }

    notifyListeners();
  }

  void _setStatus(AuthStatus status) {
    _status = status;
  }

  void updateAuthService(AuthService service) {
    if (!identical(_authService, service)) {
      _authService = service;
    }
  }
}
