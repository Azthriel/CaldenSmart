# Instrucciones para Completar Widget iOS en Xcode

## Resumen de lo que ya está preparado

Los siguientes archivos ya fueron creados y están listos en `ios/ControlWidget/`:
- ✅ `ControlWidget.swift` - Widget principal con UI y lógica
- ✅ `ControlWidgetBundle.swift` - Bundle para múltiples widgets
- ✅ `WidgetDataManager.swift` - Gestor de datos compartidos
- ✅ `WidgetIntentHandler.swift` - Manejo de interacciones
- ✅ `Info.plist` - Configuración del widget
- ✅ `ControlWidget.entitlements` - App Group configurado
- ✅ `Assets.xcassets/` - Estructura de assets

También se actualizó:
- ✅ `Runner.entitlements` - App Group añadido
- ✅ Código Flutter - Soporte multiplataforma

---

## Pasos a completar en macOS con Xcode

### 1. Abrir el proyecto en Xcode
```bash
cd /path/to/caldensmart/ios
open Runner.xcworkspace
```

### 2. Agregar Widget Extension

1. En Xcode, selecciona **File → New → Target**
2. Busca y selecciona **Widget Extension**
3. Configura:
   - **Product Name**: `ControlWidget`
   - **Team**: Tu equipo de desarrollo
   - **Bundle Identifier**: `com.caldensmart.sime.ControlWidget`
   - **Include Configuration Intent**: ❌ (ya lo tenemos con App Intents)
   - **Include Live Activity**: ❌
4. Click en **Finish**
5. Cuando pregunte "Activate scheme?", click **Cancel**

### 3. Eliminar archivos generados automáticamente

Xcode habrá creado archivos por defecto. Elimínalos del proyecto:
- `ControlWidget.swift` (el generado por Xcode)
- Cualquier otro archivo que haya creado

### 4. Agregar los archivos preparados

1. En el navegador de Xcode, click derecho en el grupo `ControlWidget`
2. Selecciona **Add Files to "Runner"...**
3. Navega a `ios/ControlWidget/` y selecciona:
   - `ControlWidget.swift`
   - `ControlWidgetBundle.swift`
   - `WidgetDataManager.swift`
   - `WidgetIntentHandler.swift`
4. Asegúrate de que:
   - ✅ Copy items if needed: **NO**
   - ✅ Add to targets: **ControlWidget** (solo el widget, no Runner)
5. Click **Add**

### 5. Agregar Assets

1. En el navegador, click derecho en el grupo `ControlWidget`
2. **Add Files to "Runner"...**
3. Selecciona la carpeta `Assets.xcassets` de `ios/ControlWidget/`
4. Asegúrate de agregar solo al target `ControlWidget`

### 6. Configurar App Group

#### Para el Target Runner (App principal):
1. Selecciona el proyecto Runner en el navegador
2. Selecciona el target **Runner**
3. Ve a la pestaña **Signing & Capabilities**
4. Click en **+ Capability**
5. Busca y agrega **App Groups**
6. Click en **+** y agrega: `group.com.caldensmart.sime`

#### Para el Target ControlWidget:
1. Selecciona el target **ControlWidget**
2. Ve a la pestaña **Signing & Capabilities**
3. Click en **+ Capability**
4. Agrega **App Groups**
5. Marca el mismo grupo: `group.com.caldensmart.sime`

### 7. Configurar Info.plist del Widget

El archivo `Info.plist` ya está preparado. Solo verifica que Xcode lo esté usando:
1. Selecciona el target **ControlWidget**
2. Ve a **Build Settings**
3. Busca "Info.plist File"
4. Debe apuntar a `ControlWidget/Info.plist`

### 8. Configurar versión del widget

Asegúrate de que la versión del widget coincida con la app:
1. Selecciona el target **ControlWidget**
2. Ve a la pestaña **General**
3. Configura:
   - **Version**: 1.0.22 (igual que la app)
   - **Build**: 26 (igual que la app)

### 9. Agregar imagen del logo

El widget necesita la imagen del logo de CaldenSmart:
1. Copia la imagen `dragon_foreground.png` de los assets de Android
2. Agrégala a `ControlWidget/Assets.xcassets/`
3. O usa SF Symbols como alternativa

### 10. Compilar y probar

1. Selecciona el esquema **Runner** (no ControlWidget)
2. Selecciona un dispositivo/simulador con iOS 14+
3. Build and Run (⌘R)
4. En el simulador/dispositivo:
   - Mantén presionado en la pantalla de inicio
   - Toca el **+** para agregar widget
   - Busca "CaldenSmart"
   - Agrega el widget

---

## Verificación de funcionamiento

### Checklist de pruebas:
- [ ] El widget aparece en la galería de widgets
- [ ] Se puede agregar a la pantalla de inicio
- [ ] Muestra "CaldenSmart" cuando no está configurado
- [ ] Tocar el widget abre la app
- [ ] Los datos se actualizan cuando la app guarda datos
- [ ] El toggle funciona (si está configurado)

---

## Solución de problemas comunes

### "App Group container not found"
- Verifica que ambos targets tengan el mismo App Group configurado
- Regenera los provisioning profiles en el portal de Apple

### "Widget not updating"
- Verifica que estés usando `UserDefaults(suiteName: "group.com.caldensmart.sime")`
- Llama a `WidgetCenter.shared.reloadAllTimelines()` después de guardar datos

### Widget no aparece en la galería
- Verifica que el target ControlWidget esté incluido en el scheme de build
- Limpia el proyecto (⌘⇧K) y vuelve a compilar

### Errores de signing
- Asegúrate de tener los provisioning profiles correctos para ambos targets
- El App Group debe estar registrado en el Apple Developer Portal

---

## Archivos de referencia

### Equivalencias Android → iOS:
| Android                          | iOS                              |
|----------------------------------|----------------------------------|
| ControlWidgetProvider.kt         | ControlWidget.swift              |
| WidgetConfigActivity.kt          | (Configuración via App)          |
| WidgetUpdateWorker.kt            | TimelineProvider (en widget)     |
| SharedPreferences                | UserDefaults (App Group)         |
| widget_layout.xml                | SwiftUI Views                    |
| HomeWidgetBackgroundIntent       | AppIntent / widgetURL            |

---

## Próximos pasos opcionales

1. **Widget interactivo (iOS 17+)**: Los botones de toggle ya están preparados en `WidgetIntentHandler.swift`
2. **Múltiples tamaños**: Agregar `.systemMedium` y `.systemLarge` a `supportedFamilies`
3. **Live Activity**: Para mostrar estado en la Dynamic Island
4. **Widget con configuración**: Usar `IntentConfiguration` en lugar de `StaticConfiguration`
