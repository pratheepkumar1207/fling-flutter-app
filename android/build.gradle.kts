plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// agora_rtc_engine's own build.gradle reads compileSdkVersion via
// safeExtGet('compileSdkVersion', 31) — it already supports being
// overridden this way (the standard Flutter-plugin-authoring pattern),
// falling back to the too-old 31 only when this isn't set. Its transitive
// androidx deps need 34+.
rootProject.extra["compileSdkVersion"] = 36

// Other plugins (e.g. file_picker) hardcode their own compileSdk instead of
// reading the extra property above, and some transitive dep now requires
// 36+. Force every Android subproject to compile against 36 regardless of
// what its own build.gradle set, so plugin authors' lag doesn't block us.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
            android.compileSdkVersion(36)
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
