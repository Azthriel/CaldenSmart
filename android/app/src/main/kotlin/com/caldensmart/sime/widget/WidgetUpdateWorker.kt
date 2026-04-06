package com.caldensmart.sime.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.util.Log
import androidx.work.*
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.util.concurrent.TimeUnit

/**
 * Worker para actualizar widgets periódicamente.
 *
 * ⚠️ NO intenta reiniciar flutter_background_service desde aquí.
 *    startForegroundService() desde un Worker crashea con
 *    ForegroundServiceDidNotStartInTimeException porque Flutter tarda
 *    más de 5 segundos en inicializar. El WidgetBootReceiver se encarga
 *    del reinicio post-boot.
 *
 * Lo que sí hace:
 *  1. Envía HomeWidgetBackgroundIntent /update → despierta el isolate Dart
 *     para que llame syncWidgetsWithDatabase() con datos reales.
 *  2. Broadcast visual → onUpdate() redibuja con los datos recién guardados.
 */
class WidgetUpdateWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "WidgetUpdateWorker"
        private const val WORK_NAME = "widget_periodic_update"
        private const val ONE_TIME_WORK_NAME = "widget_boot_restart"

        fun schedule(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<WidgetUpdateWorker>(
                15, TimeUnit.MINUTES
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(
                    BackoffPolicy.LINEAR,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
            Log.d(TAG, "WorkManager periódico programado (15 min)")
        }

        fun scheduleOneTime(context: Context) {
            val workRequest = OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setInitialDelay(5, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                ONE_TIME_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                workRequest
            )
            Log.d(TAG, "WorkManager one-time programado")
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "WorkManager cancelado")
        }
    }

    override fun doWork(): Result {
        Log.d(TAG, "doWork: iniciando")

        return try {
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(applicationContext, ControlWidgetProvider::class.java)
            )

            if (widgetIds.isEmpty()) {
                Log.d(TAG, "doWork: no hay widgets activos")
                return Result.success()
            }

            Log.d(TAG, "doWork: ${widgetIds.size} widgets → ${widgetIds.joinToString()}")

            // Paso 1: despertar el isolate Dart para sincronizar datos reales
            // backgroundCallback en widget_handler.dart maneja caldensmart://widget/update
            try {
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    applicationContext,
                    Uri.parse("caldensmart://widget/update")
                )
                backgroundIntent.send()
                Log.d(TAG, "doWork: HomeWidgetBackgroundIntent /update enviado")
            } catch (e: Exception) {
                Log.e(TAG, "doWork: error enviando background intent: ${e.message}")
                // No es fatal, seguimos con el refresh visual
            }

            // Paso 2: refresh visual con los datos que ya están en SharedPrefs
            // (el isolate Dart del paso 1 los actualizará async)
            val intent = Intent(applicationContext, ControlWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            }
            applicationContext.sendBroadcast(intent)

            Log.d(TAG, "doWork: completado")
            Result.success()

        } catch (e: Exception) {
            Log.e(TAG, "doWork: error — ${e.message}", e)
            Result.retry()
        }
    }
}