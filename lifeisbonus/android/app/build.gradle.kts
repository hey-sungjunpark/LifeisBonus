import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.lifeisbonus.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lifeisbonus.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 31
        targetSdk = 35
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storeFilePath = keystoreProperties.getProperty("storeFile") ?: ""
                check(storeFilePath.isNotBlank()) {
                    "android/key.properties의 storeFile 값이 비어 있습니다."
                }
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
