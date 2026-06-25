import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            const Icon(
              Icons.mark_email_read_outlined,
              size: 120,
              color: Colors.green,
            ),

            const SizedBox(height: 30),

            const Text(
              'Verify Your Email',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              'Please check your inbox and verify your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.go('/complete-profile');
                },
                child: const Text('I Have Verified'),
              ),
            ),

            TextButton(
              onPressed: () {},
              child: const Text('Resend Email'),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}