import AppIntents
import SwiftUI
import UIKit

/// Hoja que se abre desde Flutter para que el usuario arme su atajo personal.
///
/// Por que hace falta: las frases de AppShortcuts obligan a nombrar la app
/// ("prende las luces CON Calden"). Si el usuario crea un atajo propio y lo
/// llama "luces", puede decir solo "Oye Siri, luces". Este boton lo lleva
/// directo a la pantalla de Atajos de la app.
///
/// Target Membership: SOLO Runner.
@available(iOS 16.0, *)
struct SiriSetupView: View {

    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 32)

            Text("Controlá tus equipos con Siri")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                Label(
                    "Decí \"Oye Siri, prendé las luces con Caldén\" y listo.",
                    systemImage: "checkmark.circle.fill"
                )
                Label(
                    "¿Querés una frase más corta? Creá un atajo propio y nombralo como quieras.",
                    systemImage: "wand.and.stars"
                )
            }
            .font(.subheadline)
            .padding(.horizontal, 8)

            ShortcutsLink()
                .shortcutsLinkStyle(.automatic)

            Spacer()

            Button("Listo", action: onClose)
                .padding(.bottom, 24)
        }
        .padding(24)
    }
}

/// Presenta la hoja desde UIKit (que es lo que tenemos en un proyecto Flutter).
enum SiriSetupPresenter {

    static func present(from controller: UIViewController) {
        guard #available(iOS 16.0, *) else {
            let alert = UIAlertController(
                title: "No disponible",
                message: "Siri con Caldén Smart requiere iOS 16 o superior.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Entendido", style: .default))
            controller.present(alert, animated: true)
            return
        }

        var hosting: UIHostingController<SiriSetupView>?
        let view = SiriSetupView { hosting?.dismiss(animated: true) }
        let vc = UIHostingController(rootView: view)
        hosting = vc

        controller.present(vc, animated: true)
    }
}
