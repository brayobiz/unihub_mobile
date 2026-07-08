import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppButtonType { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonType type;
  final Color? color;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.type = AppButtonType.primary,
    this.color,
    this.width,
    this.height = 55,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget content = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          );

    void handlePress() {
      if (isLoading || onPressed == null) return;
      // Immediate haptic feedback makes the button feel faster
      HapticFeedback.lightImpact();
      onPressed!();
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: _buildButton(context, content, handlePress),
    );
  }

  Widget _buildButton(BuildContext context, Widget content, VoidCallback handlePress) {
    final theme = Theme.of(context);
    
    switch (type) {
      case AppButtonType.primary:
        return ElevatedButton(
          onPressed: onPressed != null ? handlePress : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: content,
        );
      case AppButtonType.secondary:
        return ElevatedButton(
          onPressed: onPressed != null ? handlePress : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? theme.colorScheme.secondary,
            foregroundColor: Colors.white,
          ),
          child: content,
        );
      case AppButtonType.outline:
        return OutlinedButton(
          onPressed: onPressed != null ? handlePress : null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color ?? theme.colorScheme.primary),
            foregroundColor: color ?? theme.colorScheme.primary,
          ),
          child: content,
        );
      case AppButtonType.text:
        return TextButton(
          onPressed: onPressed != null ? handlePress : null,
          style: TextButton.styleFrom(
            foregroundColor: color ?? theme.colorScheme.primary,
          ),
          child: content,
        );
    }
  }
}
