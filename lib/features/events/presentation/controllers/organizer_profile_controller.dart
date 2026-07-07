import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/organizer.dart';
import '../../shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';

class OrganizerProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final String _organizerId;

  OrganizerProfileController(this._ref, this._organizerId) : super(const AsyncValue.data(null));

  Future<void> toggleFollow() async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(organizerRepositoryProvider).toggleFollowOrganizer(user.uid, _organizerId);
    });
  }

  void shareOrganizer(BuildContext context, Organizer organizer) {
    final chatContext = ChatContext(
      type: 'organizer',
      id: organizer.id,
      title: organizer.name,
      thumbnail: organizer.logoUrl,
      metadata: {'bio': organizer.bio},
    );
    
    context.push('/share-to-chat', extra: chatContext);
    _ref.read(organizerRepositoryProvider).incrementShareCount(organizer.id);
  }

  Future<void> contactOrganizer(Organizer organizer) async {
    if (organizer.contactEmail != null) {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: organizer.contactEmail,
        query: _encodeQueryParameters(<String, String>{
          'subject': 'Inquiry from UniHub student',
        }),
      );
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}

final organizerProfileControllerProvider =
    StateNotifierProvider.family<OrganizerProfileController, AsyncValue<void>, String>((ref, organizerId) {
  return OrganizerProfileController(ref, organizerId);
});
