import 'package:flutter/material.dart';
// Import your existing SignInPage and SignUpPage classes
import 'signin.dart'; // Adjust the import path as needed

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignInMode = true;

  void _switchToSignUp() {
    setState(() {
      _isSignInMode = false;
    });
  }

  void _switchToSignIn() {
    setState(() {
      _isSignInMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isSignInMode
        ? SignInPage(onSwitchToSignUp: _switchToSignUp)
        : SignUpPage(onSwitchToSignIn: _switchToSignIn);
  }
}