import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../core/widgets/error_view.dart';

class ConnectionErrorScreen extends ConsumerWidget {
  const ConnectionErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorView(
      message: 'Unable to connect to campus services. Please check your internet and try again.',
      onRetry: () {
        // Force refresh core providers
        ref.invalidate(authStateProvider);
        ref.invalidate(appUserProvider);
      },
    );
  }
}
