# 인앱구독 배포 체크리스트 (월 9,900원)

## 1) 스토어 상품 준비
- `PREMIUM_SUBSCRIPTION_PRODUCT_ID`를 iOS/Android 모두 동일하게 맞춥니다.
- 기본값: `lifeisbonus_premium_monthly_9900`
- App Store Connect / Play Console에서 구독 상품을 생성하고 활성화합니다.

## 2) Flutter 실행 시 환경변수
```bash
cd /Users/sungjunpark/Project_LifeIsBonus_260112/lifeisbonus
flutter run \
  --dart-define=PREMIUM_SUBSCRIPTION_PRODUCT_ID=lifeisbonus_premium_monthly_9900 \
  --dart-define=ANDROID_PACKAGE_NAME=com.lifeisbonus.app.lifeisbonus \
  --dart-define=IOS_BUNDLE_ID=com.lifeisbonus.app.lifeisbonus
```

## 3) Functions 환경변수 준비
- `APPLE_SHARED_SECRET`: App Store Connect Shared Secret
- `PREMIUM_PRODUCT_IDS`: 허용할 상품 ID 목록(쉼표 구분)
- `ANDROID_PACKAGE_NAME`: 안드로이드 패키지명

## 4) Functions 배포
현재 함수는 `process.env`를 사용합니다. 배포 시 아래처럼 환경변수와 함께 실행하세요.

```bash
cd /Users/sungjunpark/Project_LifeIsBonus_260112/lifeisbonus/functions
npm install
```

```bash
cd /Users/sungjunpark/Project_LifeIsBonus_260112/lifeisbonus

PREMIUM_PRODUCT_IDS=lifeisbonus_premium_monthly_9900 \
ANDROID_PACKAGE_NAME=com.lifeisbonus.app.lifeisbonus \
APPLE_SHARED_SECRET=YOUR_APPLE_SHARED_SECRET \
firebase deploy --only functions:verifyPremiumPurchase
```

## 5) 푸시 함수까지 함께 배포
```bash
cd /Users/sungjunpark/Project_LifeIsBonus_260112/lifeisbonus
firebase deploy --only functions:verifyPremiumPurchase,functions:sendMessagePush
```

## 6) 로그 확인
```bash
cd /Users/sungjunpark/Project_LifeIsBonus_260112/lifeisbonus
firebase functions:log --only verifyPremiumPurchase
```

## 7) 테스트 시나리오
- iOS Sandbox 계정으로 구독 결제 성공
- iOS 구매 복원 버튼 동작
- Android 내부 테스트 트랙 결제 성공
- 결제 후 `users/{uid}`의 `premiumActive`, `premiumUntil`, `premiumStoreState` 값 갱신 확인
- 설정 탭의 `스토어에서 구독 관리` 버튼으로 스토어 구독 관리 화면 이동 확인
