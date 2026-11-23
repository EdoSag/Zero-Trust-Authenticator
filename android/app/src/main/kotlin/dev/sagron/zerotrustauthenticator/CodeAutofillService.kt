package dev.sagron.zerotrustauthenticator

import android.app.PendingIntent
import android.content.Intent
import android.graphics.BlendMode
import android.graphics.drawable.Icon
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.InlinePresentation
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import androidx.autofill.inline.UiVersions
import androidx.autofill.inline.v1.InlineSuggestionUi

/**
 * Android autofill for one-time codes, for people who turn it on in
 * Settings. On a field that asks for a code, in any app or browser, Android
 * shows "Code from ZT Authenticator" (in the keyboard's suggestion row where
 * the keyboard supports it). Tapping it opens [AutofillCodeActivity].
 *
 * This service never sees a key or a code: it only says "there is a code
 * field here". The vault is unlocked in the app, by the user, and the code
 * is made there.
 *
 * It fills nothing but codes and saves nothing.
 */
class CodeAutofillService : AutofillService() {
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val response = try {
            respond(request)
        } catch (error: Exception) {
            null
        }
        callback.onSuccess(response)
    }

    /** Nothing is ever saved from other apps. */
    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    @Suppress("DEPRECATION")
    private fun respond(request: FillRequest): FillResponse? {
        val structure = request.fillContexts.lastOrNull()?.structure ?: return null
        val forPackage = structure.activityComponent?.packageName ?: return null
        if (forPackage == packageName) return null
        val field = CodeFields.find(structure) ?: return null

        val open = Intent(this, AutofillCodeActivity::class.java)
            .putExtra(CodePick.EXTRA_FOR_PACKAGE, forPackage)
            .putExtra(CodePick.EXTRA_FOR_DOMAIN, field.domain)
            .putParcelableArrayListExtra(CodeAutofill.EXTRA_FIELDS, ArrayList(field.ids))
        // Mutable: Android adds what it needs to fill the answer in.
        val mutable = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        val sender = PendingIntent.getActivity(
            this,
            0,
            open,
            PendingIntent.FLAG_CANCEL_CURRENT or mutable,
        ).intentSender

        val dataset = Dataset.Builder(RemoteViews(packageName, R.layout.autofill_code))
        for (id in field.ids) dataset.setValue(id, null)
        dataset.setAuthentication(sender)
        if (Build.VERSION.SDK_INT >= 30) {
            inline(request)?.let(dataset::setInlinePresentation)
        }
        return FillResponse.Builder().addDataset(dataset.build()).build()
    }

    /** The same suggestion for the keyboard's suggestion row. */
    @RequiresApi(30)
    private fun inline(request: FillRequest): InlinePresentation? {
        val spec = request.inlineSuggestionsRequest?.inlinePresentationSpecs?.firstOrNull()
            ?: return null
        if (!UiVersions.getVersions(spec.style).contains(UiVersions.INLINE_UI_VERSION_1)) {
            return null
        }
        // Where a long press on the suggestion leads: the app itself.
        val about = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val icon = Icon.createWithResource(this, R.mipmap.ic_launcher)
            .setTintBlendMode(BlendMode.DST)
        val content = InlineSuggestionUi.newContentBuilder(about)
            .setTitle(getString(R.string.autofill_code_title))
            .setStartIcon(icon)
            .setContentDescription(getString(R.string.autofill_code_title))
            .build()
        return InlinePresentation(content.slice, spec, false)
    }
}
