package com.quiacago.quiaca_go_conductor

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.quiacago/screen_awake"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setKeepScreenOn") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val enabled = call.arguments as? Boolean ?: false
            runOnUiThread {
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
            result.success(null)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.quiacago/passenger_background"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9043
                        )
                    }
                    val intent = Intent(this, PassengerTripForegroundService::class.java)
                    arguments?.forEach { (key, value) ->
                        if (key is String && value is String) intent.putExtra(key, value)
                    }
                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("PASSENGER_SERVICE_START_FAILED", error.message, null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, PassengerTripForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.quiacago/driver_background"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            9042
                        )
                    }
                    val intent = Intent(this, DriverForegroundService::class.java)
                    arguments?.forEach { (key, value) ->
                        if (key is String && value is String) intent.putExtra(key, value)
                    }
                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("BACKGROUND_SERVICE_START_FAILED", error.message, null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, DriverForegroundService::class.java))
                    result.success(null)
                }
                "isRunning" -> result.success(DriverForegroundService.isActive)
                "getSession" -> result.success(
                    mapOf(
                        "accessToken" to DriverForegroundService.currentAccessToken,
                        "refreshToken" to DriverForegroundService.currentRefreshToken
                    )
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        DriverForegroundService.appInForeground = true
        PassengerTripForegroundService.appInForeground = true
    }

    override fun onPause() {
        DriverForegroundService.appInForeground = false
        PassengerTripForegroundService.appInForeground = false
        super.onPause()
    }
}
