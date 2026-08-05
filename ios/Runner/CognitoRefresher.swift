import Foundation

/// Canjea el refresh token guardado por Flutter en el Keychain compartido por un
/// ID token fresco, listo para mandar en el header Authorization del Lambda.
///
/// Por que no usamos Amplify aca: la extension es un proceso aparte con un
/// presupuesto de memoria chico y ~10s de vida. Amplify iOS no esta pensado para
/// eso. Estos son dos POST planos, sin SDK.
///
/// Dos caminos de refresh:
///   1. InitiateAuth (REFRESH_TOKEN_AUTH) -> usuarios nativos (USER_SRP_AUTH)
///   2. /oauth2/token (grant_type=refresh_token) -> usuarios federados (Google)
/// Probamos el 1 y si rebota caemos al 2. No hay forma barata de saber de
/// antemano como se logueo el usuario.
enum CognitoRefresher {

    // MARK: - Config

    private static let region = "sa-east-1"
    private static let clientId = "6tmd2ohbbm9cpv37jsrcoajemf"
    private static let hostedUIDomain = "caldensmart-dev.auth.sa-east-1.amazoncognito.com"

    /// Margen antes del vencimiento real. Si al token le quedan menos de estos
    /// segundos, lo renovamos igual: no queremos que expire a mitad del request.
    private static let expiryMargin: TimeInterval = 120

    enum RefreshError: Error {
        case noRefreshToken       // usuario nunca se logueo, o hizo logout
        case refreshRejected      // refresh token vencido o revocado -> abrir la app
        case network(Error)
        case malformedResponse
    }

    // MARK: - API

    /// ID token valido. Usa el cacheado si todavia sirve; si no, renueva.
    static func idToken() async throws -> String {
        if let cached = cachedIfValid() {
            return cached
        }

        guard let refreshToken = KeychainStore.read(.refreshToken) else {
            throw RefreshError.noRefreshToken
        }

        do {
            let result = try await refreshViaInitiateAuth(refreshToken)
            cache(result)
            return result.idToken
        } catch RefreshError.refreshRejected {
            // Probable usuario federado (Google). Segundo intento por Hosted UI.
            let result = try await refreshViaHostedUI(refreshToken)
            cache(result)
            return result.idToken
        }
    }

    // MARK: - Cache

    private struct TokenResult {
        let idToken: String
        let expiresIn: TimeInterval
    }

    private static func cachedIfValid() -> String? {
        guard
            let token = KeychainStore.read(.cachedIdToken),
            let expiryRaw = KeychainStore.read(.cachedIdTokenExpiry),
            let expiry = TimeInterval(expiryRaw)
        else { return nil }

        return Date().timeIntervalSince1970 + expiryMargin < expiry ? token : nil
    }

    private static func cache(_ result: TokenResult) {
        let expiry = Date().timeIntervalSince1970 + result.expiresIn
        _ = KeychainStore.save(result.idToken, for: .cachedIdToken)
        _ = KeychainStore.save(String(expiry), for: .cachedIdTokenExpiry)
    }

    // MARK: - Camino 1: InitiateAuth (usuarios nativos)

    private static func refreshViaInitiateAuth(_ refreshToken: String) async throws -> TokenResult {
        guard let url = URL(string: "https://cognito-idp.\(region).amazonaws.com/") else {
            throw RefreshError.malformedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "AWSCognitoIdentityProviderService.InitiateAuth",
            forHTTPHeaderField: "X-Amz-Target"
        )
        request.timeoutInterval = 8
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": clientId,
            "AuthParameters": ["REFRESH_TOKEN": refreshToken],
        ])

        let (data, response) = try await send(request)

        guard let http = response as? HTTPURLResponse else {
            throw RefreshError.malformedResponse
        }
        guard http.statusCode == 200 else {
            // NotAuthorizedException = token vencido/revocado, o usuario federado.
            // El caller decide si reintenta por Hosted UI.
            throw RefreshError.refreshRejected
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let auth = json["AuthenticationResult"] as? [String: Any],
            let idToken = auth["IdToken"] as? String
        else {
            throw RefreshError.malformedResponse
        }

        let expiresIn = (auth["ExpiresIn"] as? TimeInterval) ?? 3600
        return TokenResult(idToken: idToken, expiresIn: expiresIn)
    }

    // MARK: - Camino 2: Hosted UI (usuarios federados)

    private static func refreshViaHostedUI(_ refreshToken: String) async throws -> TokenResult {
        guard let url = URL(string: "https://\(hostedUIDomain)/oauth2/token") else {
            throw RefreshError.malformedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await send(request)

        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            // Aca ya no hay plan C: el usuario tiene que abrir la app.
            throw RefreshError.refreshRejected
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idToken = json["id_token"] as? String
        else {
            throw RefreshError.malformedResponse
        }

        let expiresIn = (json["expires_in"] as? TimeInterval) ?? 3600
        return TokenResult(idToken: idToken, expiresIn: expiresIn)
    }

    // MARK: - Helper

    private static func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw RefreshError.network(error)
        }
    }
}
