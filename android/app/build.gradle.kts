import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import java.util.Properties
import javax.imageio.ImageIO

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
var releasePropertiesReadable = true
if (releasePropertiesFile.isFile) {
    try {
        releasePropertiesFile.reader(Charsets.UTF_8).use { releaseProperties.load(it) }
    } catch (_: Exception) {
        releasePropertiesReadable = false
    }
}
val releaseStorePath = releaseProperties.getProperty("storeFile")
val releaseStoreFile: File? = releaseStorePath?.let { File(it) }
val releaseSigningIssue = when {
    !releasePropertiesFile.isFile -> "android/key.properties est absent."
    !releasePropertiesReadable -> "android/key.properties est illisible."
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").any {
        releaseProperties.getProperty(it).isNullOrBlank()
    } -> "Les quatre propriétés de signature Release doivent être renseignées."
    releaseStoreFile?.isAbsolute != true -> "storeFile doit être un chemin absolu (sans ~)."
    releaseStoreFile?.canonicalFile?.toPath()?.startsWith(
        rootProject.projectDir.parentFile.canonicalFile.toPath()
    ) == true -> "Le keystore Release doit être situé hors du dépôt."
    releaseStoreFile?.isFile != true -> "Le keystore Release indiqué est introuvable."
    else -> null
}

val validateAccordMemoReleaseSigning = tasks.register("validateAccordMemoReleaseSigning") {
    group = "verification"
    description = "Refuse une Release sans configuration de signature externe complète."
    doLast {
        if (releaseSigningIssue != null) {
            throw GradleException("Signature Release AccordMémo : $releaseSigningIssue")
        }
    }
}

// Ces contrôles ne sont pas exécutés par une build Debug.
tasks.matching {
    it.name == "preReleaseBuild" || it.name == "validateSigningRelease" ||
        it.name == "compileFlutterBuildRelease"
}.configureEach {
    dependsOn(validateAccordMemoReleaseSigning)
}

android {
    namespace = "fr.pianosoccitanie.accordmemo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.pianosoccitanie.accordmemo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningIssue == null) {
                storeFile = releaseStoreFile
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Ressources générées dans build/, sans copie ni modification du logo officiel.
// La source est opaque et contient son fond : on conserve son dessin entier.
abstract class GenerateAccordMemoLauncherIcons : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val logoFile: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun generate() {
        val source = ImageIO.read(logoFile.get().asFile)
            ?: throw GradleException("Logo AccordMémo PNG illisible.")
        require(source.width == source.height) { "Le logo AccordMémo doit rester carré." }
        for ((density, size) in mapOf(
            "mdpi" to 48, "hdpi" to 72, "xhdpi" to 96,
            "xxhdpi" to 144, "xxxhdpi" to 192
        )) {
            val image = BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB)
            val graphics = image.createGraphics()
            try {
                graphics.setRenderingHint(
                    RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC
                )
                graphics.drawImage(source, 0, 0, size, size, null)
            } finally {
                graphics.dispose()
            }
            val destination = outputDirectory.file("mipmap-$density/accordmemo_launcher.png")
                .get().asFile
            destination.parentFile.mkdirs()
            check(ImageIO.write(image, "png", destination)) { "Export du launcher impossible." }
        }
    }
}

androidComponents.onVariants { variant ->
    val variantTitle = variant.name.replaceFirstChar { it.uppercaseChar() }
    val icons = tasks.register<GenerateAccordMemoLauncherIcons>("generate${variantTitle}LauncherIcons") {
        logoFile.set(rootProject.layout.projectDirectory.file("../Assets/logoApp.png"))
    }
    variant.sources.res?.addGeneratedSourceDirectory(
        icons, GenerateAccordMemoLauncherIcons::outputDirectory
    )
}
