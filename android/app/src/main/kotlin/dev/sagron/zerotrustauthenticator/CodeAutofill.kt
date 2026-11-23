package dev.sagron.zerotrustauthenticator

import android.app.Activity
import android.content.Intent
import android.service.autofill.Dataset
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

/**
 * The autofill side of handing a code back: what [AutofillCodeActivity] was
 * asked for, and the answer Android fills into the field.
 */
object CodeAutofill {
    /** The field to fill, or one field per character for split code boxes. */
    const val EXTRA_FIELDS = "dev.sagron.zerotrustauthenticator.extra.FIELDS"

    @Suppress("DEPRECATION")
    private fun fields(intent: Intent): List<AutofillId> =
        intent.getParcelableArrayListExtra<AutofillId>(EXTRA_FIELDS).orEmpty()

    fun request(activity: Activity, intent: Intent): Map<String, String?> {
        val forPackage = intent.getStringExtra(CodePick.EXTRA_FOR_PACKAGE)
        return mapOf(
            // The site is what the other app says it is showing. The Dart
            // side believes it from browsers only.
            "source" to "autofill",
            "package" to forPackage,
            "domain" to intent.getStringExtra(CodePick.EXTRA_FOR_DOMAIN),
            "appLabel" to forPackage?.let { CodePick.appLabel(activity, it) },
        )
    }

    @Suppress("DEPRECATION")
    fun answer(activity: Activity, intent: Intent, code: String?) {
        val ids = fields(intent)
        if (code.isNullOrEmpty() || ids.isEmpty()) {
            activity.setResult(Activity.RESULT_CANCELED)
        } else {
            val builder = Dataset.Builder(
                RemoteViews(activity.packageName, R.layout.autofill_code),
            )
            if (ids.size == 1) {
                builder.setValue(ids[0], AutofillValue.forText(code))
            } else {
                // One box per character.
                ids.forEachIndexed { index, id ->
                    if (index < code.length) {
                        builder.setValue(id, AutofillValue.forText(code[index].toString()))
                    }
                }
            }
            activity.setResult(
                Activity.RESULT_OK,
                Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, builder.build()),
            )
        }
        activity.finish()
    }
}
