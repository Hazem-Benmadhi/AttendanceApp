import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _tokenKey = 'authToken';

abstract class AuthStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

class SecureAuthStorage implements AuthStorage {
  SecureAuthStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  @override
  Future<void> clearToken() => _secureStorage.delete(key: _tokenKey);

  @override
  Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);
}

class InMemoryAuthStorage implements AuthStorage {
  String? _token;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }
}
