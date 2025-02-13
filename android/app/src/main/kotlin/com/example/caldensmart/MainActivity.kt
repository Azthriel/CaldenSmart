package com.caldensmart.sime

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.caldensmart.sime/native"
    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isLocationServiceEnabled" -> {
                    val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    result.success(locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER))
                }
                "openLocationSettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "isBluetoothOn" -> {
                    val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
                    if (bluetoothAdapter == null) {
                        result.error("UNAVAILABLE", "Bluetooth no está disponible en este dispositivo", null)
                    } else {
                        result.success(bluetoothAdapter.isEnabled)
                    }
                }
                "turnOnBluetooth" -> {
                    val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
                    if (bluetoothAdapter != null && !bluetoothAdapter.isEnabled) {
                        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        startActivityForResult(enableBtIntent, 0)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "playSound" -> {
                    val soundName = call.argument<String>("soundName")
                    val delay = (call.argument<Int>("delay") ?: 3000).toLong()

                    Log.d("MainActivity", "playSound called with: $soundName, delay: $delay")

                    if (soundName != null) {
                        val resId = resources.getIdentifier(soundName, "raw", packageName)
                        Log.d("MainActivity", "Playing sound with resId: $resId")

                        if (resId != 0) {
                            mediaPlayer?.stop()
                            mediaPlayer?.release()
                            mediaPlayer = null
                            handler.removeCallbacksAndMessages(null)

                            handler.postDelayed({
                                mediaPlayer = MediaPlayer.create(this, resId)
                                if (mediaPlayer != null) {
                                    mediaPlayer?.start()
                                    Log.d("MainActivity", "Sonido iniciado correctamente")

                                    handler.postDelayed({
                                        mediaPlayer?.stop()
                                        mediaPlayer?.release()
                                        mediaPlayer = null
                                        Log.d("MainActivity", "Sonido detenido después de $delay ms")
                                    }, delay)

                                    mediaPlayer?.setOnCompletionListener {
                                        handler.removeCallbacksAndMessages(null)
                                        mediaPlayer?.release()
                                        mediaPlayer = null
                                        Log.d("MainActivity", "Sonido finalizó antes del delay")
                                    }
                                } else {
                                    Log.e("MainActivity", "Error al inicializar MediaPlayer")
                                    result.error("ERROR", "No se pudo reproducir el sonido", null)
                                }
                            }, 50)
                        } else {
                            Log.e("MainActivity", "Sound resource not found: $soundName")
                            result.error("ERROR", "Sonido no encontrado", null)
                        }
                        result.success(null)
                    } else {
                        result.error("ERROR", "Nombre del sonido no proporcionado", null)
                    }
                }
                "stopSound" -> {
                    mediaPlayer?.stop()
                    mediaPlayer?.release()
                    mediaPlayer = null
                    handler.removeCallbacksAndMessages(null)
                    Log.d("MainActivity", "Sonido detenido manualmente")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
        Log.d("MainActivity", "Sonido detenido en onPause()")
    }

    override fun onStop() {
        super.onStop()
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
        Log.d("MainActivity", "Sonido detenido en onStop()")
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        handler.removeCallbacksAndMessages(null)
        Log.d("MainActivity", "Sonido detenido en onDestroy()")
    }
}