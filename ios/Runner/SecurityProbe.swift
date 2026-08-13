import Foundation
import LocalAuthentication
import Network
import UIKit

/// Reads the iPhone's security posture.
///
/// iOS deliberately tells apps very little about the rest of the system, and
/// that restraint is itself a security feature. So this probe reads what the
/// sandbox honestly permits and reports nothing else. Everything it cannot see
/// is handled on the Dart side as a question the user answers, rather than as a
/// value quietly invented here.
final class SecurityProbe {

    /// Newest iOS major release this build of the app knows about.
    private let latestKnownOsMajor = 26

    /// Oldest iOS major release still receiving security fixes from Apple.
    private let minimumSupportedOsMajor = 18

    private var errors: [String: String] = [:]

    func read() -> [String: Any] {
        errors.removeAll()

        let version = ProcessInfo.processInfo.operatingSystemVersion
        let indicators = jailbreakIndicators()
        let biometry = biometryState()

        return [
            "platform": "ios",
            "osVersion": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            "osMajor": version.majorVersion,
            "deviceModel": UIDevice.current.model,
            "latestKnownOsMajor": latestKnownOsMajor,
            "minimumSupportedOsMajor": minimumSupportedOsMajor,

            "hasScreenLock": hasPasscode(),
            "hasBiometricsEnrolled": biometry.enrolled,
            "biometryLabel": biometry.label,

            "isCompromised": !indicators.isEmpty,
            "compromiseReasons": indicators,
            "isEmulator": isSimulator(),
            "debuggerAttached": isDebuggerAttached(),
            "screenBeingCaptured": UIScreen.main.isCaptured,

            "vpnActive": isVPNActive(),
            "onOpenWifi": NSNull(), // Requires an entitlement Apple grants only to network apps.

            "securityPatchEpochMs": 0, // iOS ships fixes inside the version itself.

            "probeErrors": errors
        ]
    }

    // ------------------------------------------------------------------
    // Lock
    // ------------------------------------------------------------------

    /// `deviceOwnerAuthentication` succeeds only when *some* passcode exists,
    /// which is the one authoritative way to ask this question.
    private func hasPasscode() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    private func biometryState() -> (enrolled: Bool, label: String) {
        let context = LAContext()
        var error: NSError?
        let ok = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        let label: String
        switch context.biometryType {
        case .faceID: label = "Face ID"
        case .touchID: label = "Touch ID"
        case .opticID: label = "Optic ID"
        default: label = ""
        }

        // A biometry type with an enrolment error means the hardware is there
        // but nothing is registered, which is exactly the case worth flagging.
        if let error, error.code == LAError.biometryNotEnrolled.rawValue {
            return (false, label)
        }
        return (ok, ok ? label : "")
    }

    // ------------------------------------------------------------------
    // Integrity
    // ------------------------------------------------------------------

    /// Jailbreak detection is heuristic. Each indicator is reported with its
    /// reason so the user can judge it, rather than being handed a verdict.
    private func jailbreakIndicators() -> [String] {
        #if targetEnvironment(simulator)
        return []
        #else
        var found: [String] = []
        let fm = FileManager.default

        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/usr/bin/ssh"
        ]
        if let hit = paths.first(where: { fm.fileExists(atPath: $0) }) {
            found.append("A jailbreak file is present at \(hit).")
        }

        // A sandboxed app cannot write outside its container. If this succeeds,
        // the sandbox is not being enforced.
        let probePath = "/private/aegis_sandbox_probe"
        do {
            try "probe".write(toFile: probePath, atomically: true, encoding: .utf8)
            try? fm.removeItem(atPath: probePath)
            found.append("This app can write outside its sandbox.")
        } catch {
            // Expected on a healthy device.
        }

        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) {
            found.append("A jailbreak package manager is registered on this device.")
        }

        return found
        #endif
    }

    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// `P_TRACED` on our own process is set whenever a debugger is attached.
    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else {
            errors["debugger"] = "sysctl failed"
            return false
        }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // ------------------------------------------------------------------
    // Network
    // ------------------------------------------------------------------

    /// A VPN registers a `utun`, `ppp` or `ipsec` interface in the CFNetwork
    /// proxy dictionary. This is the only way to observe it without the
    /// Network Extension entitlement.
    private func isVPNActive() -> Bool {
        guard let settings = CFNetworkCopySystemProxySettings()?
            .takeRetainedValue() as? [String: Any],
              let scoped = settings["__SCOPED__"] as? [String: Any]
        else { return false }

        let vpnPrefixes = ["tap", "tun", "ppp", "ipsec", "utun"]
        return scoped.keys.contains { key in
            vpnPrefixes.contains { key.hasPrefix($0) }
        }
    }
}
