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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Vosk's transitive JNA dependency: 5.17.0 ships 16 KB page-aligned
// libjnidispatch.so (required on Android 15+ 16 KB devices). CI verifies alignment.
allprojects {
    configurations.configureEach {
        resolutionStrategy {
            force("net.java.dev.jna:jna:5.17.0@aar")
            force("net.java.dev.jna:jna:5.17.0")
        }
    }
}
