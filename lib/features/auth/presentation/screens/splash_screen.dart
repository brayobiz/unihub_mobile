import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Show the branded logo from assets with safety fallback
              SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/icon/campus_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to a themed icon if the asset is missing
                    return Icon(
                      Icons.school_rounded,
                      size: 100,
                      color: theme.colorScheme.primary,
                    );
                  },
                ),
              ),
              const SizedBox(height: 64),
              CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
