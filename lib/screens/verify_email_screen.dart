import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/layout.dart';

class VerifyEmailScreen extends StatefulWidget {
  final VoidCallback onVerified; // called once Firebase says "verified"

  const VerifyEmailScreen({super.key, required this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _checking = false;
  int _cooldown = 0; // seconds until "Resend" works again

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Look every few seconds, so the screen moves on by itself
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _check(quiet: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Coming back from the email app → look again
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(quiet: true);
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    _checking = true;
    if (!quiet && mounted) setState(() {});

    try {
      final verified = await AuthService.refreshVerified();
      if (!mounted) return;
      if (verified) {
        widget.onVerified();
        return;
      }
      if (!quiet) {
        showAppSnack(context, 'Not verified yet. Tap the link in the email first.');
      }
    } catch (e) {
      if (!quiet && mounted) showAppSnack(context, AuthService.message(e));
    } finally {
      _checking = false;
      if (mounted && !quiet) setState(() {});
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    try {
      await AuthService.sendVerification();
      if (!mounted) return;
      showAppSnack(context, 'Verification email sent');
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, AuthService.message(e));
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.user?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: sidePadding(context, 420),
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to\n$email\n\n'
                  'Open the link (on this phone or any device), then come back here. '
                  'If you cannot find the email, check your spam folder.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _checking ? null : () => _check(),
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("I've verified my email"),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _cooldown > 0 ? null : _resend,
                  child: Text(_cooldown > 0
                      ? 'Resend email (${_cooldown}s)'
                      : 'Resend email'),
                ),
                TextButton(
                  onPressed: () => AuthService.signOut(),
                  child: const Text('Use a different email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}