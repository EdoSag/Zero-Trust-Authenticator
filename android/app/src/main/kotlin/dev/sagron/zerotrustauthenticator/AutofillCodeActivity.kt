package dev.sagron.zerotrustauthenticator

/**
 * The app as opened from Android's autofill suggestion "Code from ZT
 * Authenticator" (see [CodeAutofillService]): unlock as usual, pick the
 * account (or the linked one answers on its own), and the code is filled
 * into the field.
 *
 * Not exported: only this app's own autofill service can open it, through
 * the suggestion the user tapped.
 */
class AutofillCodeActivity : CodeActivity() {
    override fun askedForCode(): Boolean = true

    override fun askerAllowed(): Boolean = true

    override fun readRequest(): Map<String, String?> = CodeAutofill.request(this, intent)

    override fun deliver(code: String?, validUntil: Long?) =
        CodeAutofill.answer(this, intent, code)
}
