import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/shared/providers.dart';
import '../../app/theme/app_colors.dart';

class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isPermanent = user.isBanned;
    final message = isPermanent 
      ? 'Your account has been permanently banned for violating UniHub community standards.'
      : 'Your account is temporarily suspended until ${DateFormat('MMM dd, yyyy').format(user.suspendedUntil ?? DateTime.now())}.';

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            Text(
              isPermanent ? 'Account Banned' : 'Account Suspended',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            if (user.banReason != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Reason: ${user.banReason}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 48),
            const Text(
              'If you believe this is a mistake, please contact support at support@unihub.com',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
