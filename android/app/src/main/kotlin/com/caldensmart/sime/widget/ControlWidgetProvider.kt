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
import android.view.View
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
        // 40 min: WorkManager (15 min nominal) se atrasa bajo Doze/OEM battery
        // optimizers; con 20 min el margen era de solo 5 min y los widgets
        // caian en 'stale' de forma masiva con la app cerrada.
        private const val STALE_THRESHOLD_MS = 40L * 60 * 1000

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

        // ── Eventos (cadena / riego / grupo) ───────────────────────────────
        // Mismo valor que STALE_THRESHOLD_MS pero con semántica DISTINTA: acá
        // no apaga nada, solo atenúa el contador. Para un evento 'idle' es un
        // estado estable que no envejece nunca, y una cadena puede estar
        // 'running' durante horas sin que eso sea raro. La verdad está en
        // estado_ejecucion de DynamoDB, y el /update del worker la trae.
        private const val EVENT_UNCONFIRMED_MS = 40L * 60 * 1000

        private const val COLOR_GREY    = 0xFF9E9E9E.toInt()
        private const val COLOR_RUNNING = 0xFF42A5F5.toInt()  // azul
        private const val COLOR_PAUSED  = 0xFFFFA726.toInt()  // naranja
        private const val COLOR_WATER   = 0xFF66BB6A.toInt()  // verde riego
        private const val COLOR_EV_ERR  = 0xFFEF5350.toInt()  // rojo

        private fun eventActionIntent(
            context: Context,
            widgetId: Int,
            action: String,
            on: Boolean? = null
        ) = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse(
                "caldensmart://widget/event?widgetId=$widgetId&action=$action" +
                    if (on != null) "&on=$on" else ""
            )
        )
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
            editor.remove("widget_is_calibrated_$widgetId")
            editor.remove("widget_roller_position_$widgetId")
            // Claves de widgets de evento
            editor.remove("event_widget_cfg_$widgetId")
            editor.remove("widget_event_armed_$widgetId")

            // Sacar el id de la lista de eventos (se mantiene aparte de
            // active_widget_ids porque syncWidgetsWithDatabase() y
            // getWidgetTopics() iteran esa esperando encontrar pc/sn).
            var remainingEvents = 0
            val eventIdsJson = prefs.getString("active_event_widget_ids", null)
            if (eventIdsJson != null) {
                try {
                    val evArray = JSONArray(eventIdsJson)
                    val newEvArray = JSONArray()
                    for (i in 0 until evArray.length()) {
                        val id = evArray.getInt(i)
                        if (id != widgetId) newEvArray.put(id)
                    }
                    editor.putString("active_event_widget_ids", newEvArray.toString())
                    remainingEvents = newEvArray.length()
                } catch (e: Exception) {
                    Log.e(TAG, "Error actualizando lista de eventos: ${e.message}")
                }
            }

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
                    // Antes miraba solo active_widget_ids: borrar el ultimo
                    // widget de EQUIPO dejaba a los de EVENTO clavados en
                    // "Iniciando..." para siempre, porque widget_service_ready
                    // ya nunca volvia a ponerse en true.
                    if (newArray.length() == 0 && remainingEvents == 0) {
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

            // Medidas del widget.
            //
            // widget_width_/height_ solo se escriben en onAppWidgetOptionsChanged,
            // o sea al REDIMENSIONAR. Un widget recién colocado y nunca tocado
            // daba 0x0 y caía siempre en el breakpoint más chico (2 celdas),
            // aunque el usuario lo hubiera puesto de 4. Ahora se le pregunta al
            // sistema y las prefs quedan solo como respaldo.
            val opts = appWidgetManager.getAppWidgetOptions(widgetId)
            val optWidth  = opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0) ?: 0
            val optHeight = opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0

            val widthDp = if (optWidth > 0) optWidth
                          else widgetData.getInt("widget_width_$widgetId", 0)
            val heightDp = if (optHeight > 0) optHeight
                           else widgetData.getInt("widget_height_$widgetId", 0)
            val sizes    = calculateSizes(widthDp, heightDp)

            // Aplicar tamaños responsivos antes de cualquier otra cosa
            applyResponsiveSizes(views, sizes)

            // Leer estado (atómico primero, legacy como fallback)
            val atomicJson = widgetData.getString("widget_state_$widgetId", null)
            val atomic: JSONObject? = if (!atomicJson.isNullOrEmpty()) {
                try { JSONObject(atomicJson) } catch (e: Exception) { null }
            } else null

            // ── Widgets de EVENTO ───────────────────────────────────────────
            // Salida temprana. Comparten layout y archivo de prefs con los
            // equipos, pero nada de la logica de abajo: un evento no tiene
            // cstate, ni w_status, ni un 'stale' que deba apagarlo.
            if (atomic != null && atomic.optString("kind") == "event") {
                renderEventWidget(context, views, widgetId, atomic, widthDp, heightDp)
                appWidgetManager.updateAppWidget(widgetId, views)
                return
            }

            // A partir de aca es SIEMPRE un equipo: las vistas de evento se
            // fuerzan a GONE por si el widget fue reconfigurado de evento a
            // equipo sobre el mismo appWidgetId.
            views.setViewVisibility(R.id.widget_event_progress, View.GONE)
            views.setViewVisibility(R.id.widget_event_subtitle, View.GONE)
            views.setViewVisibility(R.id.widget_event_btn_primary, View.GONE)
            views.setViewVisibility(R.id.widget_event_btn_secondary, View.GONE)

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
            val isCalibrated: Boolean   // Roller: true si el dispositivo está calibrado
            val rollerPosition: Int     // Roller: 0-100, -1 = desconocido
            val isMoving: Boolean       // Roller: true mientras se desplaza
            val rollerDirection: Int    // Roller: 1 = subiendo ↑, -1 = bajando ↓, 0 = desconocido

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
                isCalibrated   = atomic.optBoolean("isCalibrated", true)
                rollerPosition = atomic.optInt("rollerPosition", -1)
                isMoving       = atomic.optBoolean("isMoving", false)
                rollerDirection = atomic.optInt("rollerDirection", 0)
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
                isCalibrated   = widgetData.getBoolean("widget_is_calibrated_$widgetId", true)
                rollerPosition = widgetData.getInt("widget_roller_position_$widgetId", -1)
                isMoving       = widgetData.getBoolean("widget_roller_moving_$widgetId", false)
                rollerDirection = 0
            }

            val isServiceReady  = widgetData.getBoolean("widget_service_ready", false)
            val isStale         = ts > 0L && (System.currentTimeMillis() - ts) > STALE_THRESHOLD_MS

            // Opción B: el stale ya NO fuerza offline. El widget SIEMPRE refleja
            // el último estado real guardado (online/offline). Si el equipo se
            // desconecta de verdad, llega cstate:false por MQTT (service vivo) y
            // se actualiza; el tap /refresh queda como confirmación manual para
            // cuando el service estuvo caído. Antes: isOnline && !isStale, que
            // pintaba gris a los 40 min aunque el equipo siguiera conectado.
            val effectiveOnline = isOnline

            if (isStale) Log.d(TAG, "Widget $widgetId: datos viejos (ts>40min), muestro último estado conocido")

            // Overlay de carga
            views.setViewVisibility(
                R.id.widget_loading_background,
                if (isLoading || isInitializing) android.view.View.VISIBLE else android.view.View.GONE
            )

            if (nickname.isNotEmpty()) {
                views.setTextViewText(R.id.widget_device_name, nickname)
                
                if (effectiveOnline && isServiceReady) {
                    views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_online)
                    views.setInt(R.id.widget_connection_icon, "setColorFilter", 0) 
                } else {
                    views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_offline)
                    views.setInt(R.id.widget_connection_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                }

                if (productCode == "024011_IOT") {
                    renderRollerWidget(
                        context, views, widgetId,
                        effectiveOnline, isCalibrated, rollerPosition,
                        isMoving, rollerDirection, isLoading, isServiceReady
                    )
                } else if (isControl) {
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

    /**
     * Renderiza un widget de EVENTO (cadena / riego / grupo).
     *
     * Se ve IGUAL que un widget de equipo — mismo logo, mismos fondos, mismo
     * icono de estado — y lo unico que lo distingue es el subtitulo bajo el
     * nombre ("Evento grupo", "Paso 3 de 7", "Pausado").
     *
     * Reparto de vistas:
     *   widget_logo_icon       -> dragon, igual que un equipo
     *   widget_device_name     -> nombre del evento
     *   widget_event_subtitle  -> tipo de evento o progreso
     *   widget_connection_icon -> icono del tipo (cadena/riego/grupo)
     *   widget_status_icon     -> switch on/off, SOLO en grupo
     *   widget_event_btn_*     -> play/pausa y cancelar, SOLO en cadena/riego
     *
     * El progreso llega YA RESUELTO en `progress` (0..100): Dart lo calcula con
     * EventoEstado.pasosCompletadosFromMensaje, que parsea el mensaje con
     * regex. Reimplementarlo aca seria duplicar una fuente de verdad que ya
     * cambio de formato una vez.
     */
    private fun renderEventWidget(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        st: JSONObject,
        widthDp: Int,
        heightDp: Int
    ) {
        val nickname    = st.optString("nickname", "")
        val eventKind   = st.optString("eventKind", "grupo")   // cadena|riego|grupo
        val status      = st.optString("status", "idle")
        val pasosDone   = st.optInt("pasosCompletados", 0)
        val pasosTotal  = st.optInt("totalPasos", 0)
        val progress    = st.optInt("progress", 0)
        val hasProgress = st.optBoolean("hasProgress", false)
        val canPause    = st.optBoolean("canPause", false)
        val loading     = st.optBoolean("loading", false)
        val groupOn     = if (st.has("groupOn")) st.optBoolean("groupOn") else null
        val lastError   = st.optString("lastError", "")
        val ts          = st.optLong("ts", 0L)

        val isRunning = status == "running"
        val isPaused  = status == "paused"
        val isActive  = isRunning || isPaused
        val isMissing = status == "missing"
        val isError   = status == "error"

        // "Sin confirmar": dice estar corriendo pero hace rato que no llega
        // MQTT. Nunca apaga el widget; solo pinta el subtitulo en gris.
        val unconfirmed = isActive && ts > 0L &&
            (System.currentTimeMillis() - ts) > EVENT_UNCONFIRMED_MS

        // ── Base identica a un equipo ──────────────────────────────────────
        views.setViewVisibility(R.id.widget_power_indicator, View.GONE)
        views.setViewVisibility(
            R.id.widget_loading_background,
            if (loading) View.VISIBLE else View.GONE
        )
        views.setImageViewResource(R.id.widget_logo_icon, R.drawable.dragon_foreground)
        views.setInt(R.id.widget_logo_icon, "setColorFilter", 0)

        // El icono del tipo va donde los equipos muestran la nube.
        views.setViewVisibility(R.id.widget_connection_icon, View.VISIBLE)
        views.setImageViewResource(
            R.id.widget_connection_icon,
            when (eventKind) {
                "cadena" -> R.drawable.ic_event_chain
                "riego"  -> R.drawable.ic_event_water
                else     -> R.drawable.ic_event_group
            }
        )
        views.setInt(R.id.widget_connection_icon, "setColorFilter", COLOR_GREY)

        views.setTextViewText(R.id.widget_device_name, nickname)
        views.setTextColor(R.id.widget_device_name, 0xFFFFFFFF.toInt())

        // ── Subtitulo ──────────────────────────────────────────────────────
        val tipoLabel = when (eventKind) {
            "cadena" -> "Evento cadena"
            "riego"  -> "Evento riego"
            else     -> "Evento grupo"
        }
        val subtitle = when {
            isMissing -> "Evento eliminado"
            isError   -> if (lastError.isNotEmpty()) lastError else "Error"
            isActive && hasProgress && pasosTotal > 0 ->
                "Paso $pasosDone de $pasosTotal"
            isPaused  -> "Pausado"
            isRunning -> "En ejecución"
            else      -> tipoLabel
        }
        views.setViewVisibility(R.id.widget_event_subtitle, View.VISIBLE)
        views.setTextViewText(R.id.widget_event_subtitle, subtitle)
        views.setTextColor(
            R.id.widget_event_subtitle,
            when {
                isError || isMissing -> COLOR_EV_ERR
                unconfirmed          -> COLOR_GREY
                isPaused             -> COLOR_PAUSED
                isRunning            -> COLOR_RUNNING
                else                 -> COLOR_GREY
            }
        )
        // Acompaña los breakpoints de calculateSizes(), un escalon por debajo
        // del nombre.
        val subSp = when {
            widthDp >= 320 -> 12f
            widthDp >= 250 -> 11f
            widthDp >= 180 -> 10f
            else           -> 9f
        }
        views.setTextViewTextSize(
            R.id.widget_event_subtitle, TypedValue.COMPLEX_UNIT_SP, subSp
        )

        // ── Barra de progreso ──────────────────────────────────────────────
        // setProgressBar es metodo remoteable: sale nativa, sin generar
        // bitmaps por cada paso.
        if (hasProgress && isActive && pasosTotal > 0) {
            views.setViewVisibility(R.id.widget_event_progress, View.VISIBLE)
            views.setProgressBar(R.id.widget_event_progress, 100, progress, false)
        } else {
            views.setViewVisibility(R.id.widget_event_progress, View.GONE)
        }

        // ── Estado terminal: sin botones, tocar abre la app ────────────────
        if (isMissing) {
            views.setViewVisibility(R.id.widget_status_icon, View.GONE)
            views.setViewVisibility(R.id.widget_event_btn_primary, View.GONE)
            views.setViewVisibility(R.id.widget_event_btn_secondary, View.GONE)
            views.setInt(R.id.widget_container, "setBackgroundResource",
                R.drawable.widget_background_offline)
            views.setOnClickPendingIntent(
                R.id.widget_container,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            return
        }

        // ── GRUPO: se comporta EXACTAMENTE como un equipo de control ───────
        // Todo el cuerpo togglea. Antes el toggle estaba en un ImageView de
        // 20dp y el contenedor abria la app: si le errabas al boton, en vez de
        // encender el grupo te abria la app.
        if (eventKind == "grupo") {
            val on = groupOn == true

            // El switch va en btn_primary, NO en widget_status_icon: en la fila
            // status_icon esta ANTES del icono de tipo y el switch quedaba en el
            // medio. btn_primary es la ultima vista visible de la fila.
            views.setViewVisibility(R.id.widget_status_icon, View.GONE)
            views.setViewVisibility(R.id.widget_event_btn_primary, View.VISIBLE)
            views.setViewVisibility(R.id.widget_event_btn_secondary, View.GONE)

            views.setImageViewResource(
                R.id.widget_event_btn_primary,
                if (on) R.drawable.ic_switch_on else R.drawable.ic_switch_off
            )
            views.setInt(R.id.widget_event_btn_primary, "setColorFilter", 0)
            views.setInt(R.id.widget_container, "setBackgroundResource",
                if (on) R.drawable.widget_background_on
                else R.drawable.widget_background_off)

            val groupIntent = eventActionIntent(context, widgetId, "group", on = !on)
            views.setOnClickPendingIntent(R.id.widget_container, groupIntent)
            views.setOnClickPendingIntent(R.id.widget_event_btn_primary, groupIntent)
            return
        }

        // ── CADENA / RIEGO: un boton que cicla play -> pausa -> play ───────
        views.setViewVisibility(R.id.widget_status_icon, View.GONE)
        views.setViewVisibility(R.id.widget_event_btn_primary, View.VISIBLE)

        val (icon, action, tint) = when {
            isRunning && canPause -> Triple(R.drawable.ic_event_pause, "pause",  COLOR_PAUSED)
            isPaused              -> Triple(R.drawable.ic_event_play,  "resume", COLOR_RUNNING)
            isRunning             -> Triple(R.drawable.ic_event_stop,  "cancel", COLOR_EV_ERR)
            else                  -> Triple(R.drawable.ic_event_play,  "start",  COLOR_RUNNING)
        }
        views.setImageViewResource(R.id.widget_event_btn_primary, icon)
        views.setInt(R.id.widget_event_btn_primary, "setColorFilter", tint)
        views.setOnClickPendingIntent(
            R.id.widget_event_btn_primary,
            eventActionIntent(context, widgetId, action)
        )

        // El boton de cancelar compite con el nombre: solo de 4 celdas (250dp)
        // para arriba, y solo mientras hay algo corriendo.
        if (isActive && canPause && widthDp >= 250) {
            views.setViewVisibility(R.id.widget_event_btn_secondary, View.VISIBLE)
            views.setImageViewResource(R.id.widget_event_btn_secondary, R.drawable.ic_event_stop)
            views.setInt(R.id.widget_event_btn_secondary, "setColorFilter", COLOR_EV_ERR)
            views.setOnClickPendingIntent(
                R.id.widget_event_btn_secondary,
                eventActionIntent(context, widgetId, "cancel")
            )
        } else {
            views.setViewVisibility(R.id.widget_event_btn_secondary, View.GONE)
        }

        views.setInt(R.id.widget_container, "setBackgroundResource",
            when {
                isError  -> R.drawable.widget_background_alert
                isActive -> R.drawable.widget_background_on
                else     -> R.drawable.widget_background_off
            })

        // TODO el cuerpo dispara la misma accion que el boton, igual que un
        // equipo de control. El riesgo del toque accidental lo cubre el doble
        // toque de confirmacion (requireConfirm), que viene activado por
        // defecto para cadena y riego.
        //
        // El boton de cancelar sigue funcionando: en RemoteViews el hijo con
        // PendingIntent propio se come el toque antes que el contenedor.
        views.setOnClickPendingIntent(
            R.id.widget_container,
            eventActionIntent(context, widgetId, action)
        )

        Log.d(TAG, "Evento $widgetId: $eventKind/$status $pasosDone/$pasosTotal ($progress%)")
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
            !effectiveOnline -> {
                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                val refreshPi = HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("caldensmart://widget/refresh?widgetId=$widgetId"))
                views.setOnClickPendingIntent(R.id.widget_container, refreshPi)
            }

            !isServiceReady -> {
                views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setTextViewText(R.id.widget_power_indicator, "Iniciando...")
                views.setTextColor(R.id.widget_power_indicator, 0xFF9E9E9E.toInt())
                views.setInt(R.id.widget_container, "setBackgroundResource",
                    R.drawable.widget_background_offline)
                // Tap → /refresh: hace la consulta real y marca el servicio listo,
                // en vez de solo abrir la app y quedarse en "Iniciando...".
                val refreshPi = HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("caldensmart://widget/refresh?widgetId=$widgetId"))
                views.setOnClickPendingIntent(R.id.widget_container, refreshPi)
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

    private fun renderRollerWidget(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        effectiveOnline: Boolean,
        isCalibrated: Boolean,
        rollerPosition: Int,
        isMoving: Boolean,
        rollerDirection: Int,   // 1 = subiendo ↑, -1 = bajando ↓, 0 = desconocido
        isLoading: Boolean,
        isServiceReady: Boolean
    ) {
        views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
        views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)

        val dirEmoji = when {
            isMoving && rollerDirection == 1  -> " ↑"
            isMoving && rollerDirection == -1 -> " ↓"
            else -> ""
        }

        val posLabel = when {
            !isCalibrated         -> "Sin calibrar"
            isMoving              -> "Moviéndose$dirEmoji (${if (rollerPosition >= 0) "$rollerPosition%" else "..."})"
            rollerPosition < 0    -> "—"
            rollerPosition == 0   -> "Abierto"
            rollerPosition == 100 -> "Cerrado"
            else                  -> "Parcial ($rollerPosition%)"
        }
        views.setTextViewText(R.id.widget_power_indicator, posLabel)

        val labelColor = when {
            !effectiveOnline      -> 0xFF9E9E9E.toInt()  // gris offline
            !isCalibrated         -> 0xFF9E9E9E.toInt()  // gris sin calibrar
            isMoving              -> 0xFFFFB300.toInt()  // ámbar
            rollerPosition == 0   -> 0xFF4CAF50.toInt()  // verde abierto
            rollerPosition == 100 -> 0xFFFF7043.toInt()  // naranja cerrado
            else                  -> 0xFF64B5F6.toInt()  // azul parcial
        }
        views.setTextColor(R.id.widget_power_indicator, labelColor)

        val bgRes = when {
            !effectiveOnline    -> R.drawable.widget_background_offline
            rollerPosition == 0 -> R.drawable.widget_background_on
            else                -> R.drawable.widget_background_off
        }
        views.setInt(R.id.widget_container, "setBackgroundResource", bgRes)

        // ── Lógica de tap ──────────────────────────────────────────────────
        // canInteract: online + servicio listo + calibrado + no cargando
        val canInteract = effectiveOnline && isServiceReady && isCalibrated && !isLoading

        val intent = when {
            // Offline/stale → tap hace consulta real (/refresh) en vez de abrir app
            !effectiveOnline ->
                HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("caldensmart://widget/refresh?widgetId=$widgetId"))

            // Sin interacción posible por otra razón (sin calibrar / cargando) → abre app
            !canInteract ->
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

            // Moviéndose → frenar en posición actual
            // Si la posición es desconocida (-1), abre app (no podemos frenar sin saber dónde está)
            isMoving ->
                if (rollerPosition >= 0)
                    HomeWidgetBackgroundIntent.getBroadcast(context,
                        Uri.parse("caldensmart://widget/position?widgetId=$widgetId&pos=$rollerPosition"))
                else
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

            // Posición desconocida → abre app
            rollerPosition < 0 ->
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

            // Abierto o parcial < 50 → cerrar
            rollerPosition < 50 ->
                HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("caldensmart://widget/close?widgetId=$widgetId"))

            // Cerrado o parcial >= 50 → abrir
            else ->
                HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("caldensmart://widget/open?widgetId=$widgetId"))
        }
        views.setOnClickPendingIntent(R.id.widget_container, intent)

        Log.d(TAG, "Roller $widgetId: label='$posLabel', calibrated=$isCalibrated, moving=$isMoving, pos=$rollerPosition, canInteract=$canInteract")
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
        // El display SIEMPRE refresca al tocar (online u offline): no tiene
        // toggle, su gesto útil es traer la lectura fresca al instante. Nunca
        // abre la app. La rama offline de abajo re-setea el mismo /refresh (es
        // idempotente) y además ajusta el visual gris.
        val refreshPi = HomeWidgetBackgroundIntent.getBroadcast(context,
            Uri.parse("caldensmart://widget/refresh?widgetId=$widgetId"))
        views.setOnClickPendingIntent(R.id.widget_container, refreshPi)

        if (!effectiveOnline) {
            views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
            views.setTextViewText(R.id.widget_power_indicator, "--°C")
            views.setTextColor(R.id.widget_power_indicator, 0xFF9E9E9E.toInt())
            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
            val refreshPi = HomeWidgetBackgroundIntent.getBroadcast(context,
                Uri.parse("caldensmart://widget/refresh?widgetId=$widgetId"))
            views.setOnClickPendingIntent(R.id.widget_container, refreshPi)
            return // Frena el renderizado y evita entrar al 'when'
        }

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