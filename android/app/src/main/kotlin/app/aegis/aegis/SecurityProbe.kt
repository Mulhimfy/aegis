package app.aegis.aegis

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import androidx.biometric.BiometricManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * Reads the device's security posture.
 *
 * Every value here comes from a public Android API. Nothing is inferred from
 * another value, and anything that cannot be read is reported as absent rather
 * than guessed, so the score above it is never built on an assumption.
 *
 * The class holds no state and keeps nothing. It is called, it reads, it
 * returns a map, and the map never leaves the device.
 */
class SecurityProbe(private val context: Context) {

    /** Newest Android major release this build of the app knows about. */
    private val latestKnownOsMajor = 16

    /**
     * Oldest Android major release still receiving security fixes from Google.
     * Android 13 is the current floor; raise this as older releases fall out of
     * support.
     */
    private val minimumSupportedOsMajor = 13

    /** Readings that failed, so the Dart side can exclude them from the score. */
    private val errors = linkedMapOf<String, String>()

    fun read(): Map<String, Any?> {
        errors.clear()
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager

        return mapOf(
            "platform" to "android",
            "osVersion" to Build.VERSION.RELEASE,
            "osMajor" to majorVersion(),
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            "latestKnownOsMajor" to latestKnownOsMajor,
            "minimumSupportedOsMajor" to minimumSupportedOsMajor,

            "hasScreenLock" to (keyguard?.isDeviceSecure ?: false),
            "hasBiometricsEnrolled" to hasBiometricsEnrolled(),
            "biometryLabel" to if (hasBiometricsEnrolled()) "Fingerprint or face" else "",
            "screenLockTimeoutMs" to screenLockTimeoutMs(),
            "lockScreenShowsSensitiveContent" to lockScreenShowsSensitiveContent(),

            "isCompromised" to rootIndicators().isNotEmpty(),
            "compromiseReasons" to rootIndicators(),
            "isEmulator" to isEmulator(),
            "debuggerAttached" to android.os.Debug.isDebuggerConnected(),
            "screenBeingCaptured" to false, // Android gives apps no way to observe this.
            "storageEncrypted" to storageEncrypted(),
            "securityPatchEpochMs" to securityPatchEpochMs(),

            "developerOptionsEnabled" to globalFlag(Settings.Global.DEVELOPMENT_SETTINGS_ENABLED),
            "usbDebuggingEnabled" to globalFlag(Settings.Global.ADB_ENABLED),
            "playProtectEnabled" to playProtectEnabled(),
            "cloudBackupEnabled" to backupEnabled(),

            "accessibilityServices" to accessibilityServices(),
            "notificationListeners" to notificationListeners(),
            "deviceAdmins" to deviceAdmins(),

            "vpnActive" to vpnActive(),
            "onOpenWifi" to onOpenWifi(),
            "encryptedDnsEnabled" to encryptedDnsEnabled(),

            "probeErrors" to errors.toMap()
        )
    }

    // ------------------------------------------------------------------
    // Version and patch level
    // ------------------------------------------------------------------

    private fun majorVersion(): Int =
        Build.VERSION.RELEASE?.substringBefore('.')?.toIntOrNull() ?: 0

    /**
     * Build.VERSION.SECURITY_PATCH is a `yyyy-MM-dd` string set by the vendor.
     * It is the only honest measure of whether a phone is actually patched, as
     * opposed to merely running a recent version number.
     */
    private fun securityPatchEpochMs(): Long = guard("securityPatch", 0L) {
        val raw = Build.VERSION.SECURITY_PATCH
        if (raw.isNullOrBlank()) return@guard 0L
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        format.parse(raw)?.time ?: 0L
    }

    // ------------------------------------------------------------------
    // Lock
    // ------------------------------------------------------------------

