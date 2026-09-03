group = "com.example.security_gate"
version = "1.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply(plugin = "com.android.library")

android {
    // Conditional: use Flutter's compileSdk if available, else default
    if (project.android.hasProperty("namespace")) {
        namespace = "com.example.security_gate"
    }

    compileSdk = 34

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}
