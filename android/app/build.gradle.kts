import org.gradle.api.tasks.PathSensitivity

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

abstract class StageRtcCppRuntime : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val arm64Runtime: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val armRuntime: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun stageLibraries() {
        val output = outputDirectory.get()
        arm64Runtime.get().asFile.copyTo(
            output.file("arm64-v8a/libc++_shared.so").asFile,
            overwrite = true,
        )
        armRuntime.get().asFile.copyTo(
            output.file("armeabi-v7a/libc++_shared.so").asFile,
            overwrite = true,
        )
    }
}

// VolcEngineRTC ships libbytenn.so for ARM, which needs the NDK C++ runtime.
val ndkSysrootLibraries = androidComponents.sdkComponents.ndkDirectory.map { ndk ->
    ndk.dir("toolchains/llvm/prebuilt").asFile.listFiles().orEmpty()
        .map { it.resolve("sysroot/usr/lib") }
        .single { it.isDirectory }
}
val stageRtcCppRuntime = tasks.register<StageRtcCppRuntime>("stageRtcCppRuntime") {
    arm64Runtime.set(layout.file(ndkSysrootLibraries.map {
        it.resolve("aarch64-linux-android/libc++_shared.so")
    }))
    armRuntime.set(layout.file(ndkSysrootLibraries.map {
        it.resolve("arm-linux-androideabi/libc++_shared.so")
    }))
    outputDirectory.set(layout.buildDirectory.dir("generated/rtcCppRuntime"))
}

androidComponents.onVariants { variant ->
    variant.sources.jniLibs?.addGeneratedSourceDirectory(
        stageRtcCppRuntime,
        StageRtcCppRuntime::outputDirectory,
    )
}

android {
    namespace = "com.caoyuming.saypal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.caoyuming.saypal"
        // The RTC SDK only includes its required libbytenn.so on ARM.
        ndk {
            abiFilters.removeAll(listOf("x86", "x86_64"))
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
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

dependencies {
    implementation(project(":oral_practice"))
}
