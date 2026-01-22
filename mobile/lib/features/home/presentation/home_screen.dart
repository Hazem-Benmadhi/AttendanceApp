import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_notifier.dart';
import '../../capture/domain/capture_session_payload.dart';
import '../../capture/presentation/camera_capture_view.dart';
import '../data/session_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CaptureSessionPayload? _session;
  bool _loadingSessions = false;

  void _signOut() {
    context.read<AuthController>().logout();
  }

  Future<void> _selectSession() async {
    if (_loadingSessions) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final teacher = context.read<AuthController>().teacher;
    setState(() => _loadingSessions = true);

    try {
      final sessionService = context.read<SessionService>();
      final sessions = await sessionService.fetchSessions(
        professorId: teacher?.id,
      );

      if (!mounted) {
        return;
      }

      if (sessions.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No sessions available right now.')),
        );
        return;
      }

      final selected = await showModalBottomSheet<CaptureSessionPayload>(
        context: context,
        isScrollControlled: true,
        builder:
            (_) => _SessionPickerSheet(
              sessions: sessions,
              initialSelection: _session,
            ),
      );

      if (selected != null) {
        setState(() => _session = selected);
      }
    } on SessionServiceException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to load sessions. Please retry.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSessions = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacher = context.watch<AuthController>().teacher;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Capture'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (teacher != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacher.nom,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (teacher.matiere != null &&
                                teacher.matiere!.isNotEmpty)
                              Text(
                                teacher.matiere!,
                                style: theme.textTheme.bodySmall,
                              ),
                            Text(
                              'CIN: ${teacher.cin}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _SessionSummaryCard(session: _session, onEdit: _selectSession),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadingSessions ? null : _selectSession,
                icon:
                    _loadingSessions
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.event_note_outlined),
                label: Text(
                  _session == null ? 'Select Session' : 'Change Session',
                ),
              ),
              const SizedBox(height: 32),
              if (_session != null)
                CameraCaptureView(session: _session)
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session required',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose an existing session to enable the camera capture workflow.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.session, required this.onEdit});

  final CaptureSessionPayload? session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (session == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No session selected. Choose a session to enable the camera.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final payload = session!;
    final date = payload.date.toLocal();
    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payload.nomSeance,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Change session',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SessionField(label: 'Class', value: payload.classe),
          const SizedBox(height: 8),
          _SessionField(label: 'Professor Ref', value: payload.profReference),
          const SizedBox(height: 8),
          _SessionField(label: 'Date', value: dateLabel),
          const SizedBox(height: 8),
          _SessionField(label: 'Session ID', value: payload.id),
        ],
      ),
    );
  }
}

class _SessionField extends StatelessWidget {
  const _SessionField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _SessionPickerSheet extends StatelessWidget {
  const _SessionPickerSheet({required this.sessions, this.initialSelection});

  final List<CaptureSessionPayload> sessions;
  final CaptureSessionPayload? initialSelection;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: mediaQuery.viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select session',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isSelected = initialSelection?.id == session.id;
                  final subtitle =
                      '${session.classe} • ${_formatDate(session.date)}';

                  return ListTile(
                    title: Text(session.nomSeance),
                    subtitle: Text(subtitle),
                    trailing:
                        isSelected
                            ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                            : null,
                    onTap: () => Navigator.of(context).pop(session),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
