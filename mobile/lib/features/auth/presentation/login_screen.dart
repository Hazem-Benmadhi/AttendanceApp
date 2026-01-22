import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_controller.dart';
import '../../capture/application/capture_workflow_controller.dart';
import '../../capture/presentation/qr_scanner_screen.dart';
import '../application/auth_notifier.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cinController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cinController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final authController = context.read<AuthController>();
    authController.login(
      name: _nameController.text.trim(),
      cin: _cinController.text.trim().toUpperCase(),
    );
  }

  Future<void> _openServerDialog() async {
    final config = context.read<ConfigController>();
    final controller = TextEditingController(text: config.baseUrl);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backend Server'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://your-host:port',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Base URL is required.';
                }
                if (!AppConfig.isValidBaseUrl(value)) {
                  return 'Enter a valid http(s) URL.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed:
                  () => Navigator.of(context).pop(AppConfig.defaultBaseUrl),
              child: const Text('Reset'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    await config.updateBaseUrl(result);

    if (!mounted) {
      return;
    }

    context.read<CaptureWorkflowController>().clear();
    await context.read<AuthController>().logout();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Backend set to $result')));
  }

  Future<void> _openQrScanner() async {
    context.read<CaptureWorkflowController>().clear();
    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthController>();
    final isLoading = authState.status == AuthStatus.loading;
    final config = context.watch<ConfigController>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                'Welcome Back',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in using your name and CIN to continue.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _openQrScanner,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: const Text('Scan QR for Capture'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openServerDialog,
                    icon: const Icon(Icons.settings_ethernet_outlined),
                    label: const Text('Server'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Backend: ${config.baseUrl}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              if (authState.status == AuthStatus.error &&
                  authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cinController,
                      decoration: const InputDecoration(
                        labelText: 'CIN',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      autofillHints: const [AutofillHints.creditCardNumber],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'CIN is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child:
                            isLoading
                                ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2.5,
                                  ),
                                )
                                : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Need help? Contact the campus administrator.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
