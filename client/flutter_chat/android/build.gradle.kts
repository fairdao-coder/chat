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
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_plugin_android_lifecycle 2.0.35+ 要求所有依賴它的 Android 子項目
// compileSdk >= 36，但 file_picker 等插件仍寫死 flutter.compileSdkVersion（34）。
// 透過 afterEvaluate 強制覆蓋所有 Android subproject 的 compileSdkVersion，
// 否則 checkReleaseAarMetadata 會報 "compiled against android-34"。
subprojects {
    afterEvaluate {
        plugins.withType(com.android.build.gradle.BasePlugin::class.java) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
