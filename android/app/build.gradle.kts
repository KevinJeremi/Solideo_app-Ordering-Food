plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // Add this line
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.id22.food_ui"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.id22.food_ui"
        minSdkVersion(29)
        targetSdkVersion(flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // Add this line
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.android.support:multidex:1.0.3")
}