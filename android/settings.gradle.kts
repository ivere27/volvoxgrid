pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenLocal()
        google()
        mavenCentral()
    }
}

rootProject.name = "VolvoxGridAndroid"
include(":volvoxgrid-android")
include(":volvoxgrid-android-compose")
include(":example")
includeBuild("../java/common")
