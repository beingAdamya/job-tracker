import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'services/background_service.dart';
import 'services/firebase_boot.dart';
import 'services/notification_service.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBoot.init(); // sign-in service
  await ThemeController.instance.load(); // so the first frame has your theme
  await NotificationService.init();
  await BackgroundService.init();
  runApp(const JobTrackerApp());
}

class JobTrackerApp extends StatelessWidget {
  const JobTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;

    // Rebuilds the whole app whenever the theme controller says "changed"
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => MaterialApp(
        title: 'Job Tracker',
        debugShowCheckedModeBanner: false,
        theme: theme.light,
        darkTheme: theme.dark,
        themeMode: theme.mode,
        home: const AuthGate(),
      ),
    );
  }
}