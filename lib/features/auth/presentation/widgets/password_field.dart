import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: widget.controller,
      obscureText: obscureText,
      enabled: widget.enabled,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.primary.withValues(alpha: 0.7), size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            size: 20,
          ),
          onPressed: () {
            setState(() {
              obscureText = !obscureText;
            });
          },
        ),
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
