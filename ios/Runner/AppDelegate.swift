import UIKit
import Flutter
import CoreLocation
import CoreBluetooth

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate, CBCentralManagerDelegate {
    
    private var locationManager: CLLocationManager?
    private var centralManager: CBCentralManager?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: "com.caldensmart.sime/native", binaryMessenger: controller.binaryMessenger)
        
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "isLocationServiceEnabled":
                self?.checkLocationServices(result: result)
            case "openLocationSettings":
                self?.openLocationSettings(result: result)
            case "isBluetoothOn":
                self?.checkBluetoothState(result: result)
            case "turnOnBluetooth":
                self?.requestBluetoothActivation(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Verificar si los servicios de localización están habilitados
    private func checkLocationServices(result: FlutterResult) {
        if CLLocationManager.locationServicesEnabled() {
            result(true)
        } else {
            result(false)
        }
    }
    
    // Abrir configuración de servicios de localización
    private func openLocationSettings(result: FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                result(nil)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "No se puede abrir la configuración", details: nil))
            }
        }
    }
    
    // Verificar si el Bluetooth está encendido
    private func checkBluetoothState(result: FlutterResult) {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        if let centralManager = centralManager {
            if centralManager.state == .poweredOn {
                result(true)
            } else {
                result(false)
            }
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Bluetooth no está disponible", details: nil))
        }
    }
    
    // Solicitar activación del Bluetooth (esto no puede encenderlo automáticamente)
    private func requestBluetoothActivation(result: FlutterResult) {
        if centralManager?.state == .poweredOff {
            result(FlutterError(code: "UNAVAILABLE", message: "No se puede encender el Bluetooth automáticamente", details: nil))
        } else {
            result(true)
        }
    }
    
    // Delegado para CBCentralManager
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Implementación si es necesario
    }
}
