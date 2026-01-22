class AppConfig {
  AppConfig._();

  static const String defaultBaseUrl = 'http://192.168.1.16:8001';

  static bool isValidBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }

    final hasScheme =
        uri.hasScheme && (uri.isScheme('http') || uri.isScheme('https'));
    final hasHost = uri.host.isNotEmpty;
    return hasScheme && hasHost;
  }
}
