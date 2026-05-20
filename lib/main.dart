import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/id_generator_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Defense-in-depth: every initialization step is wrapped so that a single
  // plugin or storage failure cannot abort cold-start. Failures are captured
  // and surfaced inside the app rather than producing a blank-screen crash.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Trap framework-level uncaught errors so they never silently kill the
    // launch sequence on physical devices.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    try {
      await Hive.initFlutter();
    } catch (_) {
      // Hive failure is non-fatal — continue with in-memory fallback.
    }

    // Firebase initialization is best-effort: if it fails (no network,
    // misconfigured project, web platform without web app registered), the
    // app continues in fully local mode using Hive only.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}

    final auth = AuthService();
    try {
      await auth.initialize();
    } catch (_) {}

    final data = DataService();
    try {
      await data.initialize();
    } catch (_) {}

    // Wire Firestore sync only after DataService is ready. Hooks set here
    // make every subsequent saveXxx() also propagate to the cloud project.
    final sync = FirebaseSyncService(data);
    try {
      await sync.initialize();
    } catch (_) {}

    final idGenerator = IdGeneratorService();
    try {
      await idGenerator.initialize();
    } catch (_) {}

    final notifications = NotificationService();
    try {
      await notifications.initialize();
    } catch (_) {}

    runApp(NerZeroApp(
      auth: auth,
      data: data,
      idGenerator: idGenerator,
      notifications: notifications,
    ));
  }, (error, stack) {
    // Last-resort fallback: surface a minimal error UI so the user knows the
    // app is alive even if a critical service failed.
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B5E20),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 64),
                const SizedBox(height: 16),
                const Text('NerZero MRV — Startup Issue',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    ));
  });
}

class NerZeroApp extends StatelessWidget {
  final AuthService auth;
  final DataService data;
  final IdGeneratorService idGenerator;
  final NotificationService notifications;
  const NerZeroApp({
    super.key,
    required this.auth,
    required this.data,
    required this.idGenerator,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: data),
        Provider<IdGeneratorService>.value(value: idGenerator),
        ChangeNotifierProvider.value(value: notifications),
      ],
      child: MaterialApp(
        title: 'NerZero MRV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
