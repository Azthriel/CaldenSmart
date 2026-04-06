package com.caldensmart.sime.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.widget.RemoteViews
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
        private const val STALE_THRESHOLD_MS = 20L * 60 * 1000

        // ── Tamaños responsivos ────────────────────────────────────────────
        // Breakpoints en dp basados en celdas estándar Android (70dp/celda):
        //   2 celdas ≈  110dp
        //   3 celdas ≈  180dp
        //   4 celdas ≈  250dp
        //   5 celdas ≈  320dp

        private data class WidgetSizes(
            val logoIconDp: Float,        // Dragón (izq)
            val connectionIconDp: Float,  // Nube / settings (der)
            val statusIconDp: Float,      // On/off / alerta
            val textSizeSp: Float,        // Nombre del equipo
            val indicatorSizeSp: Float,   // Temperatura / "Iniciando..."
        )

        private fun calculateSizes(widthDp: Int, heightDp: Int): WidgetSizes {
            return when {
                widthDp >= 320 -> WidgetSizes(  // 5+ celdas
                    logoIconDp        = 28f,
                    connectionIconDp  = 26f,
                    statusIconDp      = 26f,
                    textSizeSp        = 16f,
                    indicatorSizeSp   = 15f,
                )
                widthDp >= 250 -> WidgetSizes(  // 4 celdas
                    logoIconDp        = 24f,
                    connectionIconDp  = 22f,
                    statusIconDp      = 22f,
                    textSizeSp        = 15f,
                    indicatorSizeSp   = 14f,
                )
                widthDp >= 180 -> WidgetSizes(  // 3 celdas
                    logoIconDp        = 20f,
                    connectionIconDp  = 18f,
                    statusIconDp      = 18f,
                    textSizeSp        = 13f,
                    indicatorSizeSp   = 12f,
                )
                else -> WidgetSizes(            // 2 celdas (default)
                    logoIconDp        = 16f,
                    connectionIconDp  = 14f,
                    statusIconDp      = 16f,
                    textSizeSp        = 11f,
                    indicatorSizeSp   = 10f,
                )
            }
        }

        /** Aplica tamaños al RemoteViews. Usa API 31 para iconos; text funciona en todos. */
        private fun applyResponsiveSizes(views: RemoteViews, sizes: WidgetSizes) {
            // Texto: disponible en todos los APIs
            views.setTextViewTextSize(R.id.widget_device_name,
                TypedValue.COMPLEX_UNIT_SP, sizes.textSizeSp)
            views.setTextViewTextSize(R.id.widget_power_indicator,
                TypedValue.COMPLEX_UNIT_SP, sizes.indicatorSizeSp)

            // Iconos: setViewLayoutWidth/Height requiere API 31+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setViewLayoutWidth(R.id.widget_logo_icon,
                    sizes.logoIconDp, TypedValue.COMPLEX_UNIT_DIP)
                views.setViewLayoutHeight(R.id.widget_logo_icon,
                    sizes.logoIconDp, TypedValue.COMPLEX_UNIT_DIP)

                views.setViewLayoutWidth(R.id.widget_connection_icon,
                    sizes.connectionIconDp, TypedValue.COMPLEX_UNIT_DIP)
                views.setViewLayoutHeight(R.id.widget_connection_icon,
                    sizes.connectionIconDp, TypedValue.COMPLEX_UNIT_DIP)

                views.setViewLayoutWidth(R.id.widget_status_icon,
                    sizes.statusIconDp, TypedValue.COMPLEX_UNIT_DIP)
                views.setViewLayoutHeight(R.id.widget_status_icon,
                    sizes.statusIconDp, TypedValue.COMPLEX_UNIT_DIP)
            }
        }

        private fun readAtomicState(widgetData: SharedPreferences, widgetId: Int): JSONObject? {
            val json = widgetData.getString("widget_state_$widgetId", null) ?: return null
            return try { JSONObject(json) } catch (e: Exception) { null }
        }
    }

    // ── Ciclo de vida ──────────────────────────────────────────────────────

    override fun onEnabled(context: Context?) {
        super.onEnabled(context)
        context?.let { WidgetUpdateWorker.schedule(it) }
    }

    override fun onDisabled(context: Context?) {
        super.onDisabled(context)
        context?.let { WidgetUpdateWorker.cancel(it) }
    }

    /**
     * Se llama cada vez que el usuario REDIMENSIONA el widget.
     * Guardamos el nuevo ancho/alto y refrescamos inmediatamente.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        // Android reporta min/max porque el widget puede tener tamaños distintos
        // en portrait y landscape. Usamos el máximo para el layout principal.
        val maxWidth  = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
        val maxHeight = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)

        Log.d(TAG, "Widget $appWidgetId redimensionado: ${maxWidth}x${maxHeight}dp")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt("widget_width_$appWidgetId", maxWidth)
            .putInt("widget_height_$appWidgetId", maxHeight)
            .apply()

        // Refrescar inmediatamente con el nuevo tamaño
        updateSingleWidget(context, appWidgetManager, appWidgetId, prefs)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        var remainingWidgets = 0

        for (widgetId in appWidgetIds) {
            // Claves de tamaño
            editor.remove("widget_width_$widgetId")
            editor.remove("widget_height_$widgetId")
            // Clave atómica
            editor.remove("widget_state_$widgetId")
            // Claves legacy
            editor.remove("widget_device_$widgetId")
            editor.remove("widget_nickname_$widgetId")
            editor.remove("widget_is_control_$widgetId")
            editor.remove("widget_online_$widgetId")
            editor.remove("widget_status_$widgetId")
            editor.remove("widget_pc_$widgetId")
            editor.remove("widget_sn_$widgetId")
            editor.remove("widget_is_pin_$widgetId")
            editor.remove("widget_pin_index_$widgetId")
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
                        if (id != widgetId) newArray.put(id)
                    }
                    editor.putString("active_widget_ids", newArray.toString())
                    remainingWidgets = newArray.length()
                    if (newArray.length() == 0) {
                        editor.putBoolean("widgetServiceEnabled", false)
                        editor.putBoolean("widget_service_ready", false)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error actualizando lista: ${e.message}")
                }
            }
        }
        editor.apply()

        try {
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("caldensmart://widget/checkAndStop")
            ).send()
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
            updateSingleWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    // ── Renderizado ────────────────────────────────────────────────────────

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Leer tamaño guardado (0 = nunca redimensionado, usa default 2 celdas)
            val widthDp  = widgetData.getInt("widget_width_$widgetId", 0)
            val heightDp = widgetData.getInt("widget_height_$widgetId", 0)
            val sizes    = calculateSizes(widthDp, heightDp)

            // Aplicar tamaños responsivos antes de cualquier otra cosa
            applyResponsiveSizes(views, sizes)

            // Leer estado (atómico primero, legacy como fallback)
            val atomicJson = widgetData.getString("widget_state_$widgetId", null)
            val atomic: JSONObject? = if (!atomicJson.isNullOrEmpty()) {
                try { JSONObject(atomicJson) } catch (e: Exception) { null }
            } else null

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

            if (atomic != null) {
                nickname       = atomic.optString("nickname", "")
                isControl      = atomic.optBoolean("isControl", true)
                isOnline       = atomic.optBoolean("online", false)
                isOn           = atomic.optBoolean("status", false)
                isLoading      = atomic.optBoolean("loading", false)
                isInitializing = atomic.optBoolean("initializing", false)
                productCode    = atomic.optString("productCode", "").ifEmpty { null }
                displayTemp    = atomic.optString("displayTemp", "").ifEmpty { null }
                displayAlert   = atomic.optBoolean("displayAlert", false)
                isDisplayType  = atomic.optBoolean("isDisplayType", false)
                ts             = atomic.optLong("ts", 0L)
            } else {
                nickname       = widgetData.getString("widget_nickname_$widgetId", null) ?: ""
                isControl      = widgetData.getBoolean("widget_is_control_$widgetId", true)
                isOnline       = widgetData.getBoolean("widget_online_$widgetId", false)
                isOn           = widgetData.getBoolean("widget_status_$widgetId", false)
                isLoading      = widgetData.getBoolean("widget_loading_$widgetId", false)
                isInitializing = widgetData.getBoolean("widget_initializing_$widgetId", false)
                productCode    = widgetData.getString("widget_pc_$widgetId", null)
                displayTemp    = widgetData.getString("widget_display_temp_$widgetId", null)
                displayAlert   = widgetData.getBoolean("widget_display_alert_$widgetId", false)
                isDisplayType  = widgetData.getBoolean("widget_is_display_type_$widgetId", false)
                ts             = 0L
            }

            val isServiceReady  = widgetData.getBoolean("widget_service_ready", false)
            val isStale         = ts > 0L && (System.currentTimeMillis() - ts) > STALE_THRESHOLD_MS
            val effectiveOnline = isOnline && !isStale

            if (isStale) Log.w(TAG, "Widget $widgetId: datos obsoletos")

            // Overlay de carga
            views.setViewVisibility(
                R.id.widget_loading_background,
                if (isLoading || isInitializing) android.view.View.VISIBLE else android.view.View.GONE
            )

            if (nickname.isNotEmpty()) {
                views.setTextViewText(R.id.widget_device_name, nickname)
                views.setImageViewResource(
                    R.id.widget_connection_icon,
                    if (effectiveOnline) R.drawable.ic_widget_online else R.drawable.ic_widget_offline
                )

                if (isControl) {
                    renderControlWidget(context, views, widgetId, isOn, effectiveOnline, isLoading, isServiceReady)
                } else {
                    renderDisplayWidget(context, views, widgetId, productCode, displayTemp, displayAlert, isDisplayType, effectiveOnline)
                }
            } else {
                // Sin configurar
                views.setTextViewText(R.id.widget_device_name, "CaldenSmart")
                views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_settings)
                views.setTextViewText(R.id.widget_power_indicator, "")
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    R.drawable.widget_background_configuring)
                val pi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, pi)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        } catch (e: Exception) {
            Log.e(TAG, "Error renderizando widget $widgetId: ${e.message}", e)
        }
    }

    private fun renderControlWidget(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        isOn: Boolean,
        effectiveOnline: Boolean,
        isLoading: Boolean,
        isServiceReady: Boolean
    ) {
        views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
        views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)
        views.setInt(R.id.widget_status_icon, "setColorFilter", 0)

        val canInteract = effectiveOnline && !isLoading && isServiceReady

        when {
            !isServiceReady && effectiveOnline -> {
                views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setTextViewText(R.id.widget_power_indicator, "Iniciando...")
                views.setTextColor(R.id.widget_power_indicator, 0xFF9E9E9E.toInt())
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    R.drawable.widget_background_offline)
                val pi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, pi)
            }
            isOn -> {
                views.setImageViewResource(R.id.widget_status_icon, R.drawable.ic_switch_on)
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    R.drawable.widget_background_on)
                val intent = if (canInteract)
                    HomeWidgetBackgroundIntent.getBroadcast(context,
                        Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId"))
                else HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, intent)
            }
            else -> {
                views.setImageViewResource(R.id.widget_status_icon, R.drawable.ic_switch_off)
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    if (effectiveOnline) R.drawable.widget_background_off
                    else R.drawable.widget_background_offline)
                val intent = if (canInteract)
                    HomeWidgetBackgroundIntent.getBroadcast(context,
                        Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId"))
                else HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, intent)
            }
        }
    }

    private fun renderDisplayWidget(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        productCode: String?,
        displayTemp: String?,
        displayAlert: Boolean,
        isDisplayType: Boolean,
        effectiveOnline: Boolean
    ) {
        val pi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_container, pi)

        when {
            productCode == "023430_IOT" -> {
                views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setTextViewText(R.id.widget_power_indicator,
                    if (!displayTemp.isNullOrEmpty()) "${displayTemp}°C" else "--°C")
                views.setTextColor(R.id.widget_power_indicator, 0xFF2196F3.toInt())
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    if (effectiveOnline) R.drawable.widget_background_off
                    else R.drawable.widget_background_offline)
            }
            productCode == "015773_IOT" || isDisplayType -> {
                views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)
                if (displayAlert) {
                    views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFFF44336.toInt())
                    views.setInt(R.id.widget_container, "setBackgroundResource",
                        R.drawable.widget_background_alert)
                } else {
                    views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                    views.setInt(R.id.widget_container, "setBackgroundResource",
                        if (effectiveOnline) R.drawable.widget_background_off
                        else R.drawable.widget_background_offline)
                }
            }
            else -> {
                views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setTextViewText(R.id.widget_power_indicator, "")
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    if (effectiveOnline) R.drawable.widget_background_off
                    else R.drawable.widget_background_offline)
            }
        }
    }
}