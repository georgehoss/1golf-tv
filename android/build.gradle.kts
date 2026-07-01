allprojects {
    repositories {
        google()
        mavenCentral()
        // Bitmovin Maven repository
        maven {
            url = uri("https://artifacts.bitmovin.com/artifactory/public-releases")
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

// The bitmovin_player plugin pins compileSdkVersion 34 in its own Android module,
// but its current native AAR requires compileSdk 35+ (fails
// :bitmovin_player:checkDebugAarMetadata). Force the plugin subproject to 35.
// The afterEvaluate must run AFTER the module's own build.gradle (which sets 34)
// yet be REGISTERED before the evaluationDependsOn(":app") block below triggers
// evaluation — hence this block is placed first.
subprojects {
    if (project.name == "bitmovin_player") {
        project.afterEvaluate {
            (project.extensions.getByName("android")
                as com.android.build.gradle.LibraryExtension).compileSdk = 35
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
