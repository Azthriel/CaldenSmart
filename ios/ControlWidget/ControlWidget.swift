//
//  ControlWidget.swift
//  ControlWidget
//
//  CaldenSmart Widget for iOS
//  Equivalent to Android's ControlWidgetProvider.kt
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry
/// Representa los datos que el widget necesita para renderizarse
struct ControlWidgetEntry: TimelineEntry {
    let date: Date
    let widgetId: Int
    let nickname: String
    let isControl: Bool      // true = control (toggle), false = display only
    let isOnline: Bool
    let isOn: Bool
    let isLoading: Bool
    let isServiceReady: Bool
    let productCode: String?
    let displayTemp: String?
    let displayAlert: Bool
    let isDisplayType: Bool
    let pinLabel: String?
    
    // Entry por defecto para placeholder
    static var placeholder: ControlWidgetEntry {
        ControlWidgetEntry(
            date: Date(),
            widgetId: 0,
            nickname: "CaldenSmart",
            isControl: true,
            isOnline: false,
            isOn: false,
            isLoading: false,
            isServiceReady: false,
            productCode: nil,
            displayTemp: nil,
            displayAlert: false,
            isDisplayType: false,
            pinLabel: nil
        )
    }
    
    // Entry para widget no configurado
    static var unconfigured: ControlWidgetEntry {
        ControlWidgetEntry(
            date: Date(),
            widgetId: -1,
            nickname: "CaldenSmart",
            isControl: true,
            isOnline: false,
            isOn: false,
            isLoading: false,
            isServiceReady: false,
            productCode: nil,
            displayTemp: nil,
            displayAlert: false,
            isDisplayType: false,
            pinLabel: nil
        )
    }
}

// MARK: - Timeline Provider
/// Provee los datos al widget y define cuándo actualizarse
struct ControlWidgetProvider: TimelineProvider {
    
    // App Group para compartir datos con la app principal
    private let appGroupId = "group.com.caldensmart.sime"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    // Placeholder mientras carga
    func placeholder(in context: Context) -> ControlWidgetEntry {
        return .placeholder
    }
    
    // Snapshot para preview en galería de widgets
    func getSnapshot(in context: Context, completion: @escaping (ControlWidgetEntry) -> Void) {
        let entry = loadWidgetData(widgetId: 0) ?? .placeholder
        completion(entry)
    }
    
    // Timeline real con actualizaciones
    func getTimeline(in context: Context, completion: @escaping (Timeline<ControlWidgetEntry>) -> Void) {
        // Obtener el widgetId guardado para esta instancia
        // En iOS, usamos el contexto de configuración del widget
        let widgetId = getWidgetId(for: context)
        
        let entry = loadWidgetData(widgetId: widgetId) ?? .unconfigured
        
        // Actualizar cada 15 minutos (similar a Android WorkManager)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // MARK: - Data Loading
    
    private func getWidgetId(for context: Context) -> Int {
        // En iOS, el widget ID se maneja diferente
        // Usamos el configurationDisplayName o un ID almacenado
        guard let defaults = sharedDefaults else { return 0 }
        
        // Intentar obtener el widget ID del contexto
        // Por ahora retornamos 0, en Xcode se configurará con Intent
        return defaults.integer(forKey: "current_widget_id")
    }
    
    private func loadWidgetData(widgetId: Int) -> ControlWidgetEntry? {
        guard let defaults = sharedDefaults else { return nil }
        
        // Leer datos equivalentes a Android SharedPreferences
        let nickname = defaults.string(forKey: "widget_nickname_\(widgetId)") ?? ""
        
        // Si no hay nickname, el widget no está configurado
        if nickname.isEmpty {
            return .unconfigured
        }
        
        let isControl = defaults.bool(forKey: "widget_is_control_\(widgetId)")
        let isOnline = defaults.bool(forKey: "widget_online_\(widgetId)")
        let isOn = defaults.bool(forKey: "widget_status_\(widgetId)")
        let isLoading = defaults.bool(forKey: "widget_loading_\(widgetId)")
        let isServiceReady = defaults.bool(forKey: "widget_service_ready")
        let productCode = defaults.string(forKey: "widget_pc_\(widgetId)")
        let displayTemp = defaults.string(forKey: "widget_display_temp_\(widgetId)")
        let displayAlert = defaults.bool(forKey: "widget_display_alert_\(widgetId)")
        let isDisplayType = defaults.bool(forKey: "widget_is_display_type_\(widgetId)")
        
        // Pin label
        let isPin = defaults.bool(forKey: "widget_is_pin_\(widgetId)")
        let pinIndex = defaults.string(forKey: "widget_pin_index_\(widgetId)")
        let pinLabel: String? = isPin ? "PIN \(pinIndex ?? "1")" : nil
        
        return ControlWidgetEntry(
            date: Date(),
            widgetId: widgetId,
            nickname: nickname,
            isControl: isControl,
            isOnline: isOnline,
            isOn: isOn,
            isLoading: isLoading,
            isServiceReady: isServiceReady,
            productCode: productCode,
            displayTemp: displayTemp,
            displayAlert: displayAlert,
            isDisplayType: isDisplayType,
            pinLabel: pinLabel
        )
    }
}

// MARK: - Widget View
/// Vista principal del widget (equivalente a widget_layout.xml)
struct ControlWidgetView: View {
    var entry: ControlWidgetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Header: Logo + Connection status
                headerView
                
