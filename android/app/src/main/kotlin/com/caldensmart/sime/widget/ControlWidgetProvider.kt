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
import org.json.JSONObject

class ControlWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "ControlWidgetProvider"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        /**
         * Umbral de datos obsoletos: si el timestamp del último guardado atómico
         * supera este valor, el widget muestra el ícono de conexión en estado
         * "sin datos recientes" (usa ic_widget_offline) aunque el campo online
         * sea true. Esto evita mostrar "online" cuando el background service
         * está muerto y los datos en SharedPrefs son viejos.
         *
         * Se usa 20 min porque el WorkManager periódico corre cada 15 min;
         * damos 5 min de margen.
         */
        private const val STALE_THRESHOLD_MS = 20 * 60 * 1000L // 20 minutos

        /**
         * Lee el estado atómico del widget desde la clave widget_state_<id>.
         * Si no existe (widgets creados con versión anterior del código),
         * devuelve null para que onUpdate() use el fallback a claves individuales.
         */
        private fun readAtomicState(widgetData: SharedPreferences, widgetId: Int): JSONObject? {
            val json = widgetData.getString("widget_state_$widgetId", null) ?: return null
            return try {
                JSONObject(json)
            } catch (e: Exception) {
                Log.w(TAG, "widget_state_$widgetId no es JSON válido: ${e.message}")
                null
            }
        }
    }

    override fun onEnabled(context: Context?) {
        super.onEnabled(context)
        context?.let {
            Log.d(TAG, "Primer widget añadido, programando WorkManager")
            WidgetUpdateWorker.schedule(it)
        }
    }

    override fun onDisabled(context: Context?) {
        super.onDisabled(context)
        context?.let {
            Log.d(TAG, "Último widget eliminado, cancelando WorkManager")
            WidgetUpdateWorker.cancel(it)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)

        Log.d(TAG, "onDeleted llamado para widgets: ${appWidgetIds.joinToString()}")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()

        var remainingWidgets = 0

        for (widgetId in appWidgetIds) {
            Log.d(TAG, "Limpiando datos del widget $widgetId")

            // FIX: incluir la nueva clave atómica en la limpieza
            editor.remove("widget_state_$widgetId")

            // Claves legacy (se mantienen por backward compat y se limpian igual)
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
            editor.remove("widget_loading_$widgetId")
            editor.remove("widget_initializing_$widgetId")
            editor.remove("widget_is_display_type_$widgetId")
            editor.remove("widget_display_temp_$widgetId")
            editor.remove("widget_display_alert_$widgetId")

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
                    remainingWidgets = newArray.length()
                    if (newArray.length() == 0) {
                        editor.putBoolean("widgetServiceEnabled", false)
                        editor.putBoolean("widget_service_ready", false)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error actualizando lista de widgets: ${e.message}")
                }
            }
        }
        editor.apply()

        Log.d(TAG, "Widgets restantes: $remainingWidgets, notificando al servicio Flutter")
        try {
            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("caldensmart://widget/checkAndStop")
            )
            backgroundIntent.send()
        } catch (e: Exception) {
            Log.e(TAG, "Error notificando al servicio Flutter: ${e.message}")
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // ── Leer estado desde JSON atómico (nuevo) o claves individuales (legacy) ──
            val atomicState = readAtomicState(widgetData, widgetId)

            val nickname: String
            val isControl: Boolean
            val isOnline: Boolean
            val isOn: Boolean
            val isLoading: Boolean
            val isInitializing: Boolean
            val productCode: String?
            val displayTemp: String?
            val displayAlert: Boolean
            val isDisplayType: Boolean
            val ts: Long

            if (atomicState != null) {
                // ── Camino nuevo: lectura atómica ──────────────────────────────────
                nickname      = atomicState.optString("nickname", "")
                isControl     = atomicState.optBoolean("isControl", true)
                isOnline      = atomicState.optBoolean("online", false)
                isOn          = atomicState.optBoolean("status", false)
                isLoading     = atomicState.optBoolean("loading", false)
                isInitializing = atomicState.optBoolean("initializing", false)
                productCode   = atomicState.optString("productCode", null)
                displayTemp   = if (atomicState.has("displayTemp")) atomicState.getString("displayTemp") else null
                displayAlert  = atomicState.optBoolean("displayAlert", false)
                isDisplayType = atomicState.optBoolean("isDisplayType", false)
                ts            = atomicState.optLong("ts", 0L)
            } else {
                // ── Fallback legacy: claves individuales ───────────────────────────
                nickname      = widgetData.getString("widget_nickname_$widgetId", null) ?: ""
                isControl     = widgetData.getBoolean("widget_is_control_$widgetId", true)
                isOnline      = widgetData.getBoolean("widget_online_$widgetId", false)
                isOn          = widgetData.getBoolean("widget_status_$widgetId", false)
                isLoading     = widgetData.getBoolean("widget_loading_$widgetId", false)
                isInitializing = widgetData.getBoolean("widget_initializing_$widgetId", false)
                productCode   = widgetData.getString("widget_pc_$widgetId", null)
                displayTemp   = widgetData.getString("widget_display_temp_$widgetId", null)
                displayAlert  = widgetData.getBoolean("widget_display_alert_$widgetId", false)
                isDisplayType = widgetData.getBoolean("widget_is_display_type_$widgetId", false)
                ts            = 0L // sin timestamp en formato legacy → no stale check
            }

            val isServiceReady = widgetData.getBoolean("widget_service_ready", false)

            // ── Detección de datos obsoletos ───────────────────────────────────────
            // Si el último guardado fue hace más de STALE_THRESHOLD_MS, no confiamos
            // en que el estado "online" sea real (el background service pudo haber
            // muerto). En ese caso forzamos la apariencia offline para ser honestos
            // con el usuario.
            val isStale = ts > 0L &&
                    (System.currentTimeMillis() - ts) > STALE_THRESHOLD_MS

            if (isStale) {
                Log.w(TAG, "Widget $widgetId: datos obsoletos (última actualización hace ${(System.currentTimeMillis() - ts) / 60000} min)")
            }

            // 1. Overlay de carga/inicialización
            views.setViewVisibility(
                R.id.widget_loading_background,
                if (isLoading || isInitializing) android.view.View.VISIBLE else android.view.View.GONE
            )

            // 2. Lógica principal
            if (nickname.isNotEmpty()) {

                views.setTextViewText(R.id.widget_device_name, nickname)

                // FIX: si los datos son obsoletos mostramos icono offline aunque
                // el campo online sea true — no podemos saber el estado real.
                when {
                    isStale -> views.setImageViewResource(
                        R.id.widget_connection_icon, R.drawable.ic_widget_offline)
                    isOnline -> views.setImageViewResource(
                        R.id.widget_connection_icon, R.drawable.ic_widget_online)
                    else -> views.setImageViewResource(
                        R.id.widget_connection_icon, R.drawable.ic_widget_offline)
                }

                // La conectividad efectiva para decisiones de UI considera el stale
                val effectiveOnline = isOnline && !isStale

                if (isControl) {
                    views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                    views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)
                    views.setInt(R.id.widget_status_icon, "setColorFilter", 0)

                    if (!isServiceReady && effectiveOnline) {
                        views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                        views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                        views.setTextViewText(R.id.widget_power_indicator, "Iniciando...")
                        views.setTextColor(R.id.widget_power_indicator, 0xFF9E9E9E.toInt())
                        views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                    } else if (isOn) {
                        views.setImageViewResource(R.id.widget_status_icon, R.drawable.ic_switch_on)
                        views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_on)

                        if (effectiveOnline && !isLoading && isServiceReady) {
                            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId")
                            )
                            views.setOnClickPendingIntent(R.id.widget_container, backgroundIntent)
                        } else {
                            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                        }
                    } else {
                        views.setImageViewResource(R.id.widget_status_icon, R.drawable.ic_switch_off)

                        if (effectiveOnline) {
                            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                        } else {
                            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }

                        if (effectiveOnline && !isLoading && isServiceReady) {
                            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId")
                            )
                            views.setOnClickPendingIntent(R.id.widget_container, backgroundIntent)
                        } else {
                            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                        }
                    }
                } else {
                    // Dispositivo de solo visualización
                    views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)

                    when {
                        productCode == "023430_IOT" -> {
                            val tempText = if (displayTemp != null) "${displayTemp}°C" else "--°C"
                            views.setTextViewText(R.id.widget_power_indicator, tempText)
                            views.setTextColor(R.id.widget_power_indicator, 0xFF2196F3.toInt())

                            if (effectiveOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                            else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }

                        productCode == "015773_IOT" -> {
                            views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                            views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)

                            if (displayAlert) {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFFF44336.toInt())
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_alert)
                            } else {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                                if (effectiveOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                                else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                            }
                        }

                        isDisplayType -> {
                            views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                            views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)

                            if (displayAlert) {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFFF44336.toInt())
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_alert)
                            } else {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                                if (effectiveOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                                else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                            }
                        }

                        else -> {
                            views.setTextViewText(R.id.widget_power_indicator, "")
                            if (effectiveOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                            else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }
                    }
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
            } else {
                // Widget sin configurar
                views.setTextViewText(R.id.widget_device_name, "CaldenSmart")
                views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_settings)
                views.setTextViewText(R.id.widget_power_indicator, "")
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_configuring)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}