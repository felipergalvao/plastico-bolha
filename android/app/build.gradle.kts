plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.galvaoapps.bubbletycoon"
    
    compileSdk = flutter.compileSdkVersion
    
    // 1. FORÇA O NDK MODERNO AQUI (Sintaxe Kotlin)
    ndkVersion = "27.1.12297006"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    // 2. ADICIONE ESTE BLOCO AQUI (Obrigatório para o Android 15 / 16 KB)
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    defaultConfig {
        applicationId = "com.galvaoapps.bubbletycoon"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // --- CONFIGURAÇÃO MIDAS CORRIGIDA ---
            // Usa nomes de variáveis diferentes para evitar conflito
            
            val envKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val envStorePass = System.getenv("ANDROID_STORE_PASSWORD")
            val envKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
            val envKeyPass = System.getenv("ANDROID_KEY_PASSWORD")

            // Lógica de Segurança:
            if (envKeystorePath != null && file(envKeystorePath).exists()) {
                storeFile = file(envKeystorePath)
                storePassword = envStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            } else if (System.getenv("CI") != null) { 
                throw GradleException("❌ ERRO CRÍTICO: Keystore não encontrada no GitHub Actions!")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}