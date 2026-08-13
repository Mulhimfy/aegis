package app.aegis.aegis

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Turns a named destination into the settings screen the user actually needs.
 *
 * The whole point of the app is that a finding is one tap from its fix, and
 * that only holds if the tap lands. Manufacturer skins move, rename and remove
 * these screens constantly, so each destination is a *chain*: the exact screen
 * first, then its parent, then the settings root. The user always ends up
 * somewhere, and the written steps shown beside the button cover the rest.
 */
class SettingsRouter(private val context: Context) {

    fun open(target: String): Boolean {
        val chain = chainFor(target) ?: return false
        for (intent in chain) {
            if (launch(intent)) return true
        }
        return false
    }

    private fun launch(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
            true
        } else {
            false
        }
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    private fun self(): Uri = Uri.fromParts("package", context.packageName, null)

    private fun chainFor(target: String): List<Intent>? {
        val root = Intent(Settings.ACTION_SETTINGS)

        return when (target) {
            "security" -> listOf(
                Intent(Settings.ACTION_SECURITY_SETTINGS),
                root
            )

            // SET_NEW_PASSWORD drops straight into the lock picker, one step
            // closer to done than the security screen it falls back to.
            "screenLock" -> listOf(
                Intent("android.app.action.SET_NEW_PASSWORD"),
                Intent(Settings.ACTION_SECURITY_SETTINGS),
                root
            )

            "biometrics" -> buildList {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    add(Intent(Settings.ACTION_BIOMETRIC_ENROLL))
                }
                add(Intent("android.settings.FINGERPRINT_SETUP"))
                add(Intent(Settings.ACTION_SECURITY_SETTINGS))
                add(root)
            }

            "lockScreenNotifications" -> listOf(
                Intent("android.settings.LOCK_SCREEN_NOTIFICATION_SETTINGS"),
                Intent("android.settings.NOTIFICATION_SETTINGS"),
                root
            )

            "displayTimeout" -> listOf(
                Intent(Settings.ACTION_DISPLAY_SETTINGS),
                root
            )

            "developerOptions" -> listOf(
                Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS),
                root
            )

            "systemUpdate" -> listOf(
                Intent("android.settings.SYSTEM_UPDATE_SETTINGS"),
                Intent(Settings.ACTION_DEVICE_INFO_SETTINGS),
                root
            )

            "accessibility" -> listOf(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
                root
            )

            "notificationAccess" -> listOf(
                // The platform constant really does carry the redundant ACTION_
                // prefix in its value.
                Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"),
                Intent("android.settings.NOTIFICATION_SETTINGS"),
                root
            )

            "deviceAdmins" -> listOf(
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.android.settings",
                        "com.android.settings.Settings\$DeviceAdminSettingsActivity"
                    )
                ),
                Intent(Settings.ACTION_SECURITY_SETTINGS),
                root
            )

            // Android publishes no intent for the Private DNS screen itself, so
            // the network settings root is as close as a deep link can get.
            "privateDns" -> listOf(
                Intent(Settings.ACTION_WIRELESS_SETTINGS),
                root
            )

            "wifi" -> listOf(
                Intent(Settings.ACTION_WIFI_SETTINGS),
                root
            )

            "vpn" -> listOf(
                Intent(Settings.ACTION_VPN_SETTINGS),
                Intent(Settings.ACTION_WIRELESS_SETTINGS),
                root
            )

            "unknownAppSources" -> listOf(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES),
                Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS),
                root
            )

            "backup" -> listOf(
                Intent("android.settings.privacy.PRIVACY_SETTINGS"),
                Intent("android.settings.BACKUP_AND_RESET_SETTINGS"),
                root
            )

            "playProtect" -> listOf(
                Intent(Intent.ACTION_VIEW, Uri.parse("market://launch?id=com.google.android.gms")),
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.gms")
                ),
                root
            )

            "findMyDevice" -> listOf(
                Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/android/find")),
                Intent(Settings.ACTION_SECURITY_SETTINGS),
                root
            )

            "appSettings" -> listOf(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, self()),
                root
            )

            "appPermissions" -> listOf(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, self()),
                root
            )

            else -> null
        }
    }
}
