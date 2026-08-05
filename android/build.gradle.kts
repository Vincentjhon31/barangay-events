allprojects {
    repositories {
        google()
        mavenCentral()
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
// Raise any plugin module still compiling against an SDK below 36.
//
// file_picker 8.x hardcodes `compileSdk 34` in its own android/build.gradle,
// but its transitive flutter_plugin_android_lifecycle requires 36 — without
// this, :file_picker:checkReleaseAarMetadata fails the release build. Staying
// on file_picker 8.x is deliberate (see the note in pubspec.yaml): 11.x skips
// applying the Kotlin plugin on AGP 9 and its FilePickerPlugin class then
// never gets compiled.
//
// Applied as a floor rather than an assignment so a plugin already targeting
// 36+ is left alone. Reached reflectively because the root project's
// buildscript classpath has no guarantee of carrying AGP's types, and a
// missing-class error here would break every Android build.
//
// MUST stay above the evaluationDependsOn(":app") block below: that call
// forces :app to evaluate eagerly, and registering afterEvaluate on an
// already-evaluated project throws "Cannot run Project.afterEvaluate(Action)
// when the project is already evaluated."
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            val current = androidExt.javaClass.methods
                .firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
                ?.invoke(androidExt) as? Int
            if (current != null && current < 36) {
                androidExt.javaClass.methods
                    .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                    ?.invoke(androidExt, 36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
