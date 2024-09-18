package com.caldensmart.sime
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.caldensmart.sime/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "isLocationServiceEnabled") {
                val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                result.success(locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER))
            }else if(call.method == "openLocationSettings") {
    val intent = Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
    startActivity(intent)
    result.success(null)
    } else if(call.method == "isBluetoothOn"){
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null) {
            result.error("UNAVAILABLE", "Bluetooth no está disponible en este dispositivo", null)
        } else {
            result.success(bluetoothAdapter.isEnabled)
        }
    } else if (call.method == "turnOnBluetooth") {
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter != null && !bluetoothAdapter.isEnabled) {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, 0)
            result.success(true)
        } else {
            result.success(false)
        }
    }else {
                result.notImplemented()
            }
        }
    }
}