                Spacer()
                
                // Device name
                Text(entry.nickname)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Pin label si aplica
                if let pinLabel = entry.pinLabel {
                    Text(pinLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "FFD600"))
                }
                
                Spacer()
                
                // Footer: Status icon or text
                HStack {
                    Spacer()
                    footerView
                }
            }
            .padding(10)
            
            // Loading overlay
            if entry.isLoading {
                loadingOverlay
            }
        }
        .widgetURL(widgetURL)
    }
    
    // MARK: - Subviews
    
    private var backgroundView: some View {
        Group {
            if entry.nickname == "CaldenSmart" && entry.widgetId <= 0 {
                // Widget no configurado
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "424242"))
            } else if !entry.isOnline {
                // Offline
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "616161"))
            } else if entry.displayAlert {
                // Alert state
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color(hex: "B71C1C"), Color(hex: "C62828")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            } else if entry.isOn && entry.isControl {
                // On state
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color(hex: "1565C0"), Color(hex: "1976D2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            } else {
                // Off state
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color(hex: "37474F"), Color(hex: "455A64")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Logo
            Image("dragon_foreground")
                .resizable()
                .frame(width: 23, height: 23)
            
            Spacer()
            
            // Connection status
            connectionIcon
        }
    }
    
    private var connectionIcon: some View {
        Group {
            if entry.nickname == "CaldenSmart" && entry.widgetId <= 0 {
                // Settings icon for unconfigured widget
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
                    .frame(width: 25, height: 25)
            } else if entry.isOnline {
                Image(systemName: "wifi")
                    .foregroundColor(Color(hex: "4CAF50"))
                    .frame(width: 25, height: 25)
            } else {
                Image(systemName: "wifi.slash")
                    .foregroundColor(Color(hex: "9E9E9E"))
                    .frame(width: 25, height: 25)
            }
        }
    }
    
    private var footerView: some View {
        Group {
            if entry.nickname == "CaldenSmart" && entry.widgetId <= 0 {
                // Empty for unconfigured
                EmptyView()
            } else if !entry.isServiceReady && entry.isOnline && entry.isControl {
                // Service initializing
                Text("Iniciando...")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "9E9E9E"))
            } else if entry.isControl {
                // Control widget - show toggle icon
                Image(systemName: entry.isOn ? "power.circle.fill" : "power.circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(entry.isOn ? .white : Color(hex: "9E9E9E"))
            } else if entry.productCode == "023430_IOT" {
                // Temperature sensor
                let tempText = entry.displayTemp != nil ? "\(entry.displayTemp!)°C" : "--°C"
                Text(tempText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "2196F3"))
            } else if entry.productCode == "015773_IOT" || entry.isDisplayType {
                // Alert sensor
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(entry.displayAlert ? Color(hex: "F44336") : Color(hex: "9E9E9E"))
            } else {
                EmptyView()
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
    }
    
    // MARK: - Widget URL
    
    private var widgetURL: URL? {
        if entry.nickname == "CaldenSmart" && entry.widgetId <= 0 {
            // Widget no configurado - abrir app para configurar
            return URL(string: "caldensmart://widget/configure")
        } else if entry.isControl && entry.isOnline && !entry.isLoading && entry.isServiceReady {
            // Widget de control - toggle
            return URL(string: "caldensmart://widget/toggle?widgetId=\(entry.widgetId)")
        } else {
            // Solo abrir la app
            return URL(string: "caldensmart://app")
        }
    }
}

// MARK: - Widget Configuration
@main
struct ControlWidget: Widget {
    let kind: String = "ControlWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ControlWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                ControlWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ControlWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("CaldenSmart Control")
        .description("Controla tus dispositivos CaldenSmart desde la pantalla de inicio.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    ControlWidget()
} timeline: {
    ControlWidgetEntry.placeholder
    ControlWidgetEntry(
        date: Date(),
        widgetId: 1,
        nickname: "Sala de Estar",
        isControl: true,
        isOnline: true,
        isOn: true,
        isLoading: false,
        isServiceReady: true,
        productCode: nil,
        displayTemp: nil,
        displayAlert: false,
        isDisplayType: false,
        pinLabel: nil
    )
    ControlWidgetEntry(
        date: Date(),
        widgetId: 2,
        nickname: "Habitación",
        isControl: true,
        isOnline: true,
        isOn: false,
        isLoading: false,
        isServiceReady: true,
        productCode: nil,
        displayTemp: nil,
        displayAlert: false,
        isDisplayType: false,
        pinLabel: "PIN 1"
    )
}
