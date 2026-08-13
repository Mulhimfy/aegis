package app.aegis.aegis

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "app.aegis/probe"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val probe = SecurityProbe(applicationContext)
        val router = SettingsRouter(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> try {
                        result.success(probe.read())
                    } catch (e: Throwable) {
                        result.error("read_failed", e.message, null)
                    }

                    "openSettings" -> {
                        val target = call.argument<String>("target")
                        if (target == null) {
                            result.error("bad_args", "No target given.", null)
                        } else {
                            result.success(router.open(target))
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
