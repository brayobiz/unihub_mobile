import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Displays a prominent disclosure dialog as required by Google Play policies.
  /// This must be shown BEFORE the system permission request for sensitive permissions like Location.
  static Future<bool> showProminentDisclosure(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No Thanks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.status;
    if (status.isGranted) return true;

    final shouldShowDisclosure = await showProminentDisclosure(
      context,
      title: 'Location Access',
      message: 'Ulify uses your location to show listings and campus events nearest to you. This data is only used while the app is in use.',
      icon: Icons.location_on_outlined,
    );

    if (shouldShowDisclosure) {
      final newStatus = await Permission.location.request();
      return newStatus.isGranted;
    }

    return false;
  }
}
