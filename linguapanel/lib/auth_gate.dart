import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:linguapanel/features/auth/view/auth_page.dart';
import 'package:linguapanel/features/auth/view/verify_email_view.dart';
import 'package:linguapanel/features/home/view/home_view.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData) {
          return const AuthPage();
        }

        final user = snapshot.data!;

        // Check if the user is from Google provider
        final isGoogleUser =
            user.providerData.any((info) => info.providerId == 'google.com');

        // User is signed in and email is verified, or is a Google user
        if (user.emailVerified || isGoogleUser) {
          return const HomeView();
        }

        // User is signed in but email is not verified
        return const VerifyEmailView();
      },
    );
  }
}
