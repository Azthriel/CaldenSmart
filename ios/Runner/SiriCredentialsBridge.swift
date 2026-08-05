import Flutter
import Foundation
import UIKit

/// Puente Flutter -> Keychain compartido.
///
/// Flutter es el unico que sabe el refresh token (se lo da Amplify al loguearse).
/// La extension no puede pedirselo a Amplify, asi que la app se lo deja
/// escrito en el Keychain group.
///
/// Este archivo va SOLO en el target Runner (la extension no lo necesita).
enum SiriCredentialsBridge {

    private static let channelName = "com.caldensmart.sime/siri"
    private static let appGroup = "group.com.caldensmart.sime"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        channel.setMethodCallHandler { call, result in
            switch call.method {

            case "saveRefreshToken":
                guard
                    let args = call.arguments as? [String: Any],
                    let token = args["refreshToken"] as? String,
                    !token.isEmpty
                else {
                    result(FlutterError(
                        code: "BAD_ARGS",
                        message: "Falta refreshToken",
                        details: nil
                    ))
                    return
                }
                // El refresh token cambio: invalidamos el ID token cacheado para
                // que el proximo intent renueve con la credencial nueva.
                KeychainStore.delete(.cachedIdToken)
                KeychainStore.delete(.cachedIdTokenExpiry)
                result(KeychainStore.save(token, for: .refreshToken))

            case "clearCredentials":
                // Logout. Sin esto, Siri seguiria controlando los equipos del
                // usuario anterior hasta que venza el refresh token.
                KeychainStore.clearAll()
                UserDefaults(suiteName: Self.appGroup)?.set("[]", forKey: "siri_devices")
                result(true)

            case "hasCredentials":
                result(KeychainStore.read(.refreshToken) != nil)

            case "saveDevices":
                // La lista de equipos para Siri va al App Group, no al Keychain:
                // no es secreta y la extension la lee en cada invocacion.
                guard
                    let args = call.arguments as? [String: Any],
                    let json = args["devices"] as? String
                else {
                    result(FlutterError(
                        code: "BAD_ARGS",
                        message: "Falta devices",
                        details: nil
                    ))
                    return
                }
                guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
                    result(FlutterError(
                        code: "NO_APP_GROUP",
                        message: "No se pudo abrir el App Group \(Self.appGroup)",
                        details: nil
                    ))
                    return
                }
                defaults.set(json, forKey: "siri_devices")
                result(true)

            case "openSiriSetup":
                guard let root = Self.rootViewController() else {
                    result(FlutterError(
                        code: "NO_CONTROLLER",
                        message: "No hay view controller para presentar",
                        details: nil
                    ))
                    return
                }
                SiriSetupPresenter.present(from: root)
                result(true)

            case "isSiriAvailable":
                if #available(iOS 16.0, *) { result(true) } else { result(false) }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
