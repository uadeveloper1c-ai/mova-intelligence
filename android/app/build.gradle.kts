plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services (Firebase)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mova_intelligence_app"
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
        applicationId = "com.example.mova_intelligence_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 🔥 Вот ЭТО — самое важное для ошибки messaging-ktx
dependencies {
    // BoM – сюда подставится версии всех firebase-* библиотек
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

    // Firebase Cloud Messaging (KTX)
    implementation("com.google.firebase:firebase-messaging-ktx")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
