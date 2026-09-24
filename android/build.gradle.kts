allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

project.extra.set("kotlin_version", "2.2.10")

rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    description = "Cleans the build directory"
    delete(rootProject.layout.buildDirectory)
}
