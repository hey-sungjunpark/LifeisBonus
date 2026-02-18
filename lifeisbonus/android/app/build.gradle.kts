plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lifeisbonus.app.lifeisbonus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lifeisbonus.app.lifeisbonus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["kakaoNativeAppKey"] =
            (project.findProperty("KAKAO_NATIVE_APP_KEY") as String?)
                ?: "2fb2536b99bf76097001386b2837c5ce"
        resValue(
            "string",
            "naver_client_id",
            (project.findProperty("NAVER_CLIENT_ID") as String?)
                ?: "Pk2pE37pz6xuUEj9j6bA",
        )
        resValue(
            "string",
            "naver_client_secret",
            (project.findProperty("NAVER_CLIENT_SECRET") as String?)
                ?: "NcLY4aB1UD",
        )
        resValue(
            "string",
            "naver_client_name",
            (project.findProperty("NAVER_CLIENT_NAME") as String?)
                ?: "인생은보너스",
        )
        resValue(
            "string",
            "naver_url_scheme",
            (project.findProperty("NAVER_URL_SCHEME") as String?)
                ?: "naverPk2pE37pz6xuUEj9j6bA",
        )
        resValue(
            "string",
            "default_notification_channel_id",
            "chat_messages",
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
