plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ เพิ่มใหม่: ต้อง apply ตัวนี้ (ไม่ใส่ version ซ้ำ — ประกาศ version ไว้ที่
    // settings.gradle.kts แล้ว) ไม่งั้น build จะหา google-services.json ไม่เจอ/ไม่ generate
    // Firebase config ให้แอป ทำให้ FCM ใช้งานไม่ได้ทั้งที่ไฟล์ google-services.json อยู่ตรงนั้นแล้ว
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.flutter_goodgarage"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ✅ ปลั๊กอิน flutter_local_notifications ต้องการ core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_goodgarage"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ✅ เพิ่มส่วนนี้ — กันบั๊กที่รู้จักของ Android Gradle Plugin ที่ทำให้ task
    // mergeReleaseJavaResource พัง (VerifyException) เวลามีไฟล์ META-INF ซ้ำกัน
    // จากไลบรารีหลายตัวที่ดึงเข้ามาผ่าน dependency หลายชั้น
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module",
                "META-INF/versions/9/module-info.class",
                "META-INF/INDEX.LIST"
            )
        }
    }
}

dependencies {
    // ✅ คู่กับ isCoreLibraryDesugaringEnabled ด้านบน
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
