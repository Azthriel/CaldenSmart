//
//  ControlWidgetBundle.swift
//  ControlWidget
//
//  Bundle que contiene todos los widgets de CaldenSmart
//  Este archivo solo es necesario si tienes múltiples widgets
//

import WidgetKit
import SwiftUI

/// Bundle de widgets de CaldenSmart
/// Agrupa todos los widgets disponibles para la app
/// 
/// NOTA: Si solo tienes un widget, puedes usar @main directamente en ControlWidget.swift
/// y no necesitas este archivo. Está preparado por si quieres agregar más widgets en el futuro.
///
/// Ejemplo de uso con múltiples widgets:
/// ```swift
/// @main
/// struct CaldenSmartWidgetBundle: WidgetBundle {
///     var body: some Widget {
///         ControlWidget()          // Widget de control on/off
///         TemperatureWidget()      // Widget solo temperatura
///         AlertWidget()            // Widget de alertas
///     }
/// }
/// ```

// Descomentar esto y comentar @main en ControlWidget.swift si necesitas múltiples widgets
/*
@main
struct CaldenSmartWidgetBundle: WidgetBundle {
    var body: some Widget {
        ControlWidget()
        // Agregar más widgets aquí cuando los necesites
    }
}
*/
