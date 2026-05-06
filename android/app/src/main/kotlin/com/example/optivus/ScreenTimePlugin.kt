package com.example.optivus

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * ScreenTimePlugin
 *
 * Exposes Android UsageStatsManager data to Flutter over MethodChannel
 * com.example.optivus/screen_time.
 *
 * Methods:
 *   hasPermission      -> Boolean
 *   requestPermission  -> (void, opens system settings)
 *   query              -> Map with totalMinutes, topApps, unlockCount, capturedAt, schemaVersion
 *   lockApp            -> (void, mutes notifications for package - placeholder)
 */
class ScreenTimePlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.example.optivus/screen_time"
        private const val TOP_APPS_COUNT = 5
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasUsagePermission())
            "requestPermission" -> {
                openUsageSettings()
                result.success(null)
            }
            "query" -> {
                if (!hasUsagePermission()) {
                    result.error("PERMISSION_DENIED", "Usage access not granted", null)
                    return
                }
                try {
                    result.success(queryTodayStats())
                } catch (e: Exception) {
                    result.error("QUERY_FAILED", e.message, null)
                }
            }
            "lockApp" -> {
                // In a production app, this would involve NotificationManager / AppOps
                // to silence notifications or set a temporary restriction.
                // For this prototype, we log it and return success.
                val packageName = call.argument<String>("packageName")
                android.util.Log.i("ScreenTimePlugin", "Locking app for 1hr: $packageName")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Permission helpers ────────────────────────────────────────────────────

    private fun hasUsagePermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    // ── Query ─────────────────────────────────────────────────────────────────

    private fun queryTodayStats(): Map<String, Any?> {
        val now = System.currentTimeMillis()

        // Start of today (midnight local time)
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDay = calendar.timeInMillis

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // 1. Basic aggregated stats
        val statsMap = usageStatsManager.queryAndAggregateUsageStats(startOfDay, now)
        val totalSeconds = statsMap.values.sumOf { it.totalTimeInForeground }
        val totalMinutes = (totalSeconds / 1000 / 60).toInt()

        // 2. Event processing for Hourly Distribution and App Unlocks
        val hourlyMins = MutableList(24) { 0 }
        val appUnlocks = mutableMapOf<String, Int>()
        var totalUnlocks = 0

        val events = usageStatsManager.queryEvents(startOfDay, now)
        val event = UsageEvents.Event()
        
        var lastApp: String? = null
        var lastEventTime = startOfDay
        var isLocked = true

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val eventTime = event.timeStamp
            val hour = Calendar.getInstance().apply { timeInMillis = eventTime }.get(Calendar.HOUR_OF_DAY)

            // Track foreground time for hourly distribution
            if (lastApp != null && !isLocked) {
                val durationMs = eventTime - lastEventTime
                hourlyMins[hour] += (durationMs / 1000 / 60).toInt()
            }

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    lastApp = event.packageName
                    lastEventTime = eventTime
                    isLocked = false
                }
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    lastApp = null
                    isLocked = true
                }
                UsageEvents.Event.KEYGUARD_HIDDEN -> {
                    totalUnlocks++
                    // If an app is resumed shortly after unlock, count it as an app unlock
                    isLocked = false
                }
                UsageEvents.Event.KEYGUARD_SHOWN -> {
                    isLocked = true
                }
            }
            
            // Heuristic: If we see a resume within 2s of a keyguard_hidden, attribute the unlock
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED && !isLocked) {
                appUnlocks[event.packageName] = (appUnlocks[event.packageName] ?: 0) + 1
            }
        }

        // 3. Top apps mapping
        val pm = context.packageManager
        val topApps = statsMap.values
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .take(TOP_APPS_COUNT)
            .map { stat ->
                val appName = try {
                    pm.getApplicationLabel(
                        pm.getApplicationInfo(stat.packageName, 0)
                    ).toString()
                } catch (_: PackageManager.NameNotFoundException) {
                    stat.packageName
                }
                mapOf(
                    "packageName" to stat.packageName,
                    "appName" to appName,
                    "minutes" to (stat.totalTimeInForeground / 1000 / 60).toInt(),
                    "unlockCount" to (appUnlocks[stat.packageName] ?: 0)
                )
            }

        return mapOf(
            "totalMinutes" to totalMinutes,
            "unlockCount" to totalUnlocks,
            "topApps" to topApps,
            "hourlyDistribution" to hourlyMins,
            "capturedAt" to now,
            "schemaVersion" to 1
        )
    }
}
