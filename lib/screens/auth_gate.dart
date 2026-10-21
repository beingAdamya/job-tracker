import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/account.dart';
import '../services/auth_service.dart';
import '../services/firebase_boot.dart';
import '../theme/theme_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

// Decides which screen to show (login, verify email, or the app), and
// makes sure the app is using the signed-in account's saved data
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _activeUid; // whose data is loaded right now
  bool _switching = false;

  // Loads the data of whoever is signed in (or unloads it after sign-out)
  Future<void> _syncAccount() async {
    if (_switching) return;
    _switching = true;

    while (true) {
      final user = AuthService.user;
      final wanted = (user != null && user.emailVerified) ? user.uid : null;
      if (wanted == _activeUid) break;

      await Account.activate(wanted);
      if (wanted == null) {
        ThemeController.instance.apply(AppSettings()); // default look
      } else {
        await ThemeController.instance.load(); // this account's look
      }
      _activeUid = wanted;
    }

    _switching = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseBoot.ready) return _setupProblem();

    return StreamBuilder<User?>(
      stream: AuthService.changes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        // Read the freshest copy: "verified" can change without the stream firing
        final user = AuthService.user;
        final wanted = (user != null && user.emailVerified) ? user.uid : null;

        if (wanted != _activeUid) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncAccount());
          if (wanted != null) return _loading(); // wait for their data
        }

        if (user == null) return const LoginScreen();

        if (!user.emailVerified) {
          return VerifyEmailScreen(onVerified: () => setState(() {}));
        }

        return const HomeScreen();
      },
    );
  }

  Widget _loading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _setupProblem() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Sign-in is not available',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'The sign-in service could not start. Check that the app is set up with Firebase.\n\n${FirebaseBoot.error ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await FirebaseBoot.init();
                    if (mounted) setState(() {});
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}