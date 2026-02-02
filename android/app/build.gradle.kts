plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.galvaoapps.bubbletycoon"
    
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

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

    defaultConfig {
        applicationId = "com.galvaoapps.bubbletycoon"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // --- SEGURANÇA MIDAS (CORRIGIDA) ---
            // Renomeei as variáveis (env...) para não confundir o Gradle
            
            val envKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val envStorePass = System.getenv("ANDROID_STORE_PASSWORD")
            val envKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
            val envKeyPass = System.getenv("ANDROID_KEY_PASSWORD")

            // Lógica de Proteção:
            if (envKeystorePath != null && file(envKeystorePath).exists()) {
                // Se achou o arquivo (cenário do GitHub), assina o app.
                storeFile = file(envKeystorePath)
                storePassword = envStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            } else if (System.getenv("CI") != null) { 
                // Se estiver no GitHub (CI) e não achou a chave: TRAVA TUDO.
                throw GradleException("❌ ERRO CRÍTICO: Keystore não encontrada! O build de Release no GitHub EXIGE assinatura.")
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
