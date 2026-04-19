import 'package:linguapanel/core/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:linguapanel/features/auth/viewmodel/register_viewmodel.dart';
import 'package:provider/provider.dart';

class RegisterView extends StatelessWidget {
  final Function()? onTap;
  const RegisterView({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<RegisterViewModel>(
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
                        const SizedBox(height: 25),
                        // logo
                        Image.asset(
                          'lib/images/logo.png',
                          height: 100,
                        ),
                        const SizedBox(height: 25),
                        // let's create an account for you
                        Text(
                          'Let\'s create an account for you!',
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
                        // confirm password textfield
                        TextField(
                          controller: viewModel.confirmPasswordController,
                          decoration: const InputDecoration(
                              hintText: 'Confirm Password'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 25),
                        // sign up button
                        ElevatedButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () async {
                                  bool success = await viewModel.register();
                                  if (success && context.mounted) {
                                    await showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Verify Your Email'),
                                        content: const Text(
                                            'A verification link has been sent to your email address. Please check your inbox to continue.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                          child: const Text("Sign Up"),
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
                          label: const Text('Sign Up with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(height: 50),
                        // already have an account? login now
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: onTap,
                              child: Text(
                                'Login now',
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