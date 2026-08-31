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
//
// AGP 9.1 已把舊 DSL 的 BaseExtension 標記為 ERROR 級棄用——在 Kotlin DSL 中
// 連類名都不能引用（引用即編譯失敗），而項目 gradle.properties 又是
// android.newDsl=false（用舊擴展實現，新 DSL 的 CommonExtension 類型對不上）。
// 因此用反射調用 setter：setCompileSdk(int) 覆蓋新實現，
// setCompileSdkVersion(int) 覆蓋舊實現，兩種 AGP 配置都能工作。
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            val setter = android.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterTypes.firstOrNull() == Integer.TYPE
            } ?: android.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" && it.parameterTypes.firstOrNull() == Integer.TYPE
            }
            if (setter == null) {
                println("compileSdk override: no int setter on ${project.path}")
            } else {
                setter.invoke(android, 36)
                println("compileSdk override: ${project.path} -> 36")
            }
        }.onFailure {
            println("compileSdk override failed for ${project.path}: ${it.message}")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
