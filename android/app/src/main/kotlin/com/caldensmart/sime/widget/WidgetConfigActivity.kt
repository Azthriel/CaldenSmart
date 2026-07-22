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

class WidgetConfigActivity : FlutterActivity() {
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

        // Creamos un canal para hablar con Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.caldensmart.sime/widget_config")
            .setMethodCallHandler { call, result ->
                if (call.method == "getWidgetId") {
                    // Flutter nos pide el ID del widget actual
                    result.success(appWidgetId)
                } else if (call.method == "finishConfig") {
                    // Confirmamos a Android que la configuración fue exitosa
                    val resultValue = Intent()
                    resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    setResult(RESULT_OK, resultValue)

                    // Cerramos esta pantalla para volver al launcher
                    finish()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }

    // 5. Opcional: Definir una ruta inicial específica para esta pantalla
    // Esto hace que al abrirse, vaya directo a tu pantalla de selección
    override fun getInitialRoute(): String = "/widget_config_selection"
}
