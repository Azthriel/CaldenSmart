//
//  WidgetDataManager.swift
//  ControlWidget
//
//  Maneja la comunicación de datos entre la app Flutter y el widget iOS
//  Equivalente al uso de SharedPreferences en Android
//

import Foundation
import WidgetKit

/// Gestor de datos para widgets de CaldenSmart
/// Usa App Group para compartir datos entre la app principal y los widgets
class WidgetDataManager {
    
    // MARK: - Singleton
    static let shared = WidgetDataManager()
    
    // MARK: - Constants
    
    /// Identificador del App Group compartido
    /// IMPORTANTE: Este debe coincidir con:
    /// 1. El App Group configurado en Xcode para la app principal
    /// 2. El App Group configurado en Xcode para la extensión del widget
    /// 3. El groupId configurado en home_widget en Flutter
    static let appGroupId = "group.com.caldensmart.sime"
    
    /// Keys para datos compartidos
    struct Keys {
        static let serviceReady = "widget_service_ready"
        static let activeWidgetIds = "active_widget_ids"
        static let widgetServiceEnabled = "widgetServiceEnabled"
        
        // Keys dinámicas por widget
        static func device(_ widgetId: Int) -> String { "widget_device_\(widgetId)" }
        static func nickname(_ widgetId: Int) -> String { "widget_nickname_\(widgetId)" }
        static func isControl(_ widgetId: Int) -> String { "widget_is_control_\(widgetId)" }
        static func online(_ widgetId: Int) -> String { "widget_online_\(widgetId)" }
        static func status(_ widgetId: Int) -> String { "widget_status_\(widgetId)" }
        static func pc(_ widgetId: Int) -> String { "widget_pc_\(widgetId)" }
        static func sn(_ widgetId: Int) -> String { "widget_sn_\(widgetId)" }
        static func isPin(_ widgetId: Int) -> String { "widget_is_pin_\(widgetId)" }
        static func pinIndex(_ widgetId: Int) -> String { "widget_pin_index_\(widgetId)" }
        static func temperature(_ widgetId: Int) -> String { "widget_temperature_\(widgetId)" }
        static func alert(_ widgetId: Int) -> String { "widget_alert_\(widgetId)" }
        static func loading(_ widgetId: Int) -> String { "widget_loading_\(widgetId)" }
        static func initializing(_ widgetId: Int) -> String { "widget_initializing_\(widgetId)" }
        static func isDisplayType(_ widgetId: Int) -> String { "widget_is_display_type_\(widgetId)" }
        static func displayTemp(_ widgetId: Int) -> String { "widget_display_temp_\(widgetId)" }
        static func displayAlert(_ widgetId: Int) -> String { "widget_display_alert_\(widgetId)" }
    }
    
    // MARK: - Properties
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetDataManager.appGroupId)
    }
    
    private init() {}
    
    // MARK: - Read Methods
    
    /// Lee un valor string de los datos compartidos
    func getString(forKey key: String) -> String? {
        return sharedDefaults?.string(forKey: key)
    }
    
    /// Lee un valor bool de los datos compartidos
    func getBool(forKey key: String) -> Bool {
        return sharedDefaults?.bool(forKey: key) ?? false
    }
    
    /// Lee un valor int de los datos compartidos
    func getInt(forKey key: String) -> Int {
        return sharedDefaults?.integer(forKey: key) ?? 0
    }
    
    /// Lee un valor double de los datos compartidos
    func getDouble(forKey key: String) -> Double {
        return sharedDefaults?.double(forKey: key) ?? 0.0
    }
    
    // MARK: - Write Methods
    
    /// Guarda un valor string
    func setString(_ value: String?, forKey key: String) {
        sharedDefaults?.set(value, forKey: key)
    }
    
    /// Guarda un valor bool
    func setBool(_ value: Bool, forKey key: String) {
        sharedDefaults?.set(value, forKey: key)
    }
    
    /// Guarda un valor int
    func setInt(_ value: Int, forKey key: String) {
        sharedDefaults?.set(value, forKey: key)
    }
    
    /// Guarda un valor double
    func setDouble(_ value: Double, forKey key: String) {
        sharedDefaults?.set(value, forKey: key)
    }
    
    /// Elimina un valor
    func remove(forKey key: String) {
        sharedDefaults?.removeObject(forKey: key)
    }
    
    // MARK: - Widget Specific Methods
    
    /// Obtiene todos los IDs de widgets activos
    func getActiveWidgetIds() -> [Int] {
        guard let jsonString = getString(forKey: Keys.activeWidgetIds),
              let data = jsonString.data(using: .utf8),
              let ids = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return ids
    }
    
    /// Guarda los IDs de widgets activos
    func setActiveWidgetIds(_ ids: [Int]) {
        if let data = try? JSONEncoder().encode(ids),
           let jsonString = String(data: data, encoding: .utf8) {
            setString(jsonString, forKey: Keys.activeWidgetIds)
        }
    }
    
    /// Registra un nuevo widget ID
    func registerWidgetId(_ widgetId: Int) {
        var ids = getActiveWidgetIds()
        if !ids.contains(widgetId) {
            ids.append(widgetId)
            setActiveWidgetIds(ids)
        }
    }
    
    /// Elimina un widget ID
    func unregisterWidgetId(_ widgetId: Int) {
        var ids = getActiveWidgetIds()
        ids.removeAll { $0 == widgetId }
        setActiveWidgetIds(ids)
        
        // Limpiar todos los datos asociados a este widget
        cleanupWidgetData(widgetId)
    }
    
    /// Limpia todos los datos de un widget
    private func cleanupWidgetData(_ widgetId: Int) {
        let keysToRemove = [
            Keys.device(widgetId),
            Keys.nickname(widgetId),
            Keys.isControl(widgetId),
            Keys.online(widgetId),
            Keys.status(widgetId),
            Keys.pc(widgetId),
            Keys.sn(widgetId),
            Keys.isPin(widgetId),
            Keys.pinIndex(widgetId),
            Keys.temperature(widgetId),
            Keys.alert(widgetId),
            Keys.loading(widgetId),
            Keys.initializing(widgetId),
            Keys.isDisplayType(widgetId),
            Keys.displayTemp(widgetId),
            Keys.displayAlert(widgetId)
        ]
        
        for key in keysToRemove {
            remove(forKey: key)
        }
    }
    
    /// Verifica si el servicio está listo
    func isServiceReady() -> Bool {
        return getBool(forKey: Keys.serviceReady)
    }
    
    // MARK: - Widget Update
    
    /// Solicita que todos los widgets se actualicen
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Solicita que el widget específico se actualice
    func reloadWidget(kind: String = "ControlWidget") {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}

