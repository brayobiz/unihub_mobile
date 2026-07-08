import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: FilledButton(
        onPressed: (onPressed == null || isLoading) 
          ? null 
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
        child: isLoading 
          ? const SizedBox(
              height: 20, 
              width: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            )
          : Text(text),
      ),
    );
  }
}
