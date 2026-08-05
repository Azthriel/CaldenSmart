import AppIntents
import ExtensionFoundation

/// Punto de entrada de la App Intents Extension.
///
/// Existe para que los intents corran en un proceso propio y liviano, sin
/// levantar el FlutterEngine. Es lo que hace que "prende las luces" responda
/// en menos de un segundo en vez de esperar el arranque de la app.
///
/// El import de ExtensionFoundation es obligatorio en Swift 6:
/// AppIntentsExtension hereda de AppExtension (que vive en ese modulo), y la
/// regla MemberImportVisibility no deja usar el main() heredado sin importarlo
/// de forma explicita.
///
/// Target Membership: SOLO la extension.
@main
struct CaldenIntentsExtension: AppIntentsExtension {
}