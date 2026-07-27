import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/models/announcement.dart';
import '../../../navigation/navigation_providers.dart';

/// A centralized, invisible widget that manages the display of modal announcements.
/// Prevents multiple dialogs from stacking and ensures "Happy User" experience.
class AnnouncementModalOrchestrator extends ConsumerWidget {
  const AnnouncementModalOrchestrator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Determine active feature context from navigation
    final navIndex = ref.watch(mainNavigationIndexProvider);
    String? feature;
    switch (navIndex) {
      case 1: feature = 'marketplace'; break;
      case 2: feature = 'housing'; break;
      case 3: feature = 'notes'; break;
      case 4: feature = 'chat'; break;
      default: feature = null; // Dashboard / Global
    }

    // 2. Watch for relevant announcements and the modal lock
    final announcements = ref.watch(relevantAnnouncementsProvider(feature));
    final dismissed = ref.watch(dismissedAnnouncementsProvider);
    final sessionShown = ref.watch(sessionShownModalsProvider);
    final isModalActive = ref.watch(isAnnouncementModalActiveProvider);

    // 3. Find modals that need to be shown
    final pendingModals = announcements.where((a) => 
      a.displayStyle == AnnouncementDisplayStyle.modal && 
      !dismissed.contains(a.id) &&
      !sessionShown.contains(a.id)
    ).toList();

    // 4. Trigger logic: only if no modal is currently showing
    if (pendingModals.isNotEmpty && !isModalActive) {
      final target = pendingModals.first;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Re-verify conditions inside the callback to be thread-safe
        final currentSessionShown = ref.read(sessionShownModalsProvider);
        final currentIsActive = ref.read(isAnnouncementModalActiveProvider);
        
        if (!currentSessionShown.contains(target.id) && !currentIsActive) {
          _showAnnouncementModal(context, ref, target);
        }
      });
    }

    return const SizedBox.shrink();
  }

  void _showAnnouncementModal(BuildContext context, WidgetRef ref, Announcement a) {
    // Acquire lock and mark as session-shown immediately
    ref.read(isAnnouncementModalActiveProvider.notifier).state = true;
    ref.read(sessionShownModalsProvider.notifier).update((s) => {...s, a.id});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false, // User must interact with the button
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.title, 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            a.content, 
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: FilledButton(
                onPressed: () {
                  // Permanently dismiss from shared preferences
                  ref.read(dismissedAnnouncementsProvider.notifier).dismiss(a.id);
                  // Release lock and close
                  ref.read(isAnnouncementModalActiveProvider.notifier).state = false;
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Got it, thanks!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Safety: ensuring lock is released even if pop happens via other means
      if (ref.read(isAnnouncementModalActiveProvider)) {
        ref.read(isAnnouncementModalActiveProvider.notifier).state = false;
      }
    });
  }
}
