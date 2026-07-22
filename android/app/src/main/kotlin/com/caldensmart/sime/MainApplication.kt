package com.caldensmart.sime

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Application custom que PRE-CALIENTA un FlutterEngine dedicado a la pantalla de
 * configuración del widget (SelectDeviceScreen) y lo deja cacheado.
 *
 * Por qué: WidgetConfigActivity, al lanzarse desde el launcher, creaba un engine
 * Flutter NUEVO que tenía que arrancar en frío y correr main() compitiendo con
 * los otros engines vivos (app principal, background service, home_widget). Ese
 * cold-start era intermitente y a veces no terminaba de renderizar la ruta →
 * pantalla negra. Pre-calentando el engine acá (una vez, al arrancar el proceso),
 * cuando el usuario toca "crear widget" la activity se attachea a un engine YA
 * caliente y renderizado → aparece al instante, sin carrera.
 *
 * El engine corre el entrypoint default (main) con initialRoute
 * "/widget_config_selection", así main() toma el branch liviano (isWidgetConfig)
 * y muestra SelectDeviceScreen sin bootear toda la app.
 */
class MainApplication : Application() {
    companion object {
        const val WIDGET_CONFIG_ENGINE_ID = "widget_config_engine"
    }

    override fun onCreate() {
        super.onCreate()

        try {
            val engineGroup = FlutterEngineGroup(this)
            val entrypoint = DartExecutor.DartEntrypoint.createDefault()
            val engine: FlutterEngine =
                engineGroup.createAndRunEngine(
                    this,
                    entrypoint,
                    "/widget_config_selection",
                )
            FlutterEngineCache.getInstance().put(WIDGET_CONFIG_ENGINE_ID, engine)
        } catch (e: Exception) {
            // Si por algún motivo falla el pre-calentado, WidgetConfigActivity
            // cae al comportamiento default (crea su propio engine).
            android.util.Log.e("MainApplication", "No se pudo pre-calentar el engine de config: ${e.message}")
        }
    }
}
