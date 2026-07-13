import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEnabled = onPressed != null;
    
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(
            color: isEnabled 
                ? theme.dividerColor.withValues(alpha: 0.5) 
                : theme.dividerColor.withValues(alpha: 0.2),
          ),
          backgroundColor: isEnabled ? theme.cardColor : theme.colorScheme.surfaceVariant.withValues(alpha: 0.2),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login_rounded, 
              size: 20, 
              color: isEnabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Text(
              "Continue with Google",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isEnabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
