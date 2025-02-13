import CoreBluetooth
import CoreLocation
import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.caldensmart.sime/native"
  var audioPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let flutterViewController = window?.rootViewController as! FlutterViewController
    let methodChannel = FlutterMethodChannel(
      name: CHANNEL,
      binaryMessenger: flutterViewController.binaryMessenger)

    methodChannel.setMethodCallHandler {
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isLocationServiceEnabled":
        result(CLLocationManager.locationServicesEnabled())
      case "openLocationSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)
      case "isBluetoothOn":
        let bluetoothManager = CBCentralManager()
        result(bluetoothManager.state == .poweredOn)
      case "turnOnBluetooth":
        let bluetoothManager = CBCentralManager()
        if bluetoothManager.state != .poweredOn {
          // No es posible encender Bluetooth directamente en iOS, solicitará al usuario
          result(
            FlutterError(
              code: "UNAVAILABLE", message: "Cannot turn on Bluetooth directly", details: nil))
        } else {
          result(true)
        }
      case "playSound":
        if let args = call.arguments as? [String: Any],
           let soundName = args["soundName"] as? String {
          self?.playSound(soundName: soundName)
          result(nil)
        } else {
          result(FlutterError(code: "ERROR", message: "Nombre del sonido no proporcionado", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func playSound(soundName: String) {
    if let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
      do {
        audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
        audioPlayer?.play()
      } catch {
        print("Error al reproducir el sonido: \(error.localizedDescription)")
      }
    } else {
      print("Recurso de sonido no encontrado: \(soundName)")
    }
  }
}
