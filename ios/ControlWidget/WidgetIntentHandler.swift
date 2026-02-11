//
//  WidgetIntentHandler.swift
//  ControlWidget
//
//  Maneja las interacciones del usuario con el widget
//  Equivalente al HomeWidgetBackgroundIntent de Android
//

import Foundation
import AppIntents
import WidgetKit

// MARK: - Toggle Intent (iOS 16+)
/// Intent para ejecutar toggle desde el widget
/// Requiere iOS 16+ para App Intents
@available(iOS 16.0, *)
struct ToggleDeviceIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Toggle CaldenSmart Device"
    static var description = IntentDescription("Enciende o apaga un dispositivo CaldenSmart")
    
    /// ID del widget que ejecuta el toggle
    @Parameter(title: "Widget ID")
    var widgetId: Int
    
    init() {
        self.widgetId = 0
    }
    
    init(widgetId: Int) {
        self.widgetId = widgetId
    }
    
    /// Ejecuta el intent
    func perform() async throws -> some IntentResult {
        // Marcar como cargando
        let manager = WidgetDataManager.shared
        manager.setBool(true, forKey: WidgetDataManager.Keys.loading(widgetId))
        manager.reloadWidget()
        
        // Notificar a la app principal a través de URL scheme
        // La app Flutter manejará el toggle real
        if let url = URL(string: "caldensmart://widget/toggle?widgetId=\(widgetId)") {
            // En iOS, no podemos abrir URLs directamente desde una extensión
            // Guardamos el comando pendiente para que la app lo procese
            manager.setInt(widgetId, forKey: "pending_toggle_widget_id")
            manager.setDouble(Date().timeIntervalSince1970, forKey: "pending_toggle_timestamp")
        }
        
        // Actualizar widget para mostrar loading
        WidgetCenter.shared.reloadTimelines(ofKind: "ControlWidget")
        
        return .result()
    }
}

// MARK: - Interactive Widget (iOS 17+)
/// Extensión para soportar botones interactivos en widgets de iOS 17+
@available(iOS 17.0, *)
struct ToggleButton: View {
    let widgetId: Int
    let isOn: Bool
    let isEnabled: Bool
    
    var body: some View {
        Button(intent: ToggleDeviceIntent(widgetId: widgetId)) {
            Image(systemName: isOn ? "power.circle.fill" : "power.circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(isOn ? .white : .gray)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Widget Configuration Intent (para selección de dispositivo)
/// Intent para configurar qué dispositivo controla cada widget
/// Esto permite al usuario seleccionar un dispositivo desde la galería de widgets
@available(iOS 16.0, *)
struct ConfigureWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configurar Widget CaldenSmart"
    static var description = IntentDescription("Selecciona el dispositivo a controlar")
    
    /// Dispositivo seleccionado
    @Parameter(title: "Dispositivo")
    var device: DeviceEntity?
    
    init() {}
    
    init(device: DeviceEntity?) {
        self.device = device
    }
}

/// Entidad que representa un dispositivo para la configuración
@available(iOS 16.0, *)
struct DeviceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dispositivo"
    static var defaultQuery = DeviceEntityQuery()
    
    var id: String
    var nickname: String
    var productCode: String
    var serialNumber: String
    var isPin: Bool
    var pinIndex: String?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nickname)")
    }
}

/// Query para obtener dispositivos disponibles
@available(iOS 16.0, *)
struct DeviceEntityQuery: EntityQuery {
    
    func entities(for identifiers: [String]) async throws -> [DeviceEntity] {
        // Cargar dispositivos desde los datos compartidos
        return loadDevices().filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [DeviceEntity] {
        // Retornar todos los dispositivos disponibles
        return loadDevices()
    }
    
    func defaultResult() async -> DeviceEntity? {
        // Retornar el primer dispositivo como default
        return loadDevices().first
    }
    
    private func loadDevices() -> [DeviceEntity] {
        // TODO: Cargar desde App Group cuando Flutter guarde la lista de dispositivos
        // Por ahora retornamos vacío
        // La app Flutter debe guardar la lista de dispositivos en:
        // UserDefaults(suiteName: "group.com.caldensmart.sime")?.set(jsonString, forKey: "available_devices")
        
        guard let defaults = UserDefaults(suiteName: WidgetDataManager.appGroupId),
              let jsonString = defaults.string(forKey: "available_devices"),
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        
        do {
            let devices = try JSONDecoder().decode([DeviceEntity].self, from: data)
            return devices
        } catch {
            print("Error loading devices: \(error)")
            return []
        }
    }
}

// MARK: - Legacy Support (iOS 14-15)
/// Para iOS 14-15, usamos URL schemes en lugar de App Intents
/// El widget abre la app con una URL específica y la app maneja la acción

/*
 Flujo para iOS 14-15:
 1. Usuario toca el widget
 2. Widget usa .widgetURL(URL(string: "caldensmart://widget/toggle?widgetId=X"))
 3. iOS abre la app con esa URL
 4. AppDelegate recibe la URL en application(_:open:options:)
 5. Flutter procesa la acción
 6. Flutter actualiza los datos del widget
 7. Flutter llama HomeWidget.updateWidget()
 */
