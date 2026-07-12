package com.studyquest.studyquest

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.*
import androidx.core.app.NotificationCompat
import java.io.File

class AlarmService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        var activeAlarmId: String? = null
        var activeAlarmTitle: String? = null
        var activeAlarmSubject: String? = null
        var activeAlarmTime: String? = null
        var isRinging = false

        // Broadcast actions
        const val ALARM_ACTION_BROADCAST = "com.studyquest.studyquest.ALARM_ACTION"
        const val EXTRA_ACTION = "alarm_action"
    }

    override fun onCreate() {
        super.onCreate()
        
        // 1. Acquire WakeLock to wake screen and keep CPU alive
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "StudyQuest:AlarmWakeLock"
        ).apply {
            acquire(10 * 60 * 1000L) // 10 minutes max lock timeout
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == "DISMISS") {
            sendActionToActivity("dismiss")
            stopSelf()
            return START_NOT_STICKY
        } else if (action == "SNOOZE") {
            sendActionToActivity("snooze")
            stopSelf()
            return START_NOT_STICKY
        }

        val taskId = intent?.getStringExtra("task_id") ?: ""
        val taskTitle = intent?.getStringExtra("task_title") ?: "Study Session"
        val taskSubject = intent?.getStringExtra("task_subject") ?: "General Study"
        val taskTime = intent?.getStringExtra("task_time") ?: ""

        activeAlarmId = taskId
        activeAlarmTitle = taskTitle
        activeAlarmSubject = taskSubject
        activeAlarmTime = taskTime
        isRinging = true

        // 2. Setup Foreground Notification Channel
        val channelId = "study_alarm_channel_v1"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Study Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High urgency study session alerts"
                enableLights(true)
                enableVibration(true)
                setSound(null, null) // Quiet channel because MediaPlayer plays ringtone
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        // 3. Pending Intent for Full Screen Intent
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("task_id", taskId)
            putExtra("task_title", taskTitle)
            putExtra("task_subject", taskSubject)
            putExtra("task_time", taskTime)
            putExtra("is_alarm_ringing", true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            flag
        )

        // Notification buttons
        val dismissIntent = Intent(this, AlarmService::class.java).apply { setAction("DISMISS") }
        val snoozeIntent = Intent(this, AlarmService::class.java).apply { setAction("SNOOZE") }
        
        val dismissPending = PendingIntent.getService(this, 1, dismissIntent, flag)
        val snoozePending = PendingIntent.getService(this, 2, snoozeIntent, flag)

        val appIconId = resources.getIdentifier("ic_launcher", "mipmap", packageName)

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(if (appIconId != 0) appIconId else android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("StudyQuest: Time to Study")
            .setContentText("$taskSubject - $taskTitle")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss", dismissPending)
            .addAction(android.R.drawable.ic_popup_sync, "Snooze 10 Min", snoozePending)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        startForeground(1001, notification)

        // 4. Play custom sound assets/audio/alarm.mp3 natively
        playAlarmSound()

        // 5. Start Vibration Pattern
        startVibrate()

        // 6. Auto-start the MainActivity to overlay on lockscren
        try {
            startActivity(fullScreenIntent)
        } catch (e: Exception) {
            // Activity start failed (could be background start restrictions)
        }

        return START_STICKY
    }

    private fun playAlarmSound() {
        try {
            val tempFile = File(cacheDir, "alarm_temp.mp3")
            if (!tempFile.exists() || tempFile.length() == 0L) {
                tempFile.createNewFile()
                assets.open("flutter_assets/assets/audio/alarm.mp3").use { input ->
                    tempFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }

            mediaPlayer = MediaPlayer().apply {
                setDataSource(tempFile.absolutePath)
                isLooping = true
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                } else {
                    setAudioStreamType(AudioManager.STREAM_ALARM)
                }
                prepare()
                start()
            }
        } catch (e: Exception) {
            // Fallback to system default alarm sound
            try {
                mediaPlayer = MediaPlayer().apply {
                    val alert = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                    setDataSource(applicationContext, alert)
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (ex: Exception) {
                // Sound failed
            }
        }
    }

    private fun startVibrate() {
        try {
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val pattern = longArrayOf(0, 500, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            // Vibration failed
        }
    }

    private fun sendActionToActivity(action: String) {
        // Send local broadcast to update running activity or notify Dart channel
        val intent = Intent(ALARM_ACTION_BROADCAST).apply {
            putExtra(EXTRA_ACTION, action)
            putExtra("task_id", activeAlarmId)
        }
        sendBroadcast(intent)

        // Also start MainActivity with the action to notify Flutter if backgrounded
        val activityIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("task_id", activeAlarmId)
            putExtra("alarm_action", action)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        try {
            startActivity(activityIntent)
        } catch (e: Exception) {
            // Failed
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRinging = false
        activeAlarmId = null
        activeAlarmTitle = null
        activeAlarmSubject = null
        activeAlarmTime = null

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (e: Exception) { /* ignore */ }

        try {
            vibrator?.cancel()
        } catch (e: Exception) { /* ignore */ }

        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) { /* ignore */ }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
