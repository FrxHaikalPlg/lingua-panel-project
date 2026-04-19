import 'package:linguapanel/core/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:linguapanel/features/auth/viewmodel/login_viewmodel.dart';
import 'package:linguapanel/features/auth/view/forgot_password_page.dart';
import 'package:provider/provider.dart';

class LoginView extends StatelessWidget {
  final Function()? onTap;
  const LoginView({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<LoginViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UIHelpers.showErrorSnackBar(context, viewModel.errorMessage!);
              viewModel.setErrorMessage(null);
            });
          }
          return Stack(
            children: [
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        // logo
                        Image.asset(
                          'lib/images/logo.png',
                          height: 100,
                        ),
                        const SizedBox(height: 50),
                        // welcome back, you've been missed!
                        Text(
                          "Welcome back, you've been missed!",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 25),
                        // email textfield
                        TextField(
                          controller: viewModel.emailController,
                          decoration: const InputDecoration(hintText: 'Email'),
                          obscureText: false,
                        ),
                        const SizedBox(height: 10),
                        // password textfield
                        TextField(
                          controller: viewModel.passwordController,
                          decoration:
                              const InputDecoration(hintText: 'Password'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 10),
                        // forgot password?
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return const ForgotPasswordPage();
                                    },
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        // sign in button
                        ElevatedButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () => viewModel.signInWithEmailPassword(),
                          child: const Text("Sign In"),
                        ),
                        const SizedBox(height: 25),
                        // or continue with
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 0.5,
                                color: Colors.grey[400],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                'Or continue with',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 0.5,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        // google sign in button
                        ElevatedButton.icon(
                          onPressed: viewModel.isLoading
                              ? null
                              : () => viewModel.signInWithGoogle(),
                          icon:
                              Image.asset('lib/images/google.png', height: 24),
                          label: const Text('Sign In with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(height: 50),
                        // not a member? register now
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Not a member?',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: onTap,
                              child: Text(
                                'Register now',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              if (viewModel.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
