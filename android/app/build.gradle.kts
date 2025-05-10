import org.gradle.api.JavaVersion

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.homiya_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

   signingConfigs {
    create("release") {
        // DİAQNOSTİKA ÜÇÜN ƏLAVƏLƏR:
        println("--- Keystore Debug ---")
        println("Attempting to configure signing for release.")
        println("Does project have MYAPP_KEYSTORE property? " + project.hasProperty("MYAPP_KEYSTORE"))

        if (project.hasProperty("MYAPP_KEYSTORE")) {
            val keystorePathFromProps = project.property("MYAPP_KEYSTORE") as String
            println("MYAPP_KEYSTORE from props: '$keystorePathFromProps'") // Dırnaqlar içində göstərəcək ki, boşluqlar var ya yox
            
            storeFile = file(keystorePathFromProps) // Bu sətri olduğu kimi saxlayırıq
            println("Resolved storeFile path: '${storeFile?.absolutePath}'") // ?.absolutePath əlavə etdim ki, null olsa xəta verməsin

            // Şifrələr və alias üçün də eyni yoxlamanı edə bilərik, amma əsas problem yol ilə bağlıdır
            storePassword = project.property("MYAPP_STORE_PASSWORD") as String
            keyAlias = project.property("MYAPP_KEY_ALIAS") as String
            keyPassword = project.property("MYAPP_KEY_PASSWORD") as String
            println("Keystore password, alias, keyPassword are being set from properties.")
        } else {
            println("Warning: MYAPP_KEYSTORE property not found in gradle.properties.kts or other sources.")
            println("Build will likely fail or use a default debug keystore if available elsewhere.")
            // Burada başqa bir default konfiqurasiya yoxdursa, imzalama baş tutmayacaq.
        }
        println("--- End Keystore Debug ---")
    }
}

      buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.homiya_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

   
}

flutter {
    source = "../.."
}


dependencies {
    implementation("androidx.core:core-ktx:1.6.0")
    implementation("androidx.appcompat:appcompat:1.3.1")
    implementation("com.google.android.material:material:1.4.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.0")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.5.21")
}