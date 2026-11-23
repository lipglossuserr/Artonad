import 'package:flutter/material.dart';

import '../models/incident.dart';

/// Shown after the server confirmed the SOS (HTTP 201). Only tourist-safe
/// information is displayed: id, status and (when present) the zone name.
class SosConfirmationScreen extends StatelessWidget {
  const SosConfirmationScreen({
    super.key,
    required this.incident,
    required this.onSendAnother,
  });

  final Incident incident;
  final void Function(BuildContext context) onSendAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zone = incident.zoneName;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Scrolls on small phones / large text; actions below stay put.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.check_circle, size: 88, color: scheme.primary),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          'SOS sent',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your emergency report has been received.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),

                      // The incident ID: large, high contrast, selectable so
                      // it can be copied or read out.
                      SelectionArea(
                        child: Container(
                          key: const Key('incident_id_card'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: 'Incident ID: ',
                                style: theme.textTheme.titleLarge?.copyWith(
                                    color: scheme.onPrimaryContainer),
                              ),
                              TextSpan(
                                text: '${incident.id}',
                                style: theme.textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onPrimaryContainer),
                              ),
                            ]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(children: [
                                  const TextSpan(text: 'Status: '),
                                  TextSpan(
                                    text: incident.status,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ]),
                                key: const Key('incident_status'),
                                style: theme.textTheme.titleMedium,
                              ),
                              if (zone != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.place_outlined,
                                        color: scheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Zone: $zone',
                                        key: const Key('incident_zone'),
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The one obvious action.
                  FilledButton(
                    key: const Key('back_home_button'),
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    child: const Text('Back to home'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('send_another_button'),
                    onPressed: () => onSendAnother(context),
                    child: const Text('Send another SOS'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
