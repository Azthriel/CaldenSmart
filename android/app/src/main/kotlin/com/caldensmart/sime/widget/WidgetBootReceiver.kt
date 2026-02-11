package com.caldensmart.sime.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.util.Log

/**
 * Receiver para reiniciar el servicio de widgets después de:
 * - Reinicio del dispositivo (BOOT_COMPLETED)
 * - Actualización de la app (MY_PACKAGE_REPLACED)
 */
class WidgetBootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "WidgetBootReceiver"
        private const val PREFS_NAME = "HomeWidgetPreferences"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Recibido broadcast: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Dispositivo reiniciado, verificando widgets")
                handleBootCompleted(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "App actualizada, verificando widgets")
                handleBootCompleted(context)
            }
        }
    }
    
    private fun handleBootCompleted(context: Context) {
        try {
            // Verificar si hay widgets activos
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, ControlWidgetProvider::class.java)
            )
            
            if (widgetIds.isEmpty()) {
                Log.d(TAG, "No hay widgets activos, saltando inicialización")
                return
            }
            
            Log.d(TAG, "Encontrados ${widgetIds.size} widgets activos")
            
            // Verificar si el servicio de widgets estaba habilitado
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val widgetServiceEnabled = prefs.getBoolean("widgetServiceEnabled", false)
            
            if (widgetServiceEnabled || widgetIds.isNotEmpty()) {
                Log.d(TAG, "Re-programando WorkManager para widgets")
                WidgetUpdateWorker.schedule(context)
                
                // Forzar una actualización inmediata de los widgets
                val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                context.sendBroadcast(updateIntent)
                
                Log.d(TAG, "WorkManager programado y widgets actualizados")
            } else {
                Log.d(TAG, "Servicio de widgets no estaba habilitado")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error en handleBootCompleted: ${e.message}", e)
        }
    }
}
