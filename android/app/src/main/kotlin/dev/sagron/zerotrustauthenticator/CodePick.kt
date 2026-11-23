package dev.sagron.zerotrustauthenticator

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager

/**
 * ZT Keyboard's code chip: on a field that wants a one-time code, the
 * keyboard opens this app, the user picks an account (or the linked one
 * answers on its own), and the keyboard types the code.
 *
 * Only a Zero-Trust app may ask. All of them are signed with the same key,
 * so the caller must carry this app's own signature; anyone else is turned
 * away before anything is shown. The answer is one code, digits only, and
 * only after the vault was unlocked as usual.
 */
object CodePick {
    const val ACTION = "bz.zerotrust.action.PICK_TEXT"

    /** Set by the keyboard's code chip; how it finds this app. */
    const val CATEGORY = "bz.zerotrust.category.ONE_TIME_CODE"

    /** The app the code will be typed into (its package name). */
    const val EXTRA_FOR_PACKAGE = "bz.zerotrust.extra.FOR_PACKAGE"

    /** The site the code will be typed into, when the keyboard knows it. */
    const val EXTRA_FOR_DOMAIN = "bz.zerotrust.extra.FOR_DOMAIN"

    const val EXTRA_TEXT = "bz.zerotrust.extra.TEXT"

    /** When the code stops working, in milliseconds since 1970. */
    const val EXTRA_VALID_UNTIL = "bz.zerotrust.extra.VALID_UNTIL"

    /**
     * Any PICK_TEXT counts, with or without [CATEGORY]: a code is the only
     * text this app hands out, so the keyboard's general "insert from a
     * Zero-Trust app" key gets the same picker.
     */
    fun isPick(intent: Intent?): Boolean = intent != null && intent.action == ACTION

    /**
     * Whether [activity] was opened, for an answer, by an app signed with
     * this app's key. Android only names the caller when it waits for an
     * answer, and that name cannot be faked by the caller.
     */
    fun callerAllowed(activity: Activity): Boolean {
        val caller = activity.callingPackage ?: return false
        return try {
            activity.packageManager.checkSignatures(activity.packageName, caller) ==
                PackageManager.SIGNATURE_MATCH
        } catch (error: Exception) {
            false
        }
    }

    /** What the Dart side is told about the request. */
    fun request(activity: Activity, intent: Intent): Map<String, String?> {
        val forPackage = intent.getStringExtra(EXTRA_FOR_PACKAGE)?.trim()?.takeIf { it.isNotEmpty() }
        val domain = intent.getStringExtra(EXTRA_FOR_DOMAIN)?.trim()?.takeIf { it.isNotEmpty() }
        return mapOf(
            "source" to "keyboard",
            "package" to forPackage,
            "domain" to domain,
            "appLabel" to forPackage?.let { appLabel(activity, it) },
        )
    }

    /** The app's name as the launcher shows it, or null when it can't be read. */
    fun appLabel(activity: Activity, packageName: String): String? = try {
        val manager = activity.packageManager
        manager.getApplicationLabel(manager.getApplicationInfo(packageName, 0))
            .toString().trim().takeIf { it.isNotEmpty() }
    } catch (error: Exception) {
        null
    }

    fun answer(activity: Activity, code: String?, validUntil: Long?) {
        if (code.isNullOrEmpty()) {
            activity.setResult(Activity.RESULT_CANCELED)
        } else {
            val data = Intent().putExtra(EXTRA_TEXT, code)
            if (validUntil != null) data.putExtra(EXTRA_VALID_UNTIL, validUntil)
            activity.setResult(Activity.RESULT_OK, data)
        }
        activity.finish()
    }
}
