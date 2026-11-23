package dev.sagron.zerotrustauthenticator

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * (local_auth) needs a FragmentActivity.
 */
class MainActivity : FlutterFragmentActivity() {
    /** Who a code was asked for, while ZT Keyboard waits for one (see [CodePick]). */
    private var codeRequest: Map<String, String?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Codes and keys never show in screenshots, screen recordings, casts
        // or the recent-apps preview.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        // A code request is only honoured here, where Android names the app
        // that is waiting for the answer, never in onNewIntent.
        val asked = CodePick.isPick(intent)
        val allowed = asked && CodePick.callerAllowed(this)
        if (allowed) codeRequest = CodePick.request(this, intent)
        super.onCreate(savedInstanceState)
        if (asked && !allowed) CodePick.answer(this, null, null)
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
                            CodePick.answer(
                                this,
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
                    else -> result.notImplemented()
                }
            }
    }
}
