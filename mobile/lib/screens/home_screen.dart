import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSignOut, this.onOpenSos});

  /// Shown as a "Sign out" button when provided.
  final VoidCallback? onSignOut;

  /// Shown as the prominent SOS entry point when provided.
  final VoidCallback? onOpenSos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Scrolls on small screens / large text; the actions below stay put.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 64, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConstants.tagline,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (onOpenSos != null) ...[
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 8,
                          children: const [
                            _EmergencyHint(
                                icon: Icons.local_fire_department,
                                label: 'Fire emergency'),
                            _EmergencyHint(
                                icon: Icons.pool, label: 'Drowning emergency'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppConstants.homeGuidance,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (onOpenSos != null || onSignOut != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (onOpenSos != null)
                      FilledButton.icon(
                        key: const Key('open_sos_button'),
                        onPressed: onOpenSos,
                        icon: const Icon(Icons.sos, size: 32),
                        label: const Text('SEND SOS'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          minimumSize: const Size.fromHeight(80),
                          textStyle: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (onSignOut != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('sign_out_button'),
                        onPressed: onSignOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Non-interactive reminder of what the SOS covers.
class _EmergencyHint extends StatelessWidget {
  const _EmergencyHint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
