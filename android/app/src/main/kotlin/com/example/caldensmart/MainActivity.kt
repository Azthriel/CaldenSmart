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
    private lateinit var locReceiver: BroadcastReceiver

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

                // Recibe cambios
                locReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        locEventSink?.success(isLocationEnabled())
                    }
                }
                val filter = IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION).apply {
                    addAction(LocationManager.MODE_CHANGED_ACTION)
                }
                registerReceiver(locReceiver, filter)
            }

            override fun onCancel(arguments: Any?) {
                unregisterReceiver(locReceiver)
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
        mediaPlayer?.stop(); mediaPlayer?.release(); mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
    }
}
