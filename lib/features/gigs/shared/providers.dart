import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../../shared/notification_repository.dart';
import '../data/repositories/gigs_repository_impl.dart';
import '../domain/repositories/gigs_repository.dart';

final gigsRepositoryProvider = Provider<GigsRepository>((ref) {
  return GigsRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationRepositoryProvider),
  );
});
