import 'package:flutter/material.dart';

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
    return TextField(
      controller: widget.controller,
      obscureText: obscureText,
      enabled: widget.enabled,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () {
            setState(() {
              obscureText = !obscureText;
            });
          },
        ),
      ),
    );
  }
}