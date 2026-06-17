allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

subprojects {
    val configureAndroid = {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                if (namespace == null) {
                    namespace = if (project.group.toString().isNotEmpty()) project.group.toString() else "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                }
                try {
                    compileSdkVersion(35)
                } catch (e: Exception) {
                    // Ignore if configuration is already locked
                }
            }
        }
    }
    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate { configureAndroid() }
    }
}
