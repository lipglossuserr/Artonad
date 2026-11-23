import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// Shown instead of the app when the build configuration is invalid (for
/// example a release build without an https API_BASE_URL). The app never
/// reaches login or the network in this state.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'App configuration error',
                    key: Key('config_error_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(message,
                      key: const Key('config_error_message'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text(
                    'This build cannot be used. Please install a correctly '
                    'configured version.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
