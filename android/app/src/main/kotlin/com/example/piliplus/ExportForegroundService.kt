package com.example.piliplus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * 导出期间的前台服务。
 *
 * ffmpeg-kit 在应用进程内运行，Android 14+ 的缓存进程冻结会让长时间的转封装
 * 停滞甚至被杀。用一个 `dataSync` 类型的前台服务把进程钉在前台，
 * 同时在通知栏展示进度，让用户可以把导出放到后台继续。
 *
 * 只用框架 API 构建通知：app module 未显式依赖 androidx.core。
 */
class ExportForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.example.piliplus.export.START"
        const val ACTION_UPDATE = "com.example.piliplus.export.UPDATE"
        const val ACTION_STOP = "com.example.piliplus.export.STOP"
        const val ACTION_CANCEL = "com.example.piliplus.export.CANCEL"

        const val EXTRA_TITLE = "title"
        const val EXTRA_MESSAGE = "message"

        /** -1 表示进度未知，展示为不确定进度条。 */
        const val EXTRA_PROGRESS = "progress"

        private const val CHANNEL_ID = "export_progress"
        private const val NOTIFICATION_ID = 0x7E5D

        /** 用户从通知栏点了取消。由 [ExportChannel] 转发给 Dart。 */
        @Volatile
        var onCancelRequested: (() -> Unit)? = null

        fun start(context: Context, title: String, message: String) {
            val intent = Intent(context, ExportForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_MESSAGE, message)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, title: String, message: String, progress: Int) {
            context.startService(
                Intent(context, ExportForegroundService::class.java).apply {
                    action = ACTION_UPDATE
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_MESSAGE, message)
                    putExtra(EXTRA_PROGRESS, progress)
                },
            )
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, ExportForegroundService::class.java).apply {
                    action = ACTION_STOP
                },
            )
        }
    }

    private var started = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                onCancelRequested?.invoke()
                // 不在此处 stopSelf：等 Dart 侧真正结束后再撤下通知。
            }

            ACTION_STOP -> stopForegroundAndSelf()

            ACTION_START, ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "正在导出"
                val message = intent.getStringExtra(EXTRA_MESSAGE) ?: ""
                val progress = intent.getIntExtra(EXTRA_PROGRESS, -1)
                notify(title, message, progress)
            }
        }
        return START_NOT_STICKY
    }

    private fun notify(title: String, message: String, progress: Int) {
        ensureChannel()
        val notification = buildNotification(title, message, progress)
        if (started) {
            manager.notify(NOTIFICATION_ID, notification)
            return
        }
        started = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(
        title: String,
        message: String,
        progress: Int,
    ): Notification {
        val pendingFlags =
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val cancelIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, ExportForegroundService::class.java).setAction(ACTION_CANCEL),
            pendingFlags,
        )
        val contentIntent = PendingIntent.getActivity(
            this,
            2,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            pendingFlags,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

        builder
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(message)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress.coerceIn(0, 100), progress < 0)
            .addAction(Notification.Action.Builder(null, "取消", cancelIntent).build())

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "缓存导出",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "显示缓存导出进度"
                setShowBadge(false)
            },
        )
    }

    private fun stopForegroundAndSelf() {
        started = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        manager.cancel(NOTIFICATION_ID)
        stopSelf()
    }

    override fun onDestroy() {
        started = false
        super.onDestroy()
    }

    private val manager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
