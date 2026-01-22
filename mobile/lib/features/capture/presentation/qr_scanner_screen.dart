import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_controller.dart';
import '../application/capture_workflow_controller.dart';
import '../data/face_capture_service.dart';
import '../domain/capture_session_payload.dart';
import 'qr_session_capture_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _processing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_processing) {
      return;
    }

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        rawValue = value;
        break;
      }
    }

    if (rawValue == null) {
      return;
    }

    final payload = _parsePayload(rawValue);
    if (payload == null) {
      setState(() => _errorMessage = 'Unrecognized QR code.');
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final service = context.read<FaceCaptureService>();
    try {
      if (payload.apiBaseUrl != null &&
          AppConfig.isValidBaseUrl(payload.apiBaseUrl!)) {
        await context.read<ConfigController>().updateBaseUrl(
          payload.apiBaseUrl!,
        );
      }

      final session = await service.fetchCaptureSession(payload.token);
      if (!mounted) {
        return;
      }

      context.read<CaptureWorkflowController>().activate(
        session,
        payload.token,
      );
      await _controller.stop();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => QrSessionCaptureScreen(
                session: session,
                token: payload.token,
              ),
        ),
      );
    } on FaceCaptureException catch (error) {
      setState(() {
        _processing = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _processing = false;
        _errorMessage = 'Failed to fetch capture session.';
      });
    }
  }

  ({String token, String? apiBaseUrl})? _parsePayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final maybeToken = uri.pathSegments.last;
      if (maybeToken.isNotEmpty) {
        final api = uri.queryParameters['api'];
        return (token: maybeToken, apiBaseUrl: api);
      }
    }

    if (trimmed.contains('-')) {
      return (token: trimmed, apiBaseUrl: null);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Session QR'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleDetection,
                ),
                if (_processing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Align the QR code within the frame to load the capture session.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
