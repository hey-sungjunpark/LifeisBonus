import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumStatus {
  const PremiumStatus({
    required this.isPremium,
    this.premiumUntil,
  });

  final bool isPremium;
  final DateTime? premiumUntil;
}

class PremiumService {
  static const String _androidPackageName = String.fromEnvironment(
    'ANDROID_PACKAGE_NAME',
    defaultValue: 'com.lifeisbonus.app.lifeisbonus',
  );

  static Future<String?> resolveUserDocId() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('lastProvider');
    final providerId = prefs.getString('lastProviderId');
    if ((provider == 'kakao' || provider == 'naver') &&
        providerId != null &&
        providerId.isNotEmpty) {
      return '$provider:$providerId';
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      return authUser.uid;
    }
    if (providerId != null && providerId.isNotEmpty) {
      return providerId;
    }
    return null;
  }

  static Future<PremiumStatus> fetchStatus() async {
    final docId = await resolveUserDocId();
    if (docId == null) {
      return const PremiumStatus(isPremium: false);
    }
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(docId).get();
    final data = doc.data();
    final premiumUntilValue = data?['premiumUntil'];
    DateTime? premiumUntil;
    if (premiumUntilValue is String) {
      premiumUntil = DateTime.tryParse(premiumUntilValue);
    }
    if (premiumUntilValue is Timestamp) {
      premiumUntil = premiumUntilValue.toDate();
    }
    final now = DateTime.now();
    final isPremium = premiumUntil != null && premiumUntil.isAfter(now);
    return PremiumStatus(isPremium: isPremium, premiumUntil: premiumUntil);
  }

  static Stream<PremiumStatus> watchStatus() async* {
    final docId = await resolveUserDocId();
    if (docId == null) {
      yield const PremiumStatus(isPremium: false);
      return;
    }
    yield* FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      final premiumUntilValue = data?['premiumUntil'];
      DateTime? premiumUntil;
      if (premiumUntilValue is String) {
        premiumUntil = DateTime.tryParse(premiumUntilValue);
      }
      if (premiumUntilValue is Timestamp) {
        premiumUntil = premiumUntilValue.toDate();
      }
      final now = DateTime.now();
      final isPremium = premiumUntil != null && premiumUntil.isAfter(now);
      return PremiumStatus(isPremium: isPremium, premiumUntil: premiumUntil);
    });
  }

  static Future<void> activateMonthly({int days = 30}) async {
    final docId = await resolveUserDocId();
    if (docId == null) {
      return;
    }
    final now = DateTime.now();
    final until = now.add(Duration(days: days));
    await FirebaseFirestore.instance.collection('users').doc(docId).set({
      'premiumActive': true,
      'premiumPlan': 'monthly_9900',
      'premiumAutoRenew': true,
      'premiumSince': now.toIso8601String(),
      'premiumUntil': until.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> cancelSubscription() async {
    final docId = await resolveUserDocId();
    if (docId == null) {
      return;
    }
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('users').doc(docId).set({
      'premiumActive': false,
      'premiumAutoRenew': false,
      'premiumCanceledAt': now.toIso8601String(),
      'premiumUntil': now.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Uri?> buildManageSubscriptionUri({String? productId}) async {
    if (Platform.isIOS) {
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    }
    if (Platform.isAndroid) {
      final product = (productId ?? '').trim();
      final query = <String, String>{'package': _androidPackageName};
      if (product.isNotEmpty) {
        query['sku'] = product;
      }
      return Uri.https('play.google.com', '/store/account/subscriptions', query);
    }
    return null;
  }
}
