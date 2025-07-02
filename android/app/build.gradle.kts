import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import com.android.build.api.dsl.ApplicationBuildType
import org.gradle.api.Project
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.appdistribution") apply false
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(key: String, project: Project): String {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.reader().use { reader ->
            properties.load(reader)
        }
    } else {
        println("Warning: local.properties not found.")
    }
    return properties.getProperty(key) ?: ""
}

android {
    namespace = "com.xburnsx.toutie_budget"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.xburnsx.toutie_budget"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 35
        versionCode = localProperties("flutter.versionCode", project).toInt()
        versionName = localProperties("flutter.versionName", project)
    }

    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "android"
            storeFile = file("upload-keystore.jks")
            storePassword = "android"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // Activer R8/ProGuard pour la release
            isMinifyEnabled = true
            isShrinkResources = true

            // Activer la génération des symboles de débogage NDK
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }

            // Appliquer le plugin App Distribution uniquement en release
            project.plugins.apply("com.google.firebase.appdistribution")
        }
        
        debug {
            // Pas de config App Distribution en debug
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
}

apply(plugin = "com.google.gms.google-services")