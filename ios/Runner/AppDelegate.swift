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
  var soundTimer: Timer?

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
          result(FlutterError(code: "UNAVAILABLE", message: "Cannot turn on Bluetooth directly", details: nil))
        } else {
          result(true)
        }
      case "playSound":
        if let args = call.arguments as? [String: Any],
          let soundName = args["soundName"] as? String,
          let delay = args["delay"] as? Int {

          self?.audioPlayer?.stop()
          self?.audioPlayer = nil
          self?.soundTimer?.invalidate()
          self?.soundTimer = nil

          do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
          } catch {
            print("Error configurando el AVAudioSession: \(error.localizedDescription)")
          }

          if let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") {
            do {
              self?.audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
              self?.audioPlayer?.play()
              print("Reproduciendo sonido: \(soundName)")

              self?.soundTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(delay) / 1000.0, repeats: false) { _ in
                self?.stopSound()
                print("Sonido detenido después de \(delay) ms")
              }
            } catch {
              print("Error al reproducir el sonido: \(error.localizedDescription)")
            }
          } else {
            print("Archivo de sonido no encontrado: \(soundName).wav")
          }
          result(nil)
        } else {
          result(FlutterError(code: "ERROR", message: "Nombre del sonido o delay no proporcionado", details: nil))
        }
      case "stopSound":
        self?.stopSound()
        result(nil)
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

  private func stopSound() {
    audioPlayer?.stop()
    audioPlayer = nil
    soundTimer?.invalidate()
    soundTimer = nil
    print("Sonido detenido manualmente")
  }
}