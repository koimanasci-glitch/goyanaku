package id.goyana.preview.goyana_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Shows queue reminders scheduled by LocalNotifications.schedule from the web page. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, 0)
        remember(context, id, false)
        ensureChannel(context)
        val open = PendingIntent.getActivity(
            context, id,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
        else @Suppress("DEPRECATION") Notification.Builder(context)
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(intent.getStringExtra(EXTRA_TITLE) ?: "GOYANA")
            .setContentText(intent.getStringExtra(EXTRA_BODY) ?: "")
            .setStyle(Notification.BigTextStyle().bigText(intent.getStringExtra(EXTRA_BODY) ?: ""))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            nm.notify(id, notification)
        } catch (_: SecurityException) {
            // Notification permission was revoked after scheduling.
        }
    }

    companion object {
        private const val CHANNEL = "goyana_reminder"
        private const val EXTRA_ID = "id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        private const val PREFS = "goyana_reminders"

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Pengingat GOYANA", NotificationManager.IMPORTANCE_DEFAULT)
                        .apply { description = "Pengingat antrean dan pekerjaan laundry" })
            }
        }

        fun intent(context: Context, id: Int, title: String, body: String): PendingIntent =
            PendingIntent.getBroadcast(
                context, id,
                Intent(context, ReminderReceiver::class.java)
                    .putExtra(EXTRA_ID, id).putExtra(EXTRA_TITLE, title).putExtra(EXTRA_BODY, body),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        fun remember(context: Context, id: Int, active: Boolean) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val ids = prefs.getStringSet("ids", emptySet())!!.toMutableSet()
            if (active) ids.add(id.toString()) else ids.remove(id.toString())
            prefs.edit().putStringSet("ids", ids).apply()
        }

        fun pending(context: Context): List<Int> =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getStringSet("ids", emptySet())!!.mapNotNull { it.toIntOrNull() }
    }
}
