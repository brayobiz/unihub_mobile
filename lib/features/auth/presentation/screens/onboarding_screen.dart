import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/notification_service.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _localLoading = false;

  void _onGetStarted() async {
    setState(() => _localLoading = true);
    
    // Prompt for notifications
    await ref.read(notificationServiceProvider).requestPermission();
    
    await ref.read(authControllerProvider.notifier).completeOnboarding();

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        setState(() => _localLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error.toString().replaceAll('Exception: ', ''))),
        );
      }
      // Success will be handled by the router redirection logic
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.rocket_launch_rounded,
                size: 120,
                color: Color(0xFF388E3C),
              ),
              const SizedBox(height: 40),
              const Text(
                'Ready to Explore?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Now that your profile is set, explore the marketplace, find the best student housing, and share notes with your peers.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              
              if (_localLoading)
                const CircularProgressIndicator()
              else
                AuthButton(
                  text: 'Get Started',
                  onPressed: _onGetStarted,
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
