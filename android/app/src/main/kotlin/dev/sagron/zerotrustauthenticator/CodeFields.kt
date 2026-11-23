package dev.sagron.zerotrustauthenticator

import android.app.assist.AssistStructure
import android.app.assist.AssistStructure.ViewNode
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId

/** The field (or the boxes, one per character) on a screen that wants a code. */
class CodeField(val ids: List<AutofillId>, val domain: String?)

/**
 * Finds the field that asks for a one-time code on another app's screen,
 * from what Android's autofill shows of it. Careful rather than eager: a
 * field is only taken when the app or page says it is for a code, or its
 * name does and nothing says otherwise.
 */
object CodeFields {
    private class Candidate(
        val id: AutofillId,
        val domain: String?,
        val focused: Boolean,
        /** 1 to 8 for a box that holds one character of the code. */
        val position: Int?,
    )

    /** Hints apps and pages give a code field. */
    private val codeHints = setOf(
        "smsotpcode", "2faappotpcode", "emailotpcode", "otp", "otpcode", "totp",
        "one-time-code", "onetimecode",
    )

    /** Hints that say a field is for something else. */
    private val otherHints = listOf(
        "password", "username", "email", "phone", "name", "postal", "address",
        "creditcard", "cc-", "birth", "gender", "tel",
    )

    /** Names that can only mean a one-time code ("otp", "2fa", "user[otp_attempt]"). */
    private val codeWords = Regex(
        "otp|totp|2fa|mfa|two.?factor|two.?step|2.?step|one.?time|authenticator|" +
            "verif(y|ication).?code|auth(entication)?.?code|קוד אימות|קוד חד",
    )

    /** Names that may mean one, when the field is a short run of digits. */
    private val maybeCodeWords = Regex(
        "\\bcode\\b|security.?code|login.?code|sign.?in.?code|passcode|קוד",
    )

    /** Names that hold a code of another kind. */
    private val otherWords = Regex(
        "promo|coupon|voucher|discount|gift|zip|postal|country|area|cvv|cvc|card|" +
            "captcha|invite|referral|search|pin",
    )

    fun find(structure: AssistStructure): CodeField? {
        val found = ArrayList<Candidate>()
        for (i in 0 until structure.windowNodeCount) {
            walk(structure.getWindowNodeAt(i).rootViewNode, null, found)
        }
        val whole = found.filter { it.position == null }
        val boxes = found.filter { it.position != null }.sortedBy { it.position }
        val focused = whole.firstOrNull { it.focused }
        return when {
            focused != null -> CodeField(listOf(focused.id), focused.domain)
            boxes.size >= 4 && (whole.isEmpty() || boxes.any { it.focused }) ->
                CodeField(boxes.map { it.id }, boxes.first().domain)
            whole.isNotEmpty() -> CodeField(listOf(whole.first().id), whole.first().domain)
            else -> null
        }
    }

    private fun walk(node: ViewNode?, domain: String?, found: MutableList<Candidate>) {
        if (node == null) return
        // The site a web view shows; its fields are below it.
        val here = node.webDomain?.trim()?.takeIf { it.isNotEmpty() } ?: domain
        candidate(node, here)?.let(found::add)
        for (i in 0 until node.childCount) walk(node.getChildAt(i), here, found)
    }

    private fun candidate(node: ViewNode, domain: String?): Candidate? {
        val id = node.autofillId ?: return null
        if (node.visibility != View.VISIBLE) return null
        val html = node.htmlInfo
        val attributes = HashMap<String, String>()
        html?.attributes?.forEach { pair ->
            val key = pair.first
            val value = pair.second
            if (key != null && value != null) attributes[key.lowercase()] = value.lowercase()
        }
        val isInput = html?.tag?.lowercase() == "input"
        if (node.autofillType != View.AUTOFILL_TYPE_TEXT && !isInput) return null
        val type = attributes["type"]
        if (type != null && type !in setOf("text", "tel", "number", "password")) return null

        val hints = node.autofillHints.orEmpty().map { it.lowercase() } +
            listOfNotNull(attributes["autocomplete"])

        // The app or page says so itself.
        for (hint in hints) {
            if (hint in codeHints) return Candidate(id, domain, node.isFocused, null)
            // "smsOTPCode1" to "smsOTPCode8": one box per character.
            if (hint.startsWith("smsotpcode")) {
                val position = hint.removePrefix("smsotpcode").toIntOrNull()
                if (position != null && position in 1..8) {
                    return Candidate(id, domain, node.isFocused, position)
                }
            }
        }
        // It says it is something else.
        if (hints.any { hint -> otherHints.any { hint.contains(it) } }) return null
        if (type == "password" || isPassword(node.inputType)) return null

        // Otherwise its name has to say so.
        val words = listOfNotNull(
            node.idEntry,
            node.hint,
            attributes["name"],
            attributes["id"],
            attributes["placeholder"],
            attributes["aria-label"],
        ).joinToString(" ").lowercase()
        if (words.isBlank()) return null
        if (codeWords.containsMatchIn(words)) {
            return Candidate(id, domain, node.isFocused, null)
        }
        // Just "code": only a short field of digits, and not a promo code,
        // a postcode or a card's security code.
        if (maybeCodeWords.containsMatchIn(words) &&
            !otherWords.containsMatchIn(words) &&
            isDigits(node, attributes)
        ) {
            val length = attributes["maxlength"]?.toIntOrNull() ?: node.maxTextLength
            if (length in 4..8) return Candidate(id, domain, node.isFocused, null)
        }
        return null
    }

    private fun isPassword(inputType: Int): Boolean {
        val kind = inputType and InputType.TYPE_MASK_CLASS
        val variation = inputType and InputType.TYPE_MASK_VARIATION
        return (kind == InputType.TYPE_CLASS_TEXT && variation in setOf(
            InputType.TYPE_TEXT_VARIATION_PASSWORD,
            InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,
            InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
        )) || (kind == InputType.TYPE_CLASS_NUMBER &&
            variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD)
    }

    private fun isDigits(node: ViewNode, attributes: Map<String, String>): Boolean =
        (node.inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_NUMBER ||
            attributes["type"] in setOf("tel", "number") ||
            attributes["inputmode"] in setOf("numeric", "decimal", "tel")
}
