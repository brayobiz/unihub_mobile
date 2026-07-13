import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/payment_record.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/repositories/monetization_repository.dart';
import '../../../../core/utils/app_logger.dart';

class MonetizationRepositoryImpl implements MonetizationRepository {
  final FirebaseFirestore _firestore;

  MonetizationRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> initiateSTKPush({
    required String userId,
    required double amount,
    required String phoneNumber,
    required PaymentType type,
    String? itemId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = _firestore.collection('payments').doc();
      final payment = PaymentRecord(
        id: docRef.id,
        userId: userId,
        itemId: itemId,
        amount: amount,
        type: type,
        gateway: PaymentGateway.mpesa,
        phoneNumber: phoneNumber,
        status: PaymentStatus.pending,
        metadata: metadata ?? {},
        createdAt: DateTime.now(),
      );

      await docRef.set(payment.toJson());
      
      // In the future, this would trigger a Cloud Function or call M-Pesa API
      AppLogger.info('STK Push initiated for payment: ${docRef.id}');
      
      return docRef.id;
    } catch (e) {
      AppLogger.error('Failed to initiate STK Push', e);
      rethrow;
    }
  }

  @override
  Future<PaymentRecord?> getPaymentStatus(String paymentId) async {
    final doc = await _firestore.collection('payments').doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentRecord.fromJson(doc.data()!);
  }

  @override
  Stream<List<PaymentRecord>> watchUserPayments(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<void> upgradeToBusinessAccount({
    required String userId,
    required String businessName,
    required String businessCategory,
    required SubscriptionTier tier,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final isVerified = userDoc.data()?['isIdentityVerified'] == true || 
                       userDoc.data()?['isStudentVerified'] == true ||
                       userDoc.data()?['accountType'] == 'business';

    final batch = _firestore.batch();
    
    // Update User Profile
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'accountType': 'business',
      'businessName': businessName,
      'businessCategory': businessCategory,
      // If verified during growth phase, give them Pro tier for free
      'tier': (isVerified || tier == SubscriptionTier.businessPremium) ? 'pro' : 'free',
    });

    // Create/Update Subscription Record
    final subRef = _firestore.collection('subscriptions').doc(userId);
    final now = DateTime.now();
    final subscription = SubscriptionRecord(
      id: userId,
      userId: userId,
      tier: tier,
      status: SubscriptionStatus.active,
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
      createdAt: now,
      updatedAt: now,
    );
    
    batch.set(subRef, subscription.toJson());
    
    await batch.commit();
  }

  @override
  Future<SubscriptionRecord?> getUserSubscription(String userId) async {
    final doc = await _firestore.collection('subscriptions').doc(userId).get();
    if (!doc.exists) return null;
    return SubscriptionRecord.fromJson(doc.data()!);
  }

