package dev.sagron.zerotrustauthenticator

import android.content.Intent
import android.os.Bundle

/**
 * The app as opened from the launcher, from a link, from the home screen
 * widget or the Quick Settings tile, or by ZT Keyboard's code chip (see
 * [CodePick]).
 */
class MainActivity : CodeActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Not when Android rebuilds the screen from its saved state: the
        // scanner was asked for once, not every time.
        if (savedInstanceState == null) startAction = startActionOf(intent)
        super.onCreate(savedInstanceState)
    }

    /** The widget's scan button or the shortcut, with the app already open. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        startActionOf(intent)?.let { startAction = it }
    }

    private fun startActionOf(intent: Intent?): String? {
        if (intent == null || intent.action != ACTION_SCAN) return null
        // Reopened from the recent apps list: that is not a new request.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return "scan"
    }

    override fun askedForCode(): Boolean = CodePick.isPick(intent)

    override fun askerAllowed(): Boolean = CodePick.callerAllowed(this)

    override fun readRequest(): Map<String, String?> = CodePick.request(this, intent)

    override fun deliver(code: String?, validUntil: Long?) =
        CodePick.answer(this, code, validUntil)

    companion object {
        /** Opens the QR scanner (after unlocking). Harmless from anyone. */
        const val ACTION_SCAN = "dev.sagron.zerotrustauthenticator.action.SCAN"
    }
}
