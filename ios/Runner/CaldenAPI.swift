import Foundation

/// Cliente del backend de Siri.
///
/// Un POST plano contra el Lambda siri_command, con el ID token de Cognito en
/// el header Authorization. Sin SDK: la extension tiene poca memoria y ~10s.
///
/// Este archivo va SOLO en el target de la App Intents Extension.
enum CaldenAPI {

    private static let endpoint = "https://tnnmga3g8i.execute-api.us-east-1.amazonaws.com/v1/command"

    enum Action: String {
        case on, off, toggle
    }

    /// Error con una frase ya lista para que Siri la diga en voz alta.
    struct APIError: LocalizedError {
        let speak: String
        var errorDescription: String? { speak }
    }

    /// Manda el comando y devuelve la frase de confirmacion.
    @discardableResult
    static func send(
        productCode: String,
        serialNumber: String,
        index: Int,
        action: Action
    ) async throws -> String {

        // 1. Credencial. Si falla aca, el problema es la sesion, no el equipo.
        let token: String
        do {
            token = try await CognitoRefresher.idToken()
        } catch CognitoRefresher.RefreshError.noRefreshToken {
            throw APIError(speak: "Inicia sesion en Calden Smart para usar Siri.")
        } catch CognitoRefresher.RefreshError.refreshRejected {
            throw APIError(speak: "Tu sesion vencio. Abri Calden Smart para reconectar.")
        } catch {
            throw APIError(speak: "No pude conectarme. Revisa tu conexion.")
        }

        // 2. Request.
        guard let url = URL(string: endpoint) else {
            throw APIError(speak: "Hubo un problema de configuracion.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        // Siri corta el intent alrededor de los 10s. Dejamos margen para que la
        // frase de error alcance a decirse en vez de que muera el proceso.
        request.timeoutInterval = 7
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "productCode": productCode,
            "serialNumber": serialNumber,
            "index": index,
            "action": action.rawValue,
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError(speak: "No pude conectarme. Revisa tu conexion.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(speak: "Hubo un problema al enviar el comando.")
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        // 3. Exito: el Lambda ya manda la frase en "speak".
        if http.statusCode == 200 {
            return (json?["speak"] as? String) ?? "Listo."
        }

        // 4. Error. El 401 lo puede tirar API Gateway ANTES del Lambda (token
        // vencido justo en el borde), y en ese caso no viene "speak".
        if http.statusCode == 401 {
            throw APIError(speak: "Tu sesion vencio. Abri Calden Smart para reconectar.")
        }

        let speak = (json?["speak"] as? String) ?? "Hubo un problema al enviar el comando."
        throw APIError(speak: speak)
    }
}
