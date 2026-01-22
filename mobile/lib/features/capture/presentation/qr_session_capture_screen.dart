import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/capture_workflow_controller.dart';
import '../domain/capture_session_payload.dart';
import 'camera_capture_view.dart';

class QrSessionCaptureScreen extends StatelessWidget {
  const QrSessionCaptureScreen({
    super.key,
    required this.session,
    required this.token,
  });

  final CaptureSessionPayload session;
  final String token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Capture'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () {
            context.read<CaptureWorkflowController>().clear();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.nomSeance, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Class: ${session.classe}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${session.date.toLocal()}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (session.profReference.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Prof Ref: ${session.profReference}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text('Token: $token', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CameraCaptureView(session: session, captureToken: token),
            ],
          ),
        ),
      ),
    );
  }
}
