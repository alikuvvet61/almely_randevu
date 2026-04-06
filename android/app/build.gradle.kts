plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // Flutter Gradle Plugin, Android ve Kotlin'den sonra gelmelidir.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.almely_randevu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.almely_randevu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --- KRİTİK EKLEME ---
        // AndroidManifest içindeki ${applicationName} hatasını manuel çözen placeholder.
        // Bu satır sayesinde 'io.flutter.app.FlutterApplication' kullanmana gerek kalmaz.
        manifestPlaceholders["applicationName"] = "android.app.Application"
    }

    buildTypes {
        release {
            // Test aşamasında debug anahtarı kullanılıyor, canlıda kendi anahtarını eklemelisin.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Modern Kotlin derleme ayarları
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}