import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../admin/shared/providers.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(systemSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.build_circle_outlined,
                size: 100,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Under Maintenance',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              settingsAsync.when(
                data: (settings) => Text(
                  settings.maintenanceMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text(
                  'UniHub is currently under maintenance. We\'ll be back shortly!',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => ref.invalidate(systemSettingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
