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
    defaultValue: 'com.lifeisbonus.app',
  );

  static PremiumStatus _statusFromUserData(Map<String, dynamic>? data) {
    final premiumUntilValue = data?['premiumUntil'];
    DateTime? premiumUntil;
    if (premiumUntilValue is String) {
      premiumUntil = DateTime.tryParse(premiumUntilValue);
    }
    if (premiumUntilValue is Timestamp) {
      premiumUntil = premiumUntilValue.toDate();
    }

    final now = DateTime.now();
    final hasUnexpiredEntitlement =
        premiumUntil != null && premiumUntil.isAfter(now);
    final premiumActiveField = data?['premiumActive'];
    final premiumStoreState = (data?['premiumStoreState'] as String?)?.trim();

    final storeStateBlocksPremium = switch (premiumStoreState) {
      'SUBSCRIPTION_STATE_EXPIRED' => true,
      'SUBSCRIPTION_STATE_CANCELED' => true,
      'SUBSCRIPTION_STATE_REVOKED' => true,
      'SUBSCRIPTION_STATE_ON_HOLD' => true,
      'CANCELED' => true,
      _ => false,
    };

    final storeActive = premiumActiveField is bool
        ? premiumActiveField
        : hasUnexpiredEntitlement;
    final isPremium =
        hasUnexpiredEntitlement && storeActive && !storeStateBlocksPremium;
    return PremiumStatus(isPremium: isPremium, premiumUntil: premiumUntil);
  }

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
    return _statusFromUserData(doc.data());
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
      return _statusFromUserData(doc.data());
    });
  }

  @Deprecated('스토어 검증 기반 구독만 지원합니다. IAP 검증 로직을 사용하세요.')
  static Future<void> activateMonthly({int days = 30}) async {
    throw UnsupportedError('스토어 검증 없이 프리미엄 상태를 직접 변경할 수 없습니다.');
  }

  @Deprecated('스토어 검증 기반 구독만 지원합니다. 스토어 구독 관리 화면을 사용하세요.')
  static Future<void> cancelSubscription() async {
    throw UnsupportedError('스토어 구독 해지는 각 스토어 구독 관리 화면에서 처리해야 합니다.');
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
