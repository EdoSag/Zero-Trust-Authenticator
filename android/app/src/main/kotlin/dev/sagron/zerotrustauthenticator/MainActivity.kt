package dev.sagron.zerotrustauthenticator

/**
 * The app as opened from the launcher, from a link, or by ZT Keyboard's
 * code chip (see [CodePick]).
 */
class MainActivity : CodeActivity() {
    override fun askedForCode(): Boolean = CodePick.isPick(intent)

    override fun askerAllowed(): Boolean = CodePick.callerAllowed(this)

    override fun readRequest(): Map<String, String?> = CodePick.request(this, intent)

    override fun deliver(code: String?, validUntil: Long?) =
        CodePick.answer(this, code, validUntil)
}
