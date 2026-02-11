package com.caldensmart.sime.widget

import android.content.Context
import androidx.work.*
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * Worker para actualizar widgets periódicamente
 * Garantiza que los widgets se actualicen incluso si el sistema mata el proceso
 */
class WidgetUpdateWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "WidgetUpdateWorker"
        private const val WORK_NAME = "widget_periodic_update"

        /**
         * Programar actualizaciones periódicas de widgets
         */
        fun schedule(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<WidgetUpdateWorker>(
                15, TimeUnit.MINUTES // Mínimo 15 minutos en Android
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
         * Cancelar actualizaciones periódicas
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "WorkManager cancelado")
        }
    }

    override fun doWork(): Result {
        Log.d(TAG, "Ejecutando actualización periódica de widgets")
        
        try {
            // Obtener todos los widget IDs
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(applicationContext, ControlWidgetProvider::class.java)
            )
            
            if (widgetIds.isEmpty()) {
                Log.d(TAG, "No hay widgets activos, saltando actualización")
                return Result.success()
            }
            
            Log.d(TAG, "Actualizando ${widgetIds.size} widgets: ${widgetIds.joinToString()}")
            
            // Forzar actualización de todos los widgets
            val intent = android.content.Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            applicationContext.sendBroadcast(intent)
            
            Log.d(TAG, "Actualización de widgets completada exitosamente")
            return Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error actualizando widgets: ${e.message}", e)
            // Reintentar en caso de error
            return Result.retry()
        }
    }
}
