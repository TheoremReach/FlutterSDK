group = "com.theoremreach.flutter"
version = "1.0.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    // Flutter 3.35's app template's versions, for a build of this project alone. In an app, the app's own Android
    // Gradle plugin and Kotlin take their place.
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// The Android Gradle plugin compiles Kotlin itself from 9.0, unless the app turns that off. Before it the Kotlin Gradle
// plugin does, and Flutter applies that to a plugin only from 3.44, so the plugin applies it on older Flutter. It's
// applied here, outside the plugins block, since Flutter warns about a plugin that declares it there.
val builtInKotlin = androidComponents.pluginVersion.major >= 9 &&
    providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() != false
if (!builtInKotlin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.theoremreach.flutter"

    // The SDK's Credential Manager libraries need 35.
    compileSdk = 35

    defaultConfig {
        minSdk = 23
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    testOptions {
        unitTests {
            isReturnDefaultValues = true
            all {
                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// Set on the compile tasks, which both ways of compiling Kotlin have, rather than in a `kotlin` block, which only
// exists here when the Kotlin Gradle plugin is in the plugins block.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

dependencies {
    implementation("com.theoremreach:theoremreach:3.7.2")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.24.0")
}
