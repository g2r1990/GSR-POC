plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gsr.gsr_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    defaultConfig {
        applicationId = "com.gsr.gsr_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "app"
    productFlavors {
        create("customer") {
            dimension = "app"
            manifestPlaceholders["appLabel"] = "BossBite"
        }
        create("owner") {
            dimension = "app"
            applicationIdSuffix = ".owner"
            manifestPlaceholders["appLabel"] = "BossBite Owner"
        }
        create("admin") {
            dimension = "app"
            applicationIdSuffix = ".admin"
            manifestPlaceholders["appLabel"] = "BossBite Admin"
        }
        create("rider") {
            dimension = "app"
            applicationIdSuffix = ".rider"
            manifestPlaceholders["appLabel"] = "BossBite Rider"
        }
    }

    buildTypes {
        release {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            signingConfig = if (keystorePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
