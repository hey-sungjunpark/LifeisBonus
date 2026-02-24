import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_service.dart';

enum IapEventType { pending, purchased, restored, error }

class IapEvent {
  const IapEvent({
    required this.type,
    this.message,
    this.premiumUntil,
  });

  final IapEventType type;
  final String? message;
  final DateTime? premiumUntil;
}

class IapSubscriptionService {
  IapSubscriptionService._();

  static final IapSubscriptionService instance = IapSubscriptionService._();

  static const String productId = String.fromEnvironment(
    'PREMIUM_SUBSCRIPTION_PRODUCT_ID',
    defaultValue: 'lifeisbonus_premium_monthly',
  );

  static const String androidPackageName = String.fromEnvironment(
    'ANDROID_PACKAGE_NAME',
    defaultValue: 'com.lifeisbonus.app',
  );

  static const String iosBundleId = String.fromEnvironment(
    'IOS_BUNDLE_ID',
    defaultValue: 'com.lifeisbonus.app',
  );

  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<IapEvent> _eventController =
      StreamController<IapEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _initialized = false;
  bool _storeAvailable = false;

  Stream<IapEvent> get events => _eventController.stream;
  bool get storeAvailable => _storeAvailable;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _storeAvailable = await _iap.isAvailable();
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error) {
        _eventController.add(
          IapEvent(type: IapEventType.error, message: error.toString()),
        );
      },
    );
    _initialized = true;
  }

  Future<List<ProductDetails>> queryProducts() async {
    await initialize();
    if (!_storeAvailable) {
      return const <ProductDetails>[];
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      throw Exception(_mapIapError(response.error));
    }
    if (response.productDetails.isEmpty) {
      throw Exception('스토어에서 구독 상품을 찾지 못했습니다.');
    }
    return response.productDetails;
  }

  Future<void> buy(ProductDetails product) async {
    await initialize();
    if (!_storeAvailable) {
      throw Exception('스토어 연결을 사용할 수 없습니다.');
    }
    final userDocId = await PremiumService.resolveUserDocId();
    if (userDocId == null) {
      throw Exception('로그인 정보가 없어 결제를 시작할 수 없습니다.');
    }
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: userDocId,
    );
    final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!started) {
      throw Exception('결제 요청을 시작하지 못했습니다.');
    }
  }

  Future<void> restore() async {
    await initialize();
    if (!_storeAvailable) {
      throw Exception('스토어 연결을 사용할 수 없습니다.');
    }
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      var shouldCompletePurchase = false;
      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            _eventController.add(const IapEvent(type: IapEventType.pending));
            break;
          case PurchaseStatus.error:
            shouldCompletePurchase = true;
            _eventController.add(
              IapEvent(
                type: IapEventType.error,
                message: _mapIapError(purchase.error),
              ),
            );
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final verification = await _verifyPurchaseOnServer(purchase);
            shouldCompletePurchase = true;
            final isActive = verification['isActive'] == true;
            final premiumUntilRaw = verification['premiumUntil'] as String?;
            final premiumUntil = premiumUntilRaw == null
                ? null
                : DateTime.tryParse(premiumUntilRaw);
            if (!isActive) {
              _eventController.add(
                const IapEvent(
                  type: IapEventType.error,
                  message: '구매 검증에 실패했습니다. 고객센터로 문의해 주세요.',
                ),
              );
            } else {
              _eventController.add(
                IapEvent(
                  type: purchase.status == PurchaseStatus.restored
                      ? IapEventType.restored
                      : IapEventType.purchased,
                  premiumUntil: premiumUntil,
                ),
              );
            }
            break;
          case PurchaseStatus.canceled:
            shouldCompletePurchase = true;
            _eventController.add(
              const IapEvent(
                type: IapEventType.error,
                message: '결제가 취소되었습니다.',
              ),
            );
            break;
        }
      } catch (e) {
        _eventController.add(
          IapEvent(type: IapEventType.error, message: _mapException(e)),
        );
        // 구매/복원 후 서버 검증 단계에서 실패하면 complete를 미뤄 재시도(복원 포함) 여지를 남긴다.
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          shouldCompletePurchase = false;
        }
      } finally {
        if (purchase.pendingCompletePurchase && shouldCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<Map<String, dynamic>> _verifyPurchaseOnServer(
    PurchaseDetails purchase,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-northeast3',
    ).httpsCallable('verifyPremiumPurchase');
    final result = await callable.call(<String, dynamic>{
      'platform': Platform.isIOS ? 'ios' : 'android',
      'productId': purchase.productID,
      'purchaseToken': purchase.verificationData.serverVerificationData,
      'source': purchase.verificationData.source,
      'localVerificationData': purchase.verificationData.localVerificationData,
      'serverVerificationData': purchase.verificationData.serverVerificationData,
      'transactionId': purchase.purchaseID,
      'androidPackageName': androidPackageName,
      'iosBundleId': iosBundleId,
    });
    if (result.data is! Map) {
      throw Exception('검증 응답 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  String _mapIapError(IAPError? error) {
    if (error == null) {
      return '결제 처리 중 오류가 발생했습니다.';
    }
    final code = error.code.toLowerCase();
    if (code.contains('user') && code.contains('cancel')) {
      return '결제가 취소되었습니다.';
    }
    if (code.contains('network') || code.contains('service')) {
      return '네트워크 문제로 결제를 진행하지 못했어요. 잠시 후 다시 시도해 주세요.';
    }
    if (code.contains('item') &&
        (code.contains('unavailable') || code.contains('not'))) {
      return '스토어 상품 정보를 찾지 못했어요. 앱을 다시 실행해 주세요.';
    }
    if (code.contains('billing') && code.contains('unavailable')) {
      return '현재 기기에서 결제를 사용할 수 없어요.';
    }
    if (error.message.trim().isNotEmpty) {
      return error.message;
    }
    return '결제 처리 중 오류가 발생했습니다. ($code)';
  }

  String _mapException(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return '로그인이 필요합니다.';
        case 'failed-precondition':
          return '결제 검증 설정이 아직 완료되지 않았습니다. 고객센터로 문의해 주세요.';
        case 'permission-denied':
          return '구매 검증에 실패했습니다. 결제 내역을 확인해 주세요.';
        case 'invalid-argument':
          return '결제 요청 값이 올바르지 않습니다. 앱을 업데이트해 주세요.';
        case 'internal':
        case 'unavailable':
          return '결제 서버 연결에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      }
      return error.message ?? '결제 검증 중 오류가 발생했습니다.';
    }
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
  }
}
