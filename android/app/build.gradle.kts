plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.galvaoapps.bubbletycoon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

        defaultConfig {
        // Note o sinal de igual (=)
        applicationId = "com.galvaoapps.bubbletycoon"
        
        // Note os parênteses () no lugar de espaço
        minSdkVersion(24)
        targetSdkVersion(flutter.targetSdkVersion)
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        
    }

    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "Pietro&Lorenzo93" 
            storeFile = file("upload-keystore.jks")
            storePassword = "Pietro&Lorenzo93"
        }
    }

    buildTypes {
        getByName("release") {
            // ... (suas configs de minify, etc)
            
            // A ÚNICA LINHA QUE DEVE FICAR É ESTA:
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
