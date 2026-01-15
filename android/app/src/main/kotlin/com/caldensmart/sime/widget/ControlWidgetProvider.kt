package com.caldensmart.sime.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import com.caldensmart.sime.MainActivity
import com.caldensmart.sime.R
import org.json.JSONArray

class ControlWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "ControlWidgetProvider"
        private const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        
        Log.d(TAG, "onDeleted llamado para widgets: ${appWidgetIds.joinToString()}")
        
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        for (widgetId in appWidgetIds) {
            Log.d(TAG, "Limpiando datos del widget $widgetId")
            
            // Eliminar todos los datos asociados a este widget
            editor.remove("widget_device_$widgetId")
            editor.remove("widget_nickname_$widgetId")
            editor.remove("widget_is_control_$widgetId")
            editor.remove("widget_online_$widgetId")
            editor.remove("widget_status_$widgetId")
            editor.remove("widget_pc_$widgetId")
            editor.remove("widget_sn_$widgetId")
            editor.remove("widget_is_pin_$widgetId")
            editor.remove("widget_pin_index_$widgetId")
            editor.remove("widget_temperature_$widgetId")
            editor.remove("widget_alert_$widgetId")
            editor.remove("widget_ppmCO_$widgetId")
            editor.remove("widget_ppmCH4_$widgetId")
            
            // Actualizar la lista de widgets activos
            val widgetIdsJson = prefs.getString("active_widget_ids", null)
            if (widgetIdsJson != null) {
                try {
                    val jsonArray = JSONArray(widgetIdsJson)
                    val newArray = JSONArray()
                    
                    for (i in 0 until jsonArray.length()) {
                        val id = jsonArray.getInt(i)
                        if (id != widgetId) {
                            newArray.put(id)
                        }
                    }
                    
                    editor.putString("active_widget_ids", newArray.toString())
                    Log.d(TAG, "Lista actualizada de widgets: ${newArray.toString()}")
                    
                    // Si no quedan widgets, notificar para posiblemente detener el servicio
                    if (newArray.length() == 0) {
                        Log.d(TAG, "No quedan widgets activos, el servicio puede detenerse si no hay control por distancia")
                        editor.putBoolean("widgetServiceEnabled", false)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error actualizando lista de widgets: ${e.message}")
                }
            }
        }
        
        editor.apply()
        Log.d(TAG, "Limpieza de widgets completada")
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Leer datos del widget desde SharedPreferences
            val nickname = widgetData.getString("widget_nickname_$widgetId", null)
            val isControl = widgetData.getBoolean("widget_is_control_$widgetId", true)
            val isOnline = widgetData.getBoolean("widget_online_$widgetId", false)
            val isOn = widgetData.getBoolean("widget_status_$widgetId", false)
            val isLoading = widgetData.getBoolean("widget_loading_$widgetId", false)
            val isConfigured = nickname != null
            
            // Datos de visualización específicos
            val productCode = widgetData.getString("widget_pc_$widgetId", null)
            val displayTemp = widgetData.getString("widget_display_temp_$widgetId", null)
            val displayAlert = widgetData.getBoolean("widget_display_alert_$widgetId", false)
            val isDisplayType = widgetData.getBoolean("widget_is_display_type_$widgetId", false)
            
            // Mostrar/ocultar overlay de carga
            if (isLoading) {
                views.setViewVisibility(R.id.widget_loading_overlay, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_loading_overlay, android.view.View.GONE)
            }
            
            if (isConfigured) {
                // Widget configurado - mostrar datos del dispositivo
                views.setTextViewText(R.id.widget_device_name, nickname)
                
                // Estado de conexión
                if (isOnline) {
                    views.setTextViewText(R.id.widget_status_text, "En línea")
                    views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_online)
                } else {
                    views.setTextViewText(R.id.widget_status_text, "Desconectado")
                    views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_offline)
                }
                
                // Tipo de dispositivo e icono
                if (isControl) {
                    views.setTextViewText(R.id.widget_type_text, "Control")
                    if (isOn) {
                        views.setImageViewResource(R.id.widget_device_icon, R.drawable.ic_widget_control_on)
                        views.setTextViewText(R.id.widget_power_indicator, "ON")
                        views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_on)
                    } else {
                        views.setImageViewResource(R.id.widget_device_icon, R.drawable.ic_widget_control)
                        views.setTextViewText(R.id.widget_power_indicator, "OFF")
                        if (isOnline) {
                            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                        } else {
                            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }
                    }
                    
                    // Configurar click para toggle (solo si es control y está online y no está cargando)
                    if (isOnline && !isLoading) {
                        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                            context,
                            Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId")
                        )
                        views.setOnClickPendingIntent(R.id.widget_container, backgroundIntent)
                    } else {
                        // Si está offline o cargando, abrir la app al hacer click
                        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                    }
                } else {
                    // Widget de visualización (solo lectura)
                    views.setTextViewText(R.id.widget_type_text, "Lectura")
                    views.setImageViewResource(R.id.widget_device_icon, R.drawable.ic_widget_display)
                    
                    // Determinar qué mostrar según el tipo de dispositivo
                    when {
                        // Termómetro - mostrar temperatura
                        productCode == "023430_IOT" && displayTemp != null -> {
                            views.setTextViewText(R.id.widget_power_indicator, "${displayTemp}°C")
                            views.setTextColor(R.id.widget_power_indicator, 0xFF2196F3.toInt()) // Azul
                            if (isOnline) {
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                            } else {
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                            }
                        }
                        // Detector - mostrar alerta
                        productCode == "015773_IOT" -> {
                            if (displayAlert) {
                                views.setTextViewText(R.id.widget_power_indicator, "⚠ ALERTA")
                                views.setTextColor(R.id.widget_power_indicator, 0xFFF44336.toInt()) // Rojo
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_alert)
                            } else {
                                views.setTextViewText(R.id.widget_power_indicator, "OK")
                                views.setTextColor(R.id.widget_power_indicator, 0xFF4CAF50.toInt()) // Verde
                                if (isOnline) {
                                    views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                                } else {
                                    views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                                }
                            }
                        }
                        // Dispositivos IO con entrada (sensores de apertura, etc.)
                        isDisplayType -> {
                            if (displayAlert) {
                                views.setTextViewText(R.id.widget_power_indicator, "ABIERTO")
                                views.setTextColor(R.id.widget_power_indicator, 0xFFF44336.toInt()) // Rojo
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_alert)
                            } else {
                                views.setTextViewText(R.id.widget_power_indicator, "CERRADO")
                                views.setTextColor(R.id.widget_power_indicator, 0xFF4CAF50.toInt()) // Verde
                                if (isOnline) {
                                    views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                                } else {
                                    views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                                }
                            }
                        }
                        // Otros dispositivos de lectura genéricos
                        else -> {
                            views.setTextViewText(R.id.widget_power_indicator, "")
                            if (isOnline) {
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                            } else {
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                            }
                        }
                    }
                    
                    // Dispositivos de lectura siempre abren la app
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
            } else {
                // Widget no configurado - mostrar estado de configuración
                views.setTextViewText(R.id.widget_device_name, "CaldenSmart")
                views.setTextViewText(R.id.widget_status_text, "Configurando...")
                views.setTextViewText(R.id.widget_type_text, "Toca para configurar")
                views.setTextViewText(R.id.widget_power_indicator, "")
                views.setImageViewResource(R.id.widget_device_icon, R.drawable.ic_widget_settings)
                views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_settings)
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_configuring)
                
                // Widget no configurado abre la app
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}