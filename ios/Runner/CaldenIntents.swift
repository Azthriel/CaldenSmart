import AppIntents

/// Los dos intents que expone la app. Sin toggle: requiere leer el estado
/// actual, y sime-domotica no refleja el estado en vivo de los pines.
///
/// @available(iOS 16.0, *) porque Runner apunta a iOS 15.
///
/// Target Membership: Runner + extension.

@available(iOS 16.0, *)
struct TurnOnDeviceIntent: AppIntent {

    static var title: LocalizedStringResource = "Prender equipo"
    static var description = IntentDescription("Prende un equipo o una salida de Calden Smart.")

    /// false = el intent corre sin abrir la app. Clave para que ande desde la
    /// pantalla bloqueada y para que sea rapido.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Equipo")
    var device: SiriDevice

    init() {}

    static var parameterSummary: some ParameterSummary {
        Summary("Prender \(\.$device)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await CaldenAPI.send(
            productCode: device.productCode,
            serialNumber: device.serialNumber,
            index: device.index,
            action: .on
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

@available(iOS 16.0, *)
struct TurnOffDeviceIntent: AppIntent {

    static var title: LocalizedStringResource = "Apagar equipo"
    static var description = IntentDescription("Apaga un equipo o una salida de Calden Smart.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Equipo")
    var device: SiriDevice

    init() {}

    static var parameterSummary: some ParameterSummary {
        Summary("Apagar \(\.$device)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await CaldenAPI.send(
            productCode: device.productCode,
            serialNumber: device.serialNumber,
            index: device.index,
            action: .off
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}