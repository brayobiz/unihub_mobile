import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/monetization_repository_impl.dart';
import '../domain/repositories/monetization_repository.dart';
import '../domain/models/payment_record.dart';
import '../domain/models/subscription_record.dart';

final monetizationRepositoryProvider = Provider<MonetizationRepository>((ref) {
  return MonetizationRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final userPaymentsProvider = StreamProvider.autoDispose<List<PaymentRecord>>((ref) {
  final uid = ref.watch(appUserProvider.select((user) => user.valueOrNull?.uid));
  if (uid == null) return Stream.value([]);
  return ref.watch(monetizationRepositoryProvider).watchUserPayments(uid);
});

final userSubscriptionProvider = StreamProvider.autoDispose<SubscriptionRecord?>((ref) {
  final uid = ref.watch(appUserProvider.select((user) => user.valueOrNull?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(monetizationRepositoryProvider).watchUserSubscription(uid);
});