  @override
  Stream<SubscriptionRecord?> watchUserSubscription(String userId) {
    return _firestore
        .collection('subscriptions')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? SubscriptionRecord.fromJson(doc.data()!) : null);
  }

  @override
  Future<bool> isBusinessNameUnique(String businessName) async {
    final query = await _firestore
        .collection('users')
        .where('businessName', isEqualTo: businessName.trim())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  @override
  Future<void> handleMpesaWebhook(Map<String, dynamic> payload) async {
    // This would be called by a Cloud Function endpoint in the future
    // For now, architecture is ready to process the payload
    AppLogger.info('M-Pesa Webhook received: $payload');
  }

  @override
  Future<void> handleIntaSendWebhook(Map<String, dynamic> payload) async {
    AppLogger.info('IntaSend Webhook received: $payload');
  }

  @override
  Future<void> activateEntitlement(PaymentRecord payment) async {
    if (payment.status != PaymentStatus.completed && payment.amount > 0) return;

    final batch = _firestore.batch();
    final now = DateTime.now();

    switch (payment.type) {
      case PaymentType.boost:
        if (payment.itemId != null) {
          batch.update(_firestore.collection('listings').doc(payment.itemId), {
            'lastBoostedAt': FieldValue.serverTimestamp(),
            'boostCount': FieldValue.increment(1),
          });
        }
        break;
      case PaymentType.feature:
        if (payment.itemId != null) {
          final durationDays = payment.metadata['durationDays'] ?? 7;
          batch.update(_firestore.collection('listings').doc(payment.itemId), {
            'isFeatured': true,
            'featuredAt': FieldValue.serverTimestamp(),
            'featuredUntil': Timestamp.fromDate(now.add(Duration(days: durationDays))),
            'featuredPackage': payment.metadata['packageId'] ?? 'early_bird_free',
          });
        }
        break;
      case PaymentType.sponsoredSearch:
        if (payment.itemId != null) {
          final durationDays = payment.metadata['durationDays'] ?? 3;
          batch.update(_firestore.collection('listings').doc(payment.itemId), {
            'isSponsored': true,
            'sponsoredUntil': Timestamp.fromDate(now.add(Duration(days: durationDays))),
          });
        }
        break;
      case PaymentType.subscription:
        // Subscription handling logic
        break;
    }
    
    await batch.commit();
  }

  @override
  Future<bool> canUsePremiumFeature(String userId, PaymentType featureType) async {
    // 1. Check user verification (Verified Students or Business Accounts)
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;
    
    final data = userDoc.data();
    final isVerified = data?['isIdentityVerified'] == true || 
                       data?['isStudentVerified'] == true ||
                       data?['accountType'] == 'business';
    
    if (!isVerified) {
      AppLogger.warning('Premium feature access denied: User $userId not verified.', 'MONETIZATION');
      return false;
    }

    // 2. Check for cooldowns/limits to prevent abuse during free phase
    if (featureType == PaymentType.boost) {
      // Limit: One successful boost every 24 hours per user
      final recentBoosts = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: PaymentType.boost.name)
          .where('status', isEqualTo: PaymentStatus.completed.name)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
          .limit(1)
          .get();
      
      if (recentBoosts.docs.isNotEmpty) {
        AppLogger.info('Boost cooldown active for user $userId', 'MONETIZATION');
        return false;
      }
    }

    if (featureType == PaymentType.feature) {
      // Limit: Max 3 active featured listings at a time
      final activeFeatured = await _firestore
          .collection('listings')
          .where('sellerId', isEqualTo: userId)
          .where('isFeatured', isEqualTo: true)
          .get();
      
      if (activeFeatured.docs.length >= 3) {
        AppLogger.info('Feature limit reached (max 3) for user $userId', 'MONETIZATION');
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> activateFreePremiumFeature({
    required String userId,
    required String itemId,
    required PaymentType type,
    Map<String, dynamic>? metadata,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final isVerified = userData?['isIdentityVerified'] == true || 
                       userData?['isStudentVerified'] == true ||
                       userData?['accountType'] == 'business';

    if (!isVerified) {
       throw Exception('Verification required: Please verify your identity in the Trust Center to use premium features.');
    }

    final canUse = await canUsePremiumFeature(userId, type);
    if (!canUse) {
      if (type == PaymentType.boost) {
        throw Exception('Boost unavailable: You can only boost your items once every 24 hours.');
      } else if (type == PaymentType.feature) {
        throw Exception('Feature limit reached: You can have a maximum of 3 featured listings at a time.');
      }
      throw Exception('Feature unavailable: Check cooldown limits.');
    }

    // Record as a "Free" transaction for future data consistency
    final docRef = _firestore.collection('payments').doc();
    final payment = PaymentRecord(
      id: docRef.id,
      userId: userId,
      itemId: itemId,
      amount: 0.0,
      currency: 'KES',
      type: type,
      gateway: PaymentGateway.manual,
      status: PaymentStatus.completed,
      metadata: {
        ...(metadata ?? {}),
        'promo': 'early_bird_free',
        'activatedAt': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );

    await docRef.set(payment.toJson());
    await activateEntitlement(payment);
    
    AppLogger.info('Free premium feature activated: ${type.name} for item $itemId');
  }
}
