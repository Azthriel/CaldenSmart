package com.caldensmart.sime.widget

import android.content.Context
import android.net.Uri
import androidx.work.*
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.util.concurrent.TimeUnit

/**
 * Worker para actualizar widgets periódicamente.
 * Garantiza que los widgets se actualicen incluso si el sistema mata el proceso.
 *
 * FIX: Además de refrescar visualmente, ahora envía un HomeWidgetBackgroundIntent
 * con la URI caldensmart://widget/update, que despierta el isolate de Dart
 * (backgroundCallback en widget_handler.dart) para sincronizar el estado real
 * desde DynamoDB. Esto resuelve el caso donde el background service de Flutter
 * está muerto y los datos en SharedPrefs quedaron obsoletos (mostrando "offline"
 * aunque el dispositivo esté online).
 */
class WidgetUpdateWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "WidgetUpdateWorker"
        private const val WORK_NAME = "widget_periodic_update"
        private const val ONE_TIME_WORK_NAME = "widget_boot_restart"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        /**
         * Programar actualizaciones periódicas de widgets
         */
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
            Log.d(TAG, "WorkManager programado para actualizaciones periódicas")
        }

        /**
         * Programar una ejecución única inmediata (usado como fallback después de boot)
         */
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
            Log.d(TAG, "WorkManager one-time programado para reinicio post-boot")
        }

        /**
         * Cancelar actualizaciones periódicas
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "WorkManager cancelado")
        }
    }

    override fun doWork(): Result {
        Log.d(TAG, "Ejecutando actualización de widgets")

        try {
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(applicationContext, ControlWidgetProvider::class.java)
            )

            if (widgetIds.isEmpty()) {
                Log.d(TAG, "No hay widgets activos, saltando actualización")
                return Result.success()
            }

            Log.d(TAG, "Actualizando ${widgetIds.size} widgets: ${widgetIds.joinToString()}")

            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isServiceReady = prefs.getBoolean("widget_service_ready", false)

            // ── Paso 1: intentar despertar el Flutter background service ──────────
            // Si el servicio no está ready, intentamos reiniciarlo (mismo comportamiento
            // que antes).
            if (!isServiceReady) {
                Log.d(TAG, "widget_service_ready=false, intentando reiniciar Flutter background service")
                tryRestartFlutterService(applicationContext)
            }

            // ── Paso 2 (FIX): enviar HomeWidgetBackgroundIntent /update ───────────
            // Esto despierta el isolate de Dart (backgroundCallback en
            // widget_handler.dart) para que llame syncWidgetsWithDatabase() y guarde
            // el estado real de los dispositivos en SharedPrefs.
            // Es independiente del estado del background service: funciona tanto si
            // el servicio está vivo como si fue matado por el sistema.
            try {
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    applicationContext,
                    Uri.parse("caldensmart://widget/update")
                )
                backgroundIntent.send()
                Log.d(TAG, "HomeWidgetBackgroundIntent /update enviado → isolate Dart despertado")
            } catch (e: Exception) {
                Log.e(TAG, "Error enviando HomeWidgetBackgroundIntent: ${e.message}")
                // No es fatal: el paso 3 aún refresca visualmente con los datos actuales
            }

            // ── Paso 3: refrescar visualmente todos los widgets ───────────────────
            // Esto hace que onUpdate() se ejecute y muestre los datos más recientes
            // de SharedPrefs (que deberían estar actualizados por el paso 2, aunque
            // puede haber un pequeño delay ya que el isolate corre async).
            val intent = Intent(applicationContext, ControlWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            }
            applicationContext.sendBroadcast(intent)

            Log.d(TAG, "Actualización de widgets completada exitosamente")
            return Result.success()

        } catch (e: Exception) {
            Log.e(TAG, "Error actualizando widgets: ${e.message}", e)
            return Result.retry()
        }
    }

    /**
     * Intenta reiniciar el Flutter background service si no está corriendo
     */
    private fun tryRestartFlutterService(context: Context) {
        try {
            val serviceIntent = Intent(context, Class.forName("id.flutter.flutter_background_service.BackgroundService"))

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Flutter background service reiniciado desde WorkManager")
        } catch (e: Exception) {
            Log.e(TAG, "No se pudo reiniciar Flutter background service: ${e.message}", e)
        }
    }
}