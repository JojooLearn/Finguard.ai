package com.finguard.finguard

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.finguard.app/local_notifications"
        private const val NOTIF_CHANNEL_ID = "finguard_high_importance_channel"
        private const val NOTIF_CHANNEL_NAME = "FinGuard Notifikasi Utama"
        private const val NOTIF_CHANNEL_DESC = "Peringatan anggaran, sinyal saham, dan info keuangan FinGuard"
        private const val PERMISSION_REQUEST_CODE = 1009
    }

    private var methodChannel: MethodChannel? = null
    private var pendingRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        intent?.getStringExtra("route")?.let {
            pendingRoute = it
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    val granted = ensureNotificationPermission()
                    result.success(granted)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "FinGuard"
                    val body = call.argument<String>("body") ?: ""
                    val route = call.argument<String>("route") ?: "/notifications"
                    val shown = showSystemStatusBarNotification(id, title, body, route)
                    result.success(shown)
                }
                "getInitialRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra("route")
        if (!route.isNullOrEmpty()) {
            methodChannel?.invokeMethod("onNotificationTapped", mapOf("route" to route))
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIF_CHANNEL_ID, NOTIF_CHANNEL_NAME, importance).apply {
                description = NOTIF_CHANNEL_DESC
                enableVibration(true)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun ensureNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissionStatus = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            )
            if (permissionStatus != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    PERMISSION_REQUEST_CODE
                )
                return false
            }
        }
        return true
    }

    private fun showSystemStatusBarNotification(
        notificationId: Int,
        title: String,
        body: String,
        route: String
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissionStatus = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            )
            if (permissionStatus != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    PERMISSION_REQUEST_CODE
                )
                return false
            }
        }

        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", route)
        }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            tapIntent,
            pendingFlags
        )

        val builder = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
        return true
    }
}
