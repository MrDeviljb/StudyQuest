package com.studyquest.studyquest

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("task_id") ?: ""
        val taskTitle = intent.getStringExtra("task_title") ?: "Study Session"
        val taskSubject = intent.getStringExtra("task_subject") ?: "General Study"
        val taskTime = intent.getStringExtra("task_time") ?: ""

        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra("task_id", taskId)
            putExtra("task_title", taskTitle)
            putExtra("task_subject", taskSubject)
            putExtra("task_time", taskTime)
        }

        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
