package dev.sagron.zerotrustauthenticator

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle

/**
 * Copies a code so that Android does not show it in the clipboard preview,
 * and clears it again after a while.
 */
object PrivateClipboard {
    /** Marks a clip as this app's, so the timed clear can tell it apart. */
    private const val LABEL = "ZT Authenticator code"

    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    fun copy(context: Context, text: String, clearAfterMs: Long?) {
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return
        val clip = ClipData.newPlainText(LABEL, text)
        // ClipDescription.EXTRA_IS_SENSITIVE (Android 13); older versions ignore it.
        clip.description.extras = PersistableBundle().apply {
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        clipboard.setPrimaryClip(clip)

        pending?.let { handler.removeCallbacks(it) }
        pending = null
        if (clearAfterMs == null || clearAfterMs <= 0) return
        val clear = Runnable {
            pending = null
            try {
                // Only the description is looked at (reading the text itself
                // makes Android show a "pasted from clipboard" notice). While
                // another app is in front Android shows this app nothing, and
                // the clipboard is cleared all the same: that is what was
                // asked for.
                val label = clipboard.primaryClipDescription?.label
                if (label == null || label == LABEL) clipboard.clearPrimaryClip()
            } catch (error: Exception) {
                // Nothing to clear, or the phone refused.
            }
        }
        pending = clear
        handler.postDelayed(clear, clearAfterMs)
    }
}
