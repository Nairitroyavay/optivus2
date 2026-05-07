plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.example.optivus"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.optivus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            providers.gradleProperty("GOOGLE_MAPS_API_KEY").orElse("").get()
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled =
                    providers.gradleProperty("uploadCrashlyticsMapping").map(String::toBoolean).getOrElse(false)
            }
        }
    }

    lint {
        // Workaround for AGP lint crash: ArrayIndexOutOfBoundsException in PositionXmlParser
        // (a known Android Lint bug with certain XML resource files)
        checkReleaseBuilds = false
        abortOnError = false
    }

    // Workaround for AGP 8.y bug where stripDebugDebugSymbols fails if directory doesn't exist
    tasks.configureEach {
        if (name == "stripDebugDebugSymbols" || name == "stripProfileDebugSymbols" || name == "stripReleaseDebugSymbols") {
            doFirst {
                val inputDir = project.layout.buildDirectory.dir("intermediates/merged_native_libs/${name.replace("strip", "").replace("DebugSymbols", "").lowercase()}/merge${name.replace("strip", "").replace("DebugSymbols", "")}NativeLibs/out").get().asFile
                if (!inputDir.exists()) {
                    inputDir.mkdirs()
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

configurations.all {
    resolutionStrategy.force("androidx.core:core:1.16.0")
    resolutionStrategy.force("androidx.core:core-ktx:1.16.0")
}
