allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ✅ AQUI ESTÁ O SEU ID CORRIGIDO
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
        // ✅ AQUI TAMBÉM
        applicationId = "com.galvaoapps.bubbletycoon"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // --- SEGURANÇA MIDAS ---
            // O código abaixo busca as variáveis que o GitHub Actions injeta.
            // Você NÃO precisa mexer aqui. O robô preenche isso sozinho.
            
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val keystorePassword = System.getenv("ANDROID_STORE_PASSWORD")
            val keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            val keyPassword = System.getenv("ANDROID_KEY_PASSWORD")

            // Lógica de Proteção:
            if (keystorePath != null && file(keystorePath).exists()) {
                // Se achou o arquivo (cenário do GitHub), assina o app.
                storeFile = file(keystorePath)
                storePassword = keystorePassword
                keyAlias = keyAlias
                keyPassword = keyPassword
            } else if (System.getenv("CI") != null) { 
                // Se estiver no GitHub (CI) e não achou a chave: TRAVA TUDO.
                throw GradleException("❌ ERRO CRÍTICO: Keystore não encontrada! O build de Release no GitHub EXIGE assinatura.")
            }
            // Se estiver no seu PC (debug), ele passa sem assinar (padrão do Flutter).
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // Otimizações para deixar o app leve e difícil de clonar
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
: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
