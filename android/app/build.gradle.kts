import java.util.Properties
import java.util.Base64
import java.net.URI
import java.net.InetAddress
import java.security.KeyStore
import java.security.PrivateKey
import java.security.cert.X509Certificate
import javax.naming.ldap.LdapName

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Final identity selected by the team; never substitute a development ID.
val finalApplicationId = "com.ispeak.app"
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use(::load)
    }
}

fun validateApiConfiguration() {
    val definitions = try {
        (providers.gradleProperty("dart-defines").orNull ?: "")
            .split(',').filter(String::isNotBlank)
            .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
    } catch (_: Exception) {
        throw GradleException("Invalid dart-defines encoding; supply API_BASE_URL through flutter --dart-define")
    }
    val urls = definitions.filter { it.startsWith("API_BASE_URL=") }
    require(urls.size == 1 && urls.single().substringAfter('=').isNotBlank()) {
        "Release requires exactly one explicit --dart-define=API_BASE_URL=https://<approved-api>/api"
    }
    val value = urls.single().substringAfter('=')
    val uri = try { URI(value) } catch (_: Exception) {
        throw GradleException("Release API_BASE_URL must be a valid HTTPS URL")
    }
    require(value == value.trim() && uri.scheme == "https" && !uri.host.isNullOrBlank()) {
        "Release API_BASE_URL must be a valid HTTPS URL with a host"
    }
    require(uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null) {
        "Release API_BASE_URL must contain no credentials, query parameters or fragment"
    }
    val host = uri.host.lowercase().removePrefix("[").removeSuffix("]").trimEnd('.')
    require(host != "localhost" && !host.endsWith(".localhost") && !host.endsWith(".local")) {
        "Release API_BASE_URL must not target localhost or a local network"
    }
    // Parse only numeric literals; never perform DNS lookups during a build.
    if (host.contains(':') || host.matches(Regex("[0-9.]+"))) {
        val address = try { InetAddress.getByName(host) } catch (_: Exception) {
            throw GradleException("Release API_BASE_URL has an invalid IP address")
        }
        val bytes = address.address
        val uniqueLocalV6 = bytes.size == 16 && (bytes[0].toInt() and 0xfe) == 0xfc
        val carrierNat = bytes.size == 4 && (bytes[0].toInt() and 0xff) == 100 &&
            (bytes[1].toInt() and 0xff) in 64..127
        require(!address.isAnyLocalAddress && !address.isLoopbackAddress &&
            !address.isSiteLocalAddress && !address.isLinkLocalAddress &&
            !address.isMulticastAddress && !uniqueLocalV6 && !carrierNat) {
            "Release API_BASE_URL must not target localhost or a local network"
        }
    }
}

fun validateSigningConfiguration() {
    require(keystorePropertiesFile.isFile) {
        "android/key.properties is required for release signing; copy key.properties.example and configure the team's private keystore"
    }
    val required = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missing = required.filter {
        val value = keystoreProperties.getProperty(it)
        value.isNullOrBlank() || value.startsWith("REPLACE_", ignoreCase = true)
    }
    require(missing.isEmpty()) { "Missing release signing values: ${missing.joinToString(", ")}" }
    require(keystoreProperties.getProperty("keyAlias") != "androiddebugkey") {
        "Release signing must not use the Android debug key"
    }
    val store = file(keystoreProperties.getProperty("storeFile"))
    require(store.isFile && store.canRead()) { "Release storeFile must reference an existing readable keystore" }
    val storePassword = keystoreProperties.getProperty("storePassword").toCharArray()
    val keyPassword = keystoreProperties.getProperty("keyPassword").toCharArray()
    try {
        val keystore = KeyStore.getInstance(store, storePassword)
        val alias = keystoreProperties.getProperty("keyAlias")
        require(keystore.getKey(alias, keyPassword) is PrivateKey)
        val certificate = keystore.getCertificate(alias) as X509Certificate
        certificate.checkValidity()
        val isDebug = LdapName(certificate.subjectX500Principal.name).rdns.any {
            it.type.equals("CN", ignoreCase = true) && it.value.toString().equals("Android Debug", ignoreCase = true)
        }
        require(!isDebug)
    } catch (_: Exception) {
        // Never attach raw keystore exceptions, properties or passwords.
        throw GradleException("Release keystore validation failed; check passwords, private-key alias and certificate validity; Android debug certificates are forbidden")
    } finally {
        storePassword.fill('\u0000')
        keyPassword.fill('\u0000')
    }
}

// These validation-only tasks produce no APK/AAB and do not create secrets.
tasks.register("checkIspeakApiConfiguration") { doLast { validateApiConfiguration() } }
tasks.register("checkIspeakSigningConfiguration") { doLast { validateSigningConfiguration() } }

android {
    namespace = finalApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = finalApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let(::file)
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val isReleaseBuild = allTasks.any {
        it.project.path == project.path && it.name.contains("Release", ignoreCase = true)
    }
    if (isReleaseBuild) {
        validateApiConfiguration()
        validateSigningConfiguration()
    }
}

flutter {
    source = "../.."
}