    private fun hasBiometricsEnrolled(): Boolean = guard("biometrics", false) {
        val manager = BiometricManager.from(context)
        val strong = manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        val weak = manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)
        strong == BiometricManager.BIOMETRIC_SUCCESS || weak == BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun screenLockTimeoutMs(): Int? = guard("screenTimeout", null) {
        Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT)
    }

    /**
     * `LOCK_SCREEN_ALLOW_PRIVATE_NOTIFICATIONS` is 1 when notification bodies
     * are shown in full on the lock screen. That is where one-time codes leak.
     */
    private fun lockScreenShowsSensitiveContent(): Boolean? = guard("lockScreenPrivacy", null) {
        val showAtAll = Settings.Secure.getInt(
            context.contentResolver,
            "lock_screen_show_notifications",
            1
        )
        if (showAtAll == 0) return@guard false
        Settings.Secure.getInt(
            context.contentResolver,
            "lock_screen_allow_private_notifications",
            1
        ) == 1
    }

    // ------------------------------------------------------------------
    // Integrity
    // ------------------------------------------------------------------

    /**
     * Root detection is heuristic by nature. Each indicator on its own can have
     * an innocent explanation, so the reasons are surfaced to the user rather
     * than collapsed into a bare verdict they cannot argue with.
     */
    private fun rootIndicators(): List<String> = guard("root", emptyList()) {
        val found = mutableListOf<String>()

        if (Build.TAGS?.contains("test-keys") == true) {
            found += "The system build is signed with test keys, not the manufacturer's."
        }

        val binaries = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su",
            "/system/app/Superuser.apk", "/data/local/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su"
        )
        binaries.firstOrNull { safeExists(it) }?.let {
            found += "A superuser binary is present at $it."
        }

        val managers = listOf(
            "com.topjohnwu.magisk", "eu.chainfire.supersu",
            "com.noshufou.android.su", "com.koushikdutta.superuser"
        )
        managers.firstOrNull { isPackageInstalled(it) }?.let {
            found += "A root manager app is installed."
        }

        if (safeExists("/system/xbin/busybox") || safeExists("/system/bin/busybox")) {
            found += "BusyBox is installed in the system partition."
        }

        // A writable /system is the clearest single sign the partition has been
        // remounted, which stock Android never does.
        if (File("/system").canWrite()) {
            found += "The system partition is writable."
        }

        found
    }

    private fun safeExists(path: String): Boolean = try {
        File(path).exists()
    } catch (_: SecurityException) {
        false
    }

    private fun isPackageInstalled(name: String): Boolean = try {
        context.packageManager.getPackageInfo(name, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    } catch (_: Exception) {
        false
    }

    private fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.contains("vbox") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for") ||
            Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu") ||
            Build.PRODUCT == "sdk_gphone64_arm64"

    /**
     * File-based encryption has been mandatory since Android 10, so on every
     * supported release this is true. It is still read rather than assumed,
     * because a device that reports otherwise is exactly the device that needs
     * to be told.
     */
    private fun storageEncrypted(): Boolean? = guard("encryption", null) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            ?: return@guard null
        when (dpm.storageEncryptionStatus) {
            DevicePolicyManager.ENCRYPTION_STATUS_UNSUPPORTED -> false
            DevicePolicyManager.ENCRYPTION_STATUS_INACTIVE -> false
            else -> true
        }
    }

    // ------------------------------------------------------------------
    // App reach
    // ------------------------------------------------------------------

    /**
     * Apps holding an accessibility service see every word on screen and can
     * act on the user's behalf. The list is read from Settings.Secure, and each
     * package is resolved to its user-visible label so the finding names real
     * apps rather than package IDs.
     */
    private fun accessibilityServices(): List<Map<String, String>> =
        guard("accessibility", emptyList()) {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return@guard emptyList()

            val accessibilityOn = Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED,
                0
            )
            if (accessibilityOn == 0) return@guard emptyList()

            splitComponents(enabled)
                .filterNot { isSystemPackage(it) }
                .map { described(it) }
        }

    private fun notificationListeners(): List<Map<String, String>> =
        guard("notificationListeners", emptyList()) {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: return@guard emptyList()
            splitComponents(enabled)
                .filterNot { isSystemPackage(it) }
                .map { described(it) }
        }

    private fun deviceAdmins(): List<Map<String, String>> = guard("deviceAdmins", emptyList()) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            ?: return@guard emptyList()
        (dpm.activeAdmins ?: emptyList())
            .map { it.packageName }
            .distinct()
            .filterNot { it == context.packageName }
            .filterNot { isSystemPackage(it) }
            .map { described(it) }
    }

    /** `a/b:c/d` colon-separated component names, reduced to package names. */
    private fun splitComponents(value: String): List<String> {
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(value)
        val packages = LinkedHashSet<String>()
        while (splitter.hasNext()) {
            val name = splitter.next().substringBefore('/').trim()
            if (name.isNotEmpty()) packages.add(name)
        }
        return packages.toList()
    }

    /** Reads a 0/1 flag from Settings.Global, or null when it is not present. */
    private fun globalFlag(key: String): Boolean? = guard(key, null) {
        when (Settings.Global.getInt(context.contentResolver, key, -1)) {
            -1 -> null
            0 -> false
            else -> true
        }
    }

    /**
     * Preinstalled system components are excluded: flagging the phone's own
     * screen reader as a threat would be noise, and noise is what makes people
     * stop reading security warnings.
     */
    private fun isSystemPackage(packageName: String): Boolean = try {
        val flags = context.packageManager.getApplicationInfo(packageName, 0).flags
        (flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
    } catch (_: Exception) {
        false
    }

    private fun described(packageName: String): Map<String, String> {
        val label = try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName
        }
        return mapOf("package" to packageName, "label" to label)
    }

    /**
     * The Play Protect toggle itself lives in Google's own settings provider,
     * which apps cannot read. `package_verifier_user_consent` is the closest
     * public signal: negative means the user actively declined app scanning.
     * When the platform has never asked, the honest answer is "unknown", and
     * the check drops out of the score rather than inventing a verdict.
     */
    private fun playProtectEnabled(): Boolean? = guard("playProtect", null) {
        val consent =
            Settings.Global.getInt(context.contentResolver, "package_verifier_user_consent", 0)
        val enabled =
            Settings.Global.getInt(context.contentResolver, "package_verifier_enable", 1)
        when {
            consent < 0 -> false
            enabled == 0 -> false
            consent > 0 -> true
            else -> null
        }
    }

    private fun backupEnabled(): Boolean? = guard("backup", null) {
        Settings.Secure.getInt(context.contentResolver, "backup_enabled", -1).let {
            if (it < 0) null else it == 1
        }
    }

    // ------------------------------------------------------------------
    // Network
    // ------------------------------------------------------------------

    private fun capabilities(): NetworkCapabilities? {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return null
        val network = cm.activeNetwork ?: return null
        return cm.getNetworkCapabilities(network)
    }

    private fun vpnActive(): Boolean = guard("vpn", false) {
        capabilities()?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
    }

    /**
     * Requires no location permission on Android 12+, where the security type
     * is exposed on WifiInfo directly. On older releases the platform ties this
     * to location access, so rather than ask for a permission the user would
     * rightly question, the check reports as unavailable.
     */
    private fun onOpenWifi(): Boolean? = guard("wifi", null) {
        val caps = capabilities() ?: return@guard null
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return@guard null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return@guard null

        val info = caps.transportInfo as? WifiInfo ?: return@guard null
        when (info.currentSecurityType) {
            WifiInfo.SECURITY_TYPE_OPEN -> true
            WifiInfo.SECURITY_TYPE_UNKNOWN -> null
            else -> false
        }
    }

    private fun encryptedDnsEnabled(): Boolean? = guard("privateDns", null) {
        when (Settings.Global.getString(context.contentResolver, "private_dns_mode")) {
            null -> null
            "off" -> false
            else -> true
        }
    }

    // ------------------------------------------------------------------

    /**
     * Runs one reading in isolation. A manufacturer skin that hides a setting,
     * or a future release that removes one, degrades that single check to
     * "unavailable" instead of failing the whole scan.
     */
    private inline fun <T> guard(name: String, fallback: T, block: () -> T): T = try {
        block()
    } catch (e: Throwable) {
        errors[name] = e.javaClass.simpleName
        fallback
    }
}
