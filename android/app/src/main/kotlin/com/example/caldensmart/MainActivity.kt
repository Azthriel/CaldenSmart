package com.caldensmart.sime

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.caldensmart.sime/native"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
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
                "enableWakeLock" -> {
                    enableWakeLock()
                    result.success(null)
                }
                "disableWakeLock" -> {
                    disableWakeLock()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enableWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "com.caldensmart::WakelockTag")
        }
        if (wakeLock?.isHeld == false) {
            wakeLock?.acquire()
        }
    }

    private fun disableWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
    }
}
