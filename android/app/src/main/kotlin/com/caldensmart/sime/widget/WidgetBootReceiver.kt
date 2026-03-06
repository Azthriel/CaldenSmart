package com.caldensmart.sime.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import android.util.Log
import com.caldensmart.sime.MainActivity

/**
 * Receiver para reiniciar el servicio de widgets después de:
 * - Reinicio del dispositivo (BOOT_COMPLETED / QUICKBOOT_POWERON)
 * - Actualización de la app (MY_PACKAGE_REPLACED)
 *
 * IMPORTANTE: Este receiver debe tener android:exported="true" en el Manifest
 * para poder recibir broadcasts del sistema (BOOT_COMPLETED viene del sistema).
 */
class WidgetBootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "WidgetBootReceiver"
        private const val PREFS_NAME = "HomeWidgetPreferences"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Recibido broadcast: $action")
        
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "Boot/Update detectado ($action), verificando widgets")
                handleBootCompleted(context)
            }
            else -> {
                Log.d(TAG, "Acción no manejada: $action")
            }
        }
    }
    
    private fun handleBootCompleted(context: Context) {
        try {
            // 1. Verificar si hay widgets registrados en el sistema
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, ControlWidgetProvider::class.java)
            )
            
            if (widgetIds.isEmpty()) {
                Log.d(TAG, "No hay widgets activos en el sistema, saltando inicialización")
                return
            }
            
            Log.d(TAG, "Encontrados ${widgetIds.size} widgets activos: ${widgetIds.joinToString()}")
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val widgetServiceEnabled = prefs.getBoolean("widgetServiceEnabled", false)
            
            // 2. Marcar widget_service_ready como false mientras se reinicia
            prefs.edit().putBoolean("widget_service_ready", false).apply()
            Log.d(TAG, "widget_service_ready = false (reiniciando)")
            
            // 3. Re-programar WorkManager para actualizaciones periódicas
            Log.d(TAG, "Re-programando WorkManager...")
            WidgetUpdateWorker.schedule(context)
            
            // 4. Forzar actualización visual inmediata de los widgets
            //    (los muestra con los datos que quedaron en SharedPrefs)
            val updateIntent = Intent(context, ControlWidgetProvider::class.java).apply {
                this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            }
            context.sendBroadcast(updateIntent)
            Log.d(TAG, "Broadcast de actualización enviado a ControlWidgetProvider")
            
            // 5. CRÍTICO: Reiniciar el Flutter background service
            //    Sin esto, los widgets quedan en estado "Iniciando..." porque
            //    widget_service_ready nunca se pone en true (requiere MQTT activo)
            if (widgetServiceEnabled || widgetIds.isNotEmpty()) {
                Log.d(TAG, "Reiniciando Flutter background service para widgets...")
                restartFlutterBackgroundService(context)
            }
            
            Log.d(TAG, "handleBootCompleted completado exitosamente")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error en handleBootCompleted: ${e.message}", e)
        }
    }
    
    /**
     * Reinicia el Flutter background service que maneja MQTT y widgets.
     * Esto es necesario porque FlutterBackgroundService no se auto-reinstancia tras un reboot.
     */
    private fun restartFlutterBackgroundService(context: Context) {
        try {
            // Usar el Intent del FlutterBackgroundService para reiniciarlo
            // flutter_background_service usa su propio servicio registrado en el manifest
            val serviceIntent = Intent(context, Class.forName("id.flutter.flutter_background_service.BackgroundService"))
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
                Log.d(TAG, "startForegroundService() llamado para reiniciar el servicio")
            } else {
                context.startService(serviceIntent)
                Log.d(TAG, "startService() llamado para reiniciar el servicio")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reiniciando Flutter background service: ${e.message}", e)
            
            // Fallback: Intentar abrir la app para que se reinicie el servicio
            try {
                Log.d(TAG, "Intentando programar reinicio via WorkManager oneTimeWork...")
                WidgetUpdateWorker.scheduleOneTime(context)
            } catch (e2: Exception) {
                Log.e(TAG, "Error en fallback de reinicio: ${e2.message}", e2)
            }
        }
    }
}
