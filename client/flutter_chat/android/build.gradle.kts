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
// flutter_plugin_android_lifecycle 2.0.35+ 要求所有依賴它的 Android 子項目
// compileSdk >= 36，但 file_picker 等插件仍寫死 flutter.compileSdkVersion（34）。
//
// Flutter 3.47 最低要求 AGP 8.11.1，且仍使用舊 DSL（android.newDsl=false）。
// 故固定 AGP 8.11.1，並保留反射兼容邏輯。
// 在舊 DSL 下無法直接引用 CommonExtension，故用反射調用 setter：
// setCompileSdk(int) 覆蓋新 DSL 實現，setCompileSdkVersion(int) 覆蓋舊 DSL 實現。
//
// 注意順序：此塊必須位於下方 evaluationDependsOn 之前註冊。evaluationDependsOn
// 會立即觸發 :app 的評估，若在本塊之後執行，再對已評估的項目調用 afterEvaluate
// 會拋出 "Cannot run Project.afterEvaluate(Action) when the project is already
// evaluated"。插件項目的 compileSdk 是在各自信 build 腳本（評估期間）設置的，
// 本回調在評估完成後執行，因此不會被回寫覆蓋。
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

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
