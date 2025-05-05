import UIKit
import Flutter
import CoreLocation
import UserNotifications
import flutter_local_notifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler, CLLocationManagerDelegate {
    private let LOCATION_STREAM = "com.caldensmart.sime/locationStream"
    private let CHANNEL         = "com.caldensmart.sime/native"

    var locMgr: CLLocationManager?
    var locEventSink: FlutterEventSink?
    var audioPlayer: AVAudioPlayer?
    var soundTimer: Timer?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController

        // 1) EventChannel para Location
        let locChannel = FlutterEventChannel(
            name: LOCATION_STREAM,
            binaryMessenger: controller.binaryMessenger
        )
        locChannel.setStreamHandler(self)

        // 2) MethodChannel para métodos nativos
        let mChannel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        mChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "isLocationServiceEnabled":
                result(CLLocationManager.locationServicesEnabled())

            case "openLocationSettings":
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                result(nil)

            case "isBluetoothOn":
                let bt = CBCentralManager()
                result(bt.state == .poweredOn)

            case "turnOnBluetooth":
                let bt = CBCentralManager()
                if bt.state != .poweredOn {
                    result(FlutterError(code: "UNAVAILABLE", message: "No se puede activar BT", details: nil))
                } else {
                    result(true)
                }

            case "playSound":
                guard let args = call.arguments as? [String: Any],
                      let soundName = args["soundName"] as? String,
                      let delay = args["delay"] as? Int else {
                    result(FlutterError(code: "ERROR", message: "Faltan soundName/delay", details: nil))
                    return
                }
                self?.audioPlayer?.stop()
                self?.audioPlayer = nil
                self?.soundTimer?.invalidate()
                self?.soundTimer = nil

                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("AVAudioSession error: \(error)")
                }

                if let url = Bundle.main.url(forResource: soundName, withExtension: "wav") {
                    do {
                        self?.audioPlayer = try AVAudioPlayer(contentsOf: url)
                        self?.audioPlayer?.play()
                        self?.soundTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(delay)/1000, repeats: false) { _ in
                            self?.stopSound()
                        }
                    } catch {
                        print("AudioPlayer error: \(error)")
                    }
                } else {
                    print("No existe \(soundName).wav")
                }
                result(nil)

            case "stopSound":
                self?.stopSound()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Notificaciones iOS10+
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        locEventSink = events
        locMgr = CLLocationManager()
        locMgr?.delegate = self
        events(CLLocationManager.locationServicesEnabled())
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        locMgr?.delegate = nil
        locMgr = nil
        locEventSink = nil
        return nil
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locEventSink?(CLLocationManager.locationServicesEnabled())
    }

    // MARK: Audio helper

    private func stopSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        soundTimer?.invalidate()
        soundTimer = nil
    }
}
