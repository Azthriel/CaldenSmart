import AppIntents

/// Frases que Siri reconoce de fabrica, sin que el usuario configure nada.
///
/// REGLA DE APPLE: toda frase DEBE contener \(.applicationName). Lo valida el
/// compilador. Por eso siempre queda "... con Calden Smart".
/// Para decir solo "prende las luces" el usuario tiene que armarse un atajo
/// personal: para eso esta el boton "Añadir a Siri" en la app.
///
/// El alias corto "Caldén" se declara en Info.plist con INAlternativeAppNames.
///
/// @available(iOS 16.0, *) porque Runner apunta a iOS 15.
///
/// Target Membership: SOLO Runner (el sistema busca el provider en el app
/// target, no en la extension).
@available(iOS 16.0, *)
struct CaldenShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        AppShortcut(
            intent: TurnOnDeviceIntent(),
            phrases: [
                "Prende \(\.$device) con \(.applicationName)",
                "Prendé \(\.$device) con \(.applicationName)",
                "Encende \(\.$device) con \(.applicationName)",
                "Encendé \(\.$device) con \(.applicationName)",
                "Encender \(\.$device) en \(.applicationName)",
            ],
            shortTitle: "Prender",
            systemImageName: "power"
        )

        AppShortcut(
            intent: TurnOffDeviceIntent(),
            phrases: [
                "Apaga \(\.$device) con \(.applicationName)",
                "Apagá \(\.$device) con \(.applicationName)",
                "Apagar \(\.$device) en \(.applicationName)",
            ],
            shortTitle: "Apagar",
            systemImageName: "power.circle"
        )
    }
}