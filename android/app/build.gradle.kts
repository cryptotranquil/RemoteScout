plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val defaultApplicationId = "com.praisekajawa.remotescout"
val configuredApplicationId = providers.gradleProperty("APPLICATION_ID").orElse(
    providers.environmentVariable("APPLICATION_ID"),
).orElse(defaultApplicationId).get()
val releaseStoreFile = providers.gradleProperty("RELEASE_STORE_FILE").orElse(
    providers.environmentVariable("RELEASE_STORE_FILE"),
).orNull
val releaseStorePassword = providers.gradleProperty("RELEASE_STORE_PASSWORD").orElse(
    providers.environmentVariable("RELEASE_STORE_PASSWORD"),
).orNull
val releaseKeyAlias = providers.gradleProperty("RELEASE_KEY_ALIAS").orElse(
    providers.environmentVariable("RELEASE_KEY_ALIAS"),
).orNull
val releaseKeyPassword = providers.gradleProperty("RELEASE_KEY_PASSWORD").orElse(
    providers.environmentVariable("RELEASE_KEY_PASSWORD"),
).orNull
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = defaultApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = configuredApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

tasks.register("validateReleaseConfiguration") {
    doLast {
        check(
            configuredApplicationId.matches(
                Regex("""^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$"""),
            ),
        ) {
            "APPLICATION_ID must be a lowercase, reverse-domain Android package name."
        }
        check(hasReleaseSigning) {
            "Set RELEASE_STORE_FILE, RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS, and RELEASE_KEY_PASSWORD before building a release."
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease") {
        dependsOn("validateReleaseConfiguration")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
