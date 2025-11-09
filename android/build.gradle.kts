plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // ✅ Force compileSdk for all Android modules
    apply(plugin = "idea")

    // Helper function to read package name from AndroidManifest.xml
    fun readPackageFromManifest(): String? {
        // Try multiple possible locations for AndroidManifest.xml
        val possiblePaths = listOf(
            project.file("src/main/AndroidManifest.xml"),
            project.file("AndroidManifest.xml"),
            project.file("src/AndroidManifest.xml")
        )
        
        for (manifestFile in possiblePaths) {
            if (manifestFile.exists()) {
                return try {
                    val manifestContent = manifestFile.readText()
                    val packageRegex = """package=["']([^"']+)["']""".toRegex()
                    packageRegex.find(manifestContent)?.groupValues?.get(1)
                } catch (e: Exception) {
                    null
                }
            }
        }
        return null
    }

    // Set namespace BEFORE the Android plugin evaluates
    beforeEvaluate {
        // Check if this is likely an Android library project
        val buildFile = project.buildFile
        if (buildFile.exists()) {
            val buildFileContent = buildFile.readText()
            if (buildFileContent.contains("com.android.library") || 
                buildFileContent.contains("android-library")) {
                val packageName = readPackageFromManifest()
                if (packageName != null) {
                    // Store package name for later use
                    project.extensions.extraProperties.set("androidNamespace", packageName)
                }
            }
        }
    }

    // Configure Android library modules
    plugins.withId("com.android.library") {
        val packageName = readPackageFromManifest() ?: 
            project.extensions.extraProperties.get("androidNamespace") as? String
        
        configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 35
            
            // Set namespace from manifest if available and not already set
            if (packageName != null) {
                try {
                    // Check if namespace is already set
                    val currentNamespace = try {
                        namespace
                    } catch (e: Exception) {
                        null
                    }
                    
                    if (currentNamespace.isNullOrBlank()) {
                        namespace = packageName
                        println("✅ Set namespace '$packageName' for module '${project.name}'")
                    }
                } catch (e: Exception) {
                    // If setting namespace fails, try using reflection or other methods
                    println("⚠️ Could not set namespace for ${project.name}: ${e.message}")
                }
            } else {
                println("⚠️ Could not find package name in manifest for ${project.name}")
            }
        }
    }
    
    // Final fallback: set namespace in afterEvaluate
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val androidExtension = extensions.findByType<com.android.build.gradle.LibraryExtension>()
            val packageName = readPackageFromManifest() ?: 
                project.extensions.extraProperties.get("androidNamespace") as? String
            
            if (androidExtension != null && packageName != null) {
                try {
                    val currentNamespace = try {
                        androidExtension.namespace
                    } catch (e: Exception) {
                        null
                    }
                    
                    if (currentNamespace.isNullOrBlank()) {
                        androidExtension.namespace = packageName
                        println("✅ Set namespace '$packageName' for module '${project.name}' (afterEvaluate)")
                    }
                } catch (e: Exception) {
                    println("❌ Failed to set namespace for ${project.name}: ${e.message}")
                    e.printStackTrace()
                }
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