import '../models/payment_record.dart';
import '../models/subscription_record.dart';

abstract class MonetizationRepository {
  // Payment operations
  Future<String> initiateSTKPush({
    required String userId,
    required double amount,
    required String phoneNumber,
    required PaymentType type,
    String? itemId,
    Map<String, dynamic>? metadata,
  });

  Future<PaymentRecord?> getPaymentStatus(String paymentId);
  Stream<List<PaymentRecord>> watchUserPayments(String userId);

  // Subscription operations
  Future<void> upgradeToBusinessAccount({
    required String userId,
    required String businessName,
    required String businessCategory,
    required SubscriptionTier tier,
  });

  Future<SubscriptionRecord?> getUserSubscription(String userId);
  Stream<SubscriptionRecord?> watchUserSubscription(String userId);

  // Business Name uniqueness check
  Future<bool> isBusinessNameUnique(String businessName);

  // Webhook handling (Future-ready architecture)
  Future<void> handleMpesaWebhook(Map<String, dynamic> payload);
  Future<void> handleIntaSendWebhook(Map<String, dynamic> payload);
  
  // Entitlement logic
  Future<void> activateEntitlement(PaymentRecord payment);

  // Growth Phase Helpers (Free for verified users)
  Future<bool> canUsePremiumFeature(String userId, PaymentType featureType);
  Future<void> activateFreePremiumFeature({
    required String userId,
    required String itemId,
    required PaymentType type,
    Map<String, dynamic>? metadata,
  });
}
