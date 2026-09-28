import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 通行密鑰的 Android 來源與 assetlinks.json 都綁定簽署憑證的 SHA-256，正式版必須由全組共用的 keystore 簽署。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("android/key.properties 缺少 $name")

if (!hasReleaseKeystore && gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    logger.warn("找不到 android/key.properties，release 版改以本機 debug 金鑰簽署，通行密鑰將無法使用。")
}

android {
    namespace = "com.example.savemybook_app"
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
        // 必須與 Firebase 主控台登記的 Android 套件名稱一致。
        // namespace 維持舊值：它只決定 Kotlin 原始碼的套件路徑，改了得搬 MainActivity。
        applicationId = "today.savemybook.app"
        // Firebase Android SDK 最低支援 API 23。
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperty("storeFile"))
                storePassword = keystoreProperty("storePassword")
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}

// 外掛以 implementation 引入 firebase-messaging，App 模組編譯 SaveMyBookMessagingService 時需自行宣告；BoM 版本與 firebase_core 的 FirebaseSDKVersion 保持一致。
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.core:core:1.13.1")
}
