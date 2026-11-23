import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/sos_screen.dart';
import 'services/session_controller.dart';
import 'services/sos_dependencies.dart';

class CoastGuardApp extends StatefulWidget {
  const CoastGuardApp({super.key, required this.sessionController, this.sos});

  final SessionController sessionController;

  /// When null, the SOS entry point is not shown on the home screen.
  final SosDependencies? sos;

  @override
  State<CoastGuardApp> createState() => _CoastGuardAppState();
}

class _CoastGuardAppState extends State<CoastGuardApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_onSessionChanged);
    widget.sessionController.restore();
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Signed out (manually or by a 401): drop any pushed routes such as the
  /// SOS screen so only the login screen remains.
  void _onSessionChanged() {
    if (widget.sessionController.status == SessionStatus.authenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.sessionController;
    final sos = widget.sos;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          switch (session.status) {
            case SessionStatus.unknown:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case SessionStatus.authenticated:
              return HomeScreen(
                onSignOut: session.signOut,
                onOpenSos: sos == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SosScreen(dependencies: sos),
                          ),
                        ),
              );
            case SessionStatus.unauthenticated:
              return LoginScreen(sessionController: session);
          }
        },
      ),
    );
  }
}
