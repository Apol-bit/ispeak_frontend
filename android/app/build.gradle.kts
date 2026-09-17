import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseApplicationId = providers.gradleProperty("ISPEAK_APPLICATION_ID").orNull
    ?: System.getenv("ISPEAK_APPLICATION_ID")
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use(::load)
    }
}

android {
    namespace = "com.example.ispeak"
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
        // Development keeps the Flutter placeholder. Release tasks below require
        // an explicit, organization-owned ID via -PISPEAK_APPLICATION_ID.
        applicationId = releaseApplicationId ?: "com.example.ispeak"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let(::file)
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val isReleaseBuild = allTasks.any {
        it.path.contains("Release", ignoreCase = true)
    }
    if (isReleaseBuild) {
        require(!releaseApplicationId.isNullOrBlank() && releaseApplicationId != "com.example.ispeak") {
            "Set an organization-owned package ID with -PISPEAK_APPLICATION_ID=com.yourorg.ispeak"
        }
        require(keystorePropertiesFile.exists()) {
            "android/key.properties is required for release signing; copy key.properties.example and supply your private keystore values"
        }
    }
}

flutter {
    source = "../.."
}
