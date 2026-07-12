package com.studyquest.studyquest

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            // Start MainActivity to allow Flutter initialization and alarm rescheduling on boot
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("boot_reschedule", true)
                }
                context.startActivity(launchIntent)
            }
        }
    }
}
