import Foundation

/// Acceso al Keychain compartido entre el target Runner y la App Intents Extension.
///
/// El grupo se declara en los .entitlements de AMBOS targets como
/// `$(AppIdentifierPrefix)com.caldensmart.sime`. En runtime hay que pasar el
/// prefijo del Team ID ya expandido, asi que lo leemos del Info.plist (ver
/// abajo) en vez de hardcodearlo.
///
/// AGREGAR AL Info.plist DE AMBOS TARGETS:
///     <key>AppIdentifierPrefix</key>
///     <string>$(AppIdentifierPrefix)</string>
/// Xcode expande esa variable en build time y queda "ABCDE12345." con el punto.
///
/// Este archivo va en AMBOS targets (Target Membership: Runner + extension).
enum KeychainStore {

    enum Key: String {
        case refreshToken = "siri_cognito_refresh_token"
        case cachedIdToken = "siri_cognito_id_token"
        case cachedIdTokenExpiry = "siri_cognito_id_token_expiry"
    }

    private static var accessGroup: String {
        let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? ""
        return "\(prefix)com.caldensmart.sime"
    }

    // MARK: - API

    static func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Borramos primero: SecItemUpdate no crea el item si no existe y
        // SecItemAdd falla con errSecDuplicateItem si ya esta.
        SecItemDelete(baseQuery(key) as CFDictionary)

        var query = baseQuery(key)
        query[kSecValueData as String] = data
        // AfterFirstUnlock es clave: sin esto, Siri invocado desde la pantalla
        // bloqueada no puede leer el token y el intent falla.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("[KeychainStore] save \(key.rawValue) fallo: \(status)")
        }
        return status == errSecSuccess
    }

    static func read(_ key: Key) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                // errSecMissingEntitlement (-34018) = falta keychain-access-groups
                // en los entitlements de este target.
                NSLog("[KeychainStore] read \(key.rawValue) fallo: \(status)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Borra todo lo de Siri. Se llama en logout desde Flutter.
    static func clearAll() {
        delete(.refreshToken)
        delete(.cachedIdToken)
        delete(.cachedIdTokenExpiry)
    }

    // MARK: - Interno

    private static func baseQuery(_ key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.caldensmart.sime.siri",
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessGroup as String: accessGroup,
        ]
    }
}
