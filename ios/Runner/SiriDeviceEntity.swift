import AppIntents
import Foundation

/// Un equipo (o una salida de un equipo multipin) que Siri puede controlar.
///
/// Los datos salen del App Group, donde SiriService (Dart) los deja escritos.
/// La extension no consulta DynamoDB: no tiene tiempo ni Amplify.
///
/// @available(iOS 16.0, *) porque Runner apunta a iOS 15 y App Intents existe
/// recien desde iOS 16. La extension apunta a 16, pero estos archivos compilan
/// en ambos targets.
///
/// Target Membership: Runner + extension.
@available(iOS 16.0, *)
struct SiriDevice: AppEntity, Identifiable {

    let id: String            // "027313_IOT#20051220#0"
    let name: String          // nickname del pin o del equipo -> "Luces"
    let room: String          // nickname del equipo, vacio si no aplica
    let productCode: String
    let serialNumber: String
    let index: Int

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Equipo")
    }

    var displayRepresentation: DisplayRepresentation {
        room.isEmpty
            ? DisplayRepresentation(title: "\(name)")
            : DisplayRepresentation(title: "\(name)", subtitle: "\(room)")
    }

    static var defaultQuery = SiriDeviceQuery()
}

/// Resuelve lo que dijo el usuario contra la lista del App Group.
///
/// EntityStringQuery (no solo EntityQuery) es lo que permite que Siri matchee
/// texto hablado: "las luces" -> el entity con name "Luces".
@available(iOS 16.0, *)
struct SiriDeviceQuery: EntityStringQuery {

    private static let appGroup = "group.com.caldensmart.sime"
    private static let devicesKey = "siri_devices"

    // MARK: - EntityQuery

    /// Por ID. Lo usa Siri cuando reejecuta un atajo ya armado.
    func entities(for identifiers: [SiriDevice.ID]) async throws -> [SiriDevice] {
        let all = Self.loadAll()
        let wanted = Set(identifiers)
        return all.filter { wanted.contains($0.id) }
    }

    /// Lo que Siri ofrece en la app Atajos y al desambiguar.
    func suggestedEntities() async throws -> [SiriDevice] {
        Self.loadAll()
    }

    // MARK: - EntityStringQuery

    /// Match por texto hablado. Siri no transcribe exacto, asi que vamos de
    /// mas estricto a mas laxo y devolvemos la primera tanda que da resultados.
    func entities(matching string: String) async throws -> [SiriDevice] {
        let all = Self.loadAll()
        let needle = Self.normalize(string)

        guard !needle.isEmpty else { return all }

        // 1. Coincidencia exacta del nombre.
        let exact = all.filter { Self.normalize($0.name) == needle }
        if !exact.isEmpty { return exact }

        // 2. El nombre contiene lo dicho, o al reves ("luces" vs "luces living").
        let contains = all.filter {
            let n = Self.normalize($0.name)
            return n.contains(needle) || needle.contains(n)
        }
        if !contains.isEmpty { return contains }

        // 3. Ultimo intento: incluimos el nombre del equipo en la busqueda,
        //    para cuando el usuario dice "las luces del quincho".
        return all.filter {
            let combined = Self.normalize("\($0.name) \($0.room)")
            return combined.contains(needle)
                || needle.split(separator: " ").contains { combined.contains($0) }
        }
    }

    // MARK: - Interno

    /// Minusculas, sin acentos, sin articulos. Siri devuelve "Las Luces" y en
    /// el App Group esta guardado como "Luces".
    private static func normalize(_ s: String) -> String {
        let stripped = s
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let articles: Set<String> = ["el", "la", "los", "las", "un", "una", "del", "de"]
        return stripped
            .split(separator: " ")
            .filter { !articles.contains(String($0)) }
            .joined(separator: " ")
    }

    private static func loadAll() -> [SiriDevice] {
        guard
            let defaults = UserDefaults(suiteName: appGroup),
            let json = defaults.string(forKey: devicesKey),
            let data = json.data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            NSLog("[SiriDeviceQuery] No hay equipos en el App Group")
            return []
        }

        return array.compactMap { dict in
            guard
                let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let productCode = dict["productCode"] as? String,
                let serialNumber = dict["serialNumber"] as? String,
                let index = dict["index"] as? Int
            else { return nil }

            return SiriDevice(
                id: id,
                name: name,
                room: dict["room"] as? String ?? "",
                productCode: productCode,
                serialNumber: serialNumber,
                index: index
            )
        }
    }
}