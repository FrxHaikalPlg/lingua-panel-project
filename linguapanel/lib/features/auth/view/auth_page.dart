import 'package:flutter/material.dart';
import 'package:linguapanel/features/auth/view/login_view.dart';
import 'package:linguapanel/features/auth/view/register_view.dart';
import 'package:linguapanel/features/auth/viewmodel/login_viewmodel.dart';
import 'package:linguapanel/features/auth/viewmodel/register_viewmodel.dart';
import 'package:provider/provider.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Initially, show the login page
  bool showLoginPage = true;

  void toggleScreens() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LoginViewModel()),
        ChangeNotifierProvider(create: (context) => RegisterViewModel()),
      ],
      child: Builder(
        builder: (context) {
          if (showLoginPage) {
            return LoginView(onTap: toggleScreens);
          } else {
            return RegisterView(onTap: toggleScreens);
          }
        },
      ),
    );
  }
}
