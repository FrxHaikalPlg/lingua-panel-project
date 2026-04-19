import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:linguapanel/core/services/auth_service.dart';
import 'package:linguapanel/core/utils/ui_helpers.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  final AuthService _authService = AuthService();
  bool _isSending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified ?? false) {
        timer.cancel();
        // AuthGate will handle navigation
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'lib/images/logo.png',
                height: 100,
              ),
              const SizedBox(height: 25),
              Text(
                'Please verify your email address',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                'A verification link has been sent to ${FirebaseAuth.instance.currentUser?.email}. Please check your inbox (and spam folder) to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 35),
              ElevatedButton(
                onPressed: _isSending
                    ? null
                    : () async {
                        setState(() {
                          _isSending = true;
                        });
                        try {
                          await _authService.sendVerificationEmail();
                          if (context.mounted) {
                            UIHelpers.showSuccessSnackBar(
                                context, 'Verification email sent!');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            UIHelpers.showErrorSnackBar(
                                context, 'Error sending email: $e');
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() {
                              _isSending = false;
                            });
                          }
                        }
                      },
                child: Text(_isSending ? 'Sending...' : 'Resend Email'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await _authService.signOut();
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
