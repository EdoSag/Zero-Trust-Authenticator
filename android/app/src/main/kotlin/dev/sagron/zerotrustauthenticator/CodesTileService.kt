package dev.sagron.zerotrustauthenticator

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * The Quick Settings tile: one tap from any screen opens ZT Authenticator.
 * It only opens the app. Codes show there, after unlocking as usual.
 */
class CodesTileService : TileService() {
    override fun onStartListening() {
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    @Suppress("DEPRECATION")
    override fun onClick() {
        val open = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val start = Runnable {
            if (Build.VERSION.SDK_INT >= 34) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(this, 2, open, PendingIntent.FLAG_IMMUTABLE),
                )
            } else {
                startActivityAndCollapse(open)
            }
        }
        // From the lock screen: the phone is unlocked first.
        if (isLocked) unlockAndRun(start) else start.run()
    }
}
