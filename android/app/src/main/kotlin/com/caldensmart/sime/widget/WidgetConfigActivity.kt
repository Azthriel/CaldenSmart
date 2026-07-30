package com.caldensmart.sime.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.caldensmart.sime.MainApplication
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Activity de configuración del widget.
 *
 * Hay UN solo provider (ControlWidgetProvider) y por lo tanto una sola entrada
 * en el selector del launcher. SelectDeviceScreen muestra eventos y equipos en
 * la misma pantalla, así que esta activity no necesita saber qué se va a
 * configurar: eso lo decide el usuario del lado de Dart.
 *
 * Nota sobre el engine: viene PRE-CALENTADO desde MainApplication con
 * initialRoute "/widget_config_selection". Con engine cacheado,
 * getInitialRoute() se IGNORA (el entrypoint de Dart ya corrió con su ruta);
 * se mantiene abajo solo para el caso de fallback en que el cache esté vacío
 * y FlutterActivity tenga que crear un engine propio.
 */
class WidgetConfigActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.caldensmart.sime/widget_config"
    }

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    // Nos attachamos al engine PRE-CALENTADO por MainApplication en vez de crear
    // uno nuevo en frío (que dejaba la pantalla negra). Si por algún motivo no
    // está en el cache, devolvemos null y FlutterActivity crea uno propio (fallback).
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(MainApplication.WIDGET_CONFIG_ENGINE_ID)

    // El engine cacheado NO se destruye al cerrar esta activity: queda caliente
    // para la próxima vez que se cree un widget.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Obtener el ID del Widget que se quiere crear
        val extras = intent.extras
        if (extras != null) {
            appWidgetId =
                extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID,
                )
        }

        // 2. Si no hay ID válido, cancelamos y cerramos (el usuario volvió atrás)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // 3. Establecemos el resultado por defecto como CANCELED.
        // Si el usuario sale de la app sin elegir dispositivo, el widget NO se crea.
        val resultValue = Intent()
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_CANCELED, resultValue)
    }

    // 4. Configuramos el motor de Flutter para recibir el ID del widget
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWidgetId" -> {
                        // Flutter nos pide el ID del widget actual
                        result.success(appWidgetId)
                    }

                    "finishConfig" -> {
                        // Confirmamos a Android que la configuración fue exitosa
                        val resultValue = Intent()
                        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        setResult(RESULT_OK, resultValue)

                        // Cerramos esta pantalla para volver al launcher
                        finish()
                        result.success(true)
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    // 5. Ruta inicial para el caso de fallback (engine no cacheado).
    override fun getInitialRoute(): String = "/widget_config_selection"
}
