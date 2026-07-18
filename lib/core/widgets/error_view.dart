import 'package:flutter/material.dart';
import '../error/error_handler.dart';

class ErrorView extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? message;
  final bool isFullPage;

  const ErrorView({
    super.key,
    this.error,
    this.onRetry,
    this.message,
    this.isFullPage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String displayMessage = message ?? (error != null ? AppErrorHandler.mapError(error) : 'Something went wrong.');

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isFullPage) {
      return Scaffold(body: SafeArea(child: content));
    }
    return content;
  }
}