// MARK: - Widget Data Model
/// Modelo de datos completo para un widget
struct WidgetData: Codable {
    let widgetId: Int
    var device: String?
    var nickname: String
    var isControl: Bool
    var isOnline: Bool
    var isOn: Bool
    var productCode: String?
    var serialNumber: String?
    var isPin: Bool
    var pinIndex: String?
    var temperature: String?
    var alert: Bool
    var isDisplayType: Bool
    var displayTemp: String?
    var displayAlert: Bool
    var isLoading: Bool
    var isInitializing: Bool
    
    init(widgetId: Int) {
        self.widgetId = widgetId
        self.nickname = ""
        self.isControl = true
        self.isOnline = false
        self.isOn = false
        self.isPin = false
        self.alert = false
        self.isDisplayType = false
        self.displayAlert = false
        self.isLoading = false
        self.isInitializing = false
    }
    
    /// Carga los datos desde UserDefaults
    static func load(widgetId: Int) -> WidgetData {
        let manager = WidgetDataManager.shared
        var data = WidgetData(widgetId: widgetId)
        
        data.device = manager.getString(forKey: WidgetDataManager.Keys.device(widgetId))
        data.nickname = manager.getString(forKey: WidgetDataManager.Keys.nickname(widgetId)) ?? ""
        data.isControl = manager.getBool(forKey: WidgetDataManager.Keys.isControl(widgetId))
        data.isOnline = manager.getBool(forKey: WidgetDataManager.Keys.online(widgetId))
        data.isOn = manager.getBool(forKey: WidgetDataManager.Keys.status(widgetId))
        data.productCode = manager.getString(forKey: WidgetDataManager.Keys.pc(widgetId))
        data.serialNumber = manager.getString(forKey: WidgetDataManager.Keys.sn(widgetId))
        data.isPin = manager.getBool(forKey: WidgetDataManager.Keys.isPin(widgetId))
        data.pinIndex = manager.getString(forKey: WidgetDataManager.Keys.pinIndex(widgetId))
        data.temperature = manager.getString(forKey: WidgetDataManager.Keys.temperature(widgetId))
        data.alert = manager.getBool(forKey: WidgetDataManager.Keys.alert(widgetId))
        data.isDisplayType = manager.getBool(forKey: WidgetDataManager.Keys.isDisplayType(widgetId))
        data.displayTemp = manager.getString(forKey: WidgetDataManager.Keys.displayTemp(widgetId))
        data.displayAlert = manager.getBool(forKey: WidgetDataManager.Keys.displayAlert(widgetId))
        data.isLoading = manager.getBool(forKey: WidgetDataManager.Keys.loading(widgetId))
        data.isInitializing = manager.getBool(forKey: WidgetDataManager.Keys.initializing(widgetId))
        
        return data
    }
    
    /// Guarda los datos en UserDefaults
    func save() {
        let manager = WidgetDataManager.shared
        
        manager.setString(device, forKey: WidgetDataManager.Keys.device(widgetId))
        manager.setString(nickname, forKey: WidgetDataManager.Keys.nickname(widgetId))
        manager.setBool(isControl, forKey: WidgetDataManager.Keys.isControl(widgetId))
        manager.setBool(isOnline, forKey: WidgetDataManager.Keys.online(widgetId))
        manager.setBool(isOn, forKey: WidgetDataManager.Keys.status(widgetId))
        manager.setString(productCode, forKey: WidgetDataManager.Keys.pc(widgetId))
        manager.setString(serialNumber, forKey: WidgetDataManager.Keys.sn(widgetId))
        manager.setBool(isPin, forKey: WidgetDataManager.Keys.isPin(widgetId))
        manager.setString(pinIndex, forKey: WidgetDataManager.Keys.pinIndex(widgetId))
        manager.setString(temperature, forKey: WidgetDataManager.Keys.temperature(widgetId))
        manager.setBool(alert, forKey: WidgetDataManager.Keys.alert(widgetId))
        manager.setBool(isDisplayType, forKey: WidgetDataManager.Keys.isDisplayType(widgetId))
        manager.setString(displayTemp, forKey: WidgetDataManager.Keys.displayTemp(widgetId))
        manager.setBool(displayAlert, forKey: WidgetDataManager.Keys.displayAlert(widgetId))
        manager.setBool(isLoading, forKey: WidgetDataManager.Keys.loading(widgetId))
        manager.setBool(isInitializing, forKey: WidgetDataManager.Keys.initializing(widgetId))
    }
}
