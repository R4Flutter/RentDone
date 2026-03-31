allprojects {
   repositories {
    google()
    mavenCentral()
    maven("https://maven.cashfree.com/release")
}
}

subprojects {
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        // Third-party Android plugins may still target Java 8; suppress obsolete option noise.
        options.compilerArgs.add("-Xlint:-options")
        // Suppress noisy plugin-side notes for deprecated/unchecked APIs from pub cache deps.
        options.compilerArgs.add("-Xlint:-deprecation")
        options.compilerArgs.add("-Xlint:-unchecked")
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
