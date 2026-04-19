import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linguapanel/core/services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<bool> signInWithEmailPassword() async {
    _setLoading(true);
    setErrorMessage(null);
    try {
      await _authService.signInWithEmailPassword(
        emailController.text,
        passwordController.text,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        setErrorMessage(
            'No internet connection. Please check your connection and try again.');
      } else if (e.code == 'email-not-verified') {
        setErrorMessage('Please verify your email before logging in.');
      } else if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-email') {
        setErrorMessage('Invalid email or password.');
      } else {
        setErrorMessage('An error occurred during sign-in. Please try again.');
      }
      _setLoading(false);
      return false;
    } catch (e) {
      setErrorMessage('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    setErrorMessage(null);
    try {
      await _authService.signInWithGoogle();
      _setLoading(false);
      return true;
    } on PlatformException catch (e) {
      final message = e.message?.toLowerCase() ?? '';
      if (message.contains('network is unreachable') ||
          message.contains('failed host lookup')) {
        setErrorMessage(
            'No internet connection. Please check your connection and try again.');
      } else {
        setErrorMessage('An error occurred during sign-in. Please try again.');
      }
      _setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        setErrorMessage(
            'No internet connection. Please check your connection and try again.');
      } else {
        setErrorMessage('An error occurred during sign-in. Please try again.');
      }
      _setLoading(false);
      return false;
    } catch (e) {
      setErrorMessage('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
