package com.example.optivus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the screen-time MethodChannel and delegate all calls to ScreenTimePlugin.
        val plugin = ScreenTimePlugin(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ScreenTimePlugin.CHANNEL
        ).setMethodCallHandler(plugin)
    }
}
