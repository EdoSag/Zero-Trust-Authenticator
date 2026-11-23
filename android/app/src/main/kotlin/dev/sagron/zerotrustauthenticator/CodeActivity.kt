package dev.sagron.zerotrustauthenticator

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * What both screens of the app share: no screenshots, and the channel the
 * Dart side talks to (who asked for a code, handing the code back, the
 * private clipboard, the autofill switch).
 *
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * (local_auth) needs a FragmentActivity.
 */
abstract class CodeActivity : FlutterFragmentActivity() {
    /** Who a code was asked for, while the asker waits for one. */
    private var codeRequest: Map<String, String?>? = null

    /** Whether this screen was opened to hand a code back. */
    protected abstract fun askedForCode(): Boolean

    /** Whether whoever opened it may have one. */
    protected abstract fun askerAllowed(): Boolean

    /** What the Dart side is told about the request. */
    protected abstract fun readRequest(): Map<String, String?>

    /** Hands [code] back (null declines) and closes the screen. */
    protected abstract fun deliver(code: String?, validUntil: Long?)

    override fun onCreate(savedInstanceState: Bundle?) {
        // Codes and keys never show in screenshots, screen recordings, casts
        // or the recent-apps preview.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        // A code request is only honoured here, where Android names the app
        // that is waiting for the answer, never in onNewIntent.
        val asked = askedForCode()
        val allowed = asked && askerAllowed()
        if (allowed) codeRequest = readRequest()
        super.onCreate(savedInstanceState)
        if (asked && !allowed) deliver(null, null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_authenticator/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pendingCodeRequest" -> result.success(codeRequest)
                    "answerCodeRequest" -> {
                        if (codeRequest != null) {
                            codeRequest = null
                            deliver(
                                call.argument<String>("code"),
                                call.argument<Number>("validUntil")?.toLong(),
                            )
                        }
                        result.success(null)
                    }
                    "copyPrivately" -> {
                        PrivateClipboard.copy(
                            applicationContext,
                            call.argument<String>("text").orEmpty(),
                            call.argument<Number>("clearAfterMs")?.toLong(),
                        )
                        result.success(null)
                    }
                    "autofillState" -> {
                        val manager = getSystemService(AutofillManager::class.java)
                        result.success(
                            mapOf(
                                "supported" to (manager?.isAutofillSupported == true),
                                "enabled" to (manager?.hasEnabledAutofillServices() == true),
                            ),
                        )
                    }
                    "setAutofill" -> {
                        try {
                            if (call.argument<Boolean>("on") == true) {
                                // Android's own screen: the user picks this app there.
                                startActivity(
                                    Intent(
                                        Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE,
                                        Uri.parse("package:$packageName"),
                                    ),
                                )
                            } else {
                                getSystemService(AutofillManager::class.java)
                                    ?.disableAutofillServices()
                            }
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("unavailable", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
