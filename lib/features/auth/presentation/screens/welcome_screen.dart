import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                size: 100,
                color: Colors.green.shade700,
              ),

              const SizedBox(height: 30),

              const Text(
                'Welcome to UniHub',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Your Campus, Your Opportunities',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 50),

              AuthButton(
                text: 'Sign In',
                onPressed: () {
                  context.push('/login');
                },
              ),

              const SizedBox(height: 16),

              AuthButton(
                text: 'Create Account',
                onPressed: () {
                  context.push('/register');
                },
              ),

              const SizedBox(height: 24),

              // Note: Guest mode is disabled to ensure strict auth flow as requested
              // TextButton(
              //   onPressed: () {
              //     context.go('/main');
              //   },
              //   child: const Text(
              //     'Continue as Guest',
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}