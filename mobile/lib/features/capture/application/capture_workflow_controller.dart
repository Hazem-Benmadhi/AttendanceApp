import 'package:flutter/foundation.dart';

import '../domain/capture_session_payload.dart';

class CaptureWorkflowController extends ChangeNotifier {
  CaptureSessionPayload? _session;
  String? _token;

  CaptureSessionPayload? get session => _session;
  String? get captureToken => _token;
  bool get hasActiveCapture => _session != null && _token != null;

  void activate(CaptureSessionPayload session, String token) {
    _session = session;
    _token = token;
    notifyListeners();
  }

  void clear() {
    if (_session == null && _token == null) {
      return;
    }
    _session = null;
    _token = null;
    notifyListeners();
  }
}
