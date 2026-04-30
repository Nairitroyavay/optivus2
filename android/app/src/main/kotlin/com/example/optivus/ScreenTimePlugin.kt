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
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // INTERVAL_DAILY gives one stats entry per app covering the full day.
        // We also run an event scan for unlock count.
        val statsMap = usageStatsManager.queryAndAggregateUsageStats(startOfDay, now)

        // --- Total foreground time across all apps (seconds → minutes) ---
        val totalSeconds = statsMap.values.sumOf { it.totalTimeInForeground }
        val totalMinutes = (totalSeconds / 1000 / 60).toInt()

        // --- Top apps by foreground time ---
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
                    stat.packageName // fallback — package ID
                }
                mapOf(
                    "packageName" to stat.packageName,
                    "appName" to appName,
                    "minutes" to (stat.totalTimeInForeground / 1000 / 60).toInt()
                )
            }

        // --- Unlock count: count KEYGUARD_HIDDEN events ---
        val unlockCount = countUnlockEvents(usageStatsManager, startOfDay, now)

        return mapOf(
            "totalMinutes" to totalMinutes,
            "unlockCount" to unlockCount,
            "topApps" to topApps,
            "capturedAt" to now,
            "schemaVersion" to 1
        )
    }

    /**
     * Counts the number of times the device was unlocked today by scanning
     * UsageEvents for KEYGUARD_HIDDEN events (API 23+).
     * Returns 0 on API < 23 or if scanning fails.
     */
    private fun countUnlockEvents(
        usageStatsManager: UsageStatsManager,
        startMs: Long,
        endMs: Long
    ): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return 0
        return try {
            val events = usageStatsManager.queryEvents(startMs, endMs)
            val event = UsageEvents.Event()
            var count = 0
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.KEYGUARD_HIDDEN) count++
            }
            count
        } catch (_: Exception) {
            0
        }
    }
}
