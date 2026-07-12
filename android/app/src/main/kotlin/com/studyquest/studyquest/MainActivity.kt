package com.studyquest.studyquest

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.*
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.studyquest.studyquest/alarm"
    private var pendingAction: String? = null
    private var pendingActionTaskId: String? = null
    private var isAlarmActiveInIntent = false

    private val alarmReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.getStringExtra(AlarmService.EXTRA_ACTION)
            val taskId = intent.getStringExtra("task_id")
            if (action != null && taskId != null) {
                pendingAction = action
                pendingActionTaskId = taskId
                
                // Immediately notify Flutter over method channel if engine is running
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("onAlarmAction", mapOf(
                        "action" to action,
                        "task_id" to taskId
                    ))
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Register local broadcast receiver for service actions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(alarmReceiver, IntentFilter(AlarmService.ALARM_ACTION_BROADCAST), Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(alarmReceiver, IntentFilter(AlarmService.ALARM_ACTION_BROADCAST))
        }
        
        // Show over lockscreen and turn screen on
        setupLockscreenFlags()
        
        // Parse startup intent for alarm info
        parseIntent(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(alarmReceiver)
        } catch (e: Exception) { /* ignore */ }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        parseIntent(intent)
        
        // Trigger method channel call to Dart to show AlarmScreen immediately
        if (isAlarmActiveInIntent) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onAlarmRinging", mapOf(
                    "id" to intent.getStringExtra("task_id"),
                    "title" to intent.getStringExtra("task_title"),
                    "subject" to intent.getStringExtra("task_subject"),
                    "startTime" to intent.getStringExtra("task_time")
                ))
            }
        }

        val action = intent.getStringExtra("alarm_action")
        val taskId = intent.getStringExtra("task_id")
        if (action != null && taskId != null) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onAlarmAction", mapOf(
                    "action" to action,
                    "task_id" to taskId
                ))
            }
        }
    }

    private fun parseIntent(intent: Intent?) {
        isAlarmActiveInIntent = intent?.getBooleanExtra("is_alarm_ringing", false) == true
        val action = intent?.getStringExtra("alarm_action")
        val taskId = intent?.getStringExtra("task_id")
        if (action != null && taskId != null) {
            pendingAction = action
            pendingActionTaskId = taskId
        }
    }

    private fun setupLockscreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleExactAlarm" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val subject = call.argument<String>("subject") ?: ""
                    val time = call.argument<String>("time") ?: ""
                    val triggerTime = call.argument<Number>("triggerTime")?.toLong() ?: 0L
                    
                    scheduleAlarm(id, title, subject, time, triggerTime)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelAlarm(id)
                    result.success(true)
                }
                "stopAlarm" -> {
                    stopAlarmService()
                    result.success(true)
                }
                "getActiveAlarm" -> {
                    if (AlarmService.isRinging) {
                        result.success(mapOf(
                            "id" to AlarmService.activeAlarmId,
                            "title" to AlarmService.activeAlarmTitle,
                            "subject" to AlarmService.activeAlarmSubject,
                            "startTime" to AlarmService.activeAlarmTime
                        ))
                    } else {
                        result.success(null)
                    }
                }
                "consumeAlarmAction" -> {
                    if (pendingAction != null) {
                        val map = mapOf(
                            "action" to pendingAction,
                            "task_id" to pendingActionTaskId
                        )
                        pendingAction = null
                        pendingActionTaskId = null
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }
                "checkExactAlarmPermission" -> {
                    result.success(checkExactAlarmPermission())
                }
                "requestExactAlarmPermission" -> {
                    requestExactAlarmPermission()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleAlarm(id: String, title: String, subject: String, time: String, triggerTime: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("task_id", id)
            putExtra("task_title", title)
            putExtra("task_subject", subject)
            putExtra("task_time", time)
        }
        
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            flag
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }
    }

    private fun cancelAlarm(id: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            flag
        )
        
        alarmManager.cancel(pendingIntent)
    }

    private fun stopAlarmService() {
        val serviceIntent = Intent(this, AlarmService::class.java)
        stopService(serviceIntent)
    }

    private fun checkExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return alarmManager.canScheduleExactAlarms()
        }
        return true
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!checkExactAlarmPermission()) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
                startActivity(intent)
            }
        }
    }
}
