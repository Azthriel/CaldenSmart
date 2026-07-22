package com.caldensmart.sime

import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.LocationManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val LOCATION_STREAM = "com.caldensmart.sime/locationStream"
    private val CHANNEL         = "com.caldensmart.sime/native"

    // Para LocationWatcher
    private var locEventSink: EventChannel.EventSink? = null
    private var locReceiver: BroadcastReceiver? = null
    private var locReceiverRegistered = false

    // Para audio
    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1) EventChannel → Emite true/false al cambiar Location Services
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_STREAM
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                locEventSink = events
                // Estado inicial
                events.success(isLocationEnabled())
                // Registro idempotente (no duplica si ya estaba registrado)
                registerLocReceiver()
            }

            override fun onCancel(arguments: Any?) {
                unregisterLocReceiver()
                locEventSink = null
            }
        })

        // 2) MethodChannel → Métodos nativos
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // LOCATION
                "isLocationServiceEnabled" -> {
                    result.success(isLocationEnabled())
                }
                "openLocationSettings" -> {
                    startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                    result.success(null)
                }
                // AUDIO
                "playSound" -> {
                    val soundName = call.argument<String>("soundName")
                    val delay = (call.argument<Int>("delay") ?: 3000).toLong()
                    Log.d("MainActivity", "playSound: $soundName, delay: $delay")
                    if (soundName != null) {
                        val resId = resources.getIdentifier(soundName, "raw", packageName)
                        mediaPlayer?.stop()
                        mediaPlayer?.release()
                        mediaPlayer = null
                        handler.removeCallbacksAndMessages(null)

                        handler.postDelayed({
                            mediaPlayer = MediaPlayer.create(this, resId)
                            if (mediaPlayer != null) {
                                mediaPlayer?.start()
                                handler.postDelayed({
                                    mediaPlayer?.stop()
                                    mediaPlayer?.release()
                                    mediaPlayer = null
                                }, delay)
                                mediaPlayer?.setOnCompletionListener {
                                    handler.removeCallbacksAndMessages(null)
                                    mediaPlayer?.release()
                                    mediaPlayer = null
                                }
                            } else {
                                result.error("ERROR", "No se pudo reproducir el sonido", null)
                            }
                        }, 50)
                        result.success(null)
                    } else {
                        result.error("ERROR", "Nombre de sonido no proporcionado", null)
                    }
                }
                "stopSound" -> {
                    mediaPlayer?.stop()
                    mediaPlayer?.release()
                    mediaPlayer = null
                    handler.removeCallbacksAndMessages(null)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    /** Registra el receiver de cambios de ubicación de forma idempotente.
     *  Guarda la referencia y un flag para poder des-registrarlo siempre y no
     *  duplicarlo (cada duplicado sería un IntentReceiverLeaked). */
    private fun registerLocReceiver() {
        if (locReceiverRegistered) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                locEventSink?.success(isLocationEnabled())
            }
        }
        val filter = IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION).apply {
            addAction(LocationManager.MODE_CHANGED_ACTION)
        }
        // Android 13+ (API 33) exige declarar si el receiver es exportado.
        // Solo escuchamos broadcasts del sistema → NOT_EXPORTED.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        locReceiver = receiver
        locReceiverRegistered = true
    }

    /** Des-registra el receiver si está registrado. Seguro de llamar múltiples
     *  veces (onCancel, onDestroy). */
    private fun unregisterLocReceiver() {
        if (!locReceiverRegistered) return
        try {
            locReceiver?.let { unregisterReceiver(it) }
        } catch (e: IllegalArgumentException) {
            Log.w("MainActivity", "locReceiver ya no estaba registrado: ${e.message}")
        }
        locReceiver = null
        locReceiverRegistered = false
    }

    private fun isLocationEnabled(): Boolean {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    override fun onPause() {
        super.onPause()
        mediaPlayer?.stop(); mediaPlayer?.release(); mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
    }

    override fun onStop() {
        super.onStop()
        mediaPlayer?.stop(); mediaPlayer?.release(); mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Fix del IntentReceiverLeaked: si Dart nunca llamó onCancel, el
        // receiver seguía registrado al destruir la Activity y se filtraba.
        unregisterLocReceiver()
        mediaPlayer?.stop(); mediaPlayer?.release(); mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
    }
}