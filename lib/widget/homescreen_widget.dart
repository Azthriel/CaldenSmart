import 'package:flutter/material.dart';

/// Esta clase define CÓMO se ve el widget en la pantalla de inicio.
/// Flutter le sacará una "foto" a esto.
class DeviceWidgetCard extends StatelessWidget {
  final String title;
  final String statusText;
  final bool isControl;
  final bool isOn;

  const DeviceWidgetCard({
    super.key,
    required this.title,
    required this.statusText,
    required this.isControl,
    required this.isOn,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos colores fijos
    final bgColor = isOn ? Colors.amber[100] : Colors.white;
    const textColor = Colors.black87;
    final iconColor = isOn ? Colors.amber[700] : Colors.grey;

    // 1. IMPORTANTE: Directionality define la dirección del texto (Izquierda a Derecha)
    return Directionality(
      textDirection: TextDirection.ltr,
      // 2. IMPORTANTE: Material provee el lienzo para dibujar sombras y fondos
      child: Material(
        color: Colors.white,
        child: Container(
          width: 300,
          // height: 200,
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            color: bgColor, // El color de fondo real
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isOn ? Colors.amber : Colors.grey.withValues(alpha: 0.2),
              width: 2,
            ),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withValues(alpha: 0.1),
            //     blurRadius: 10,
            //     offset: const Offset(0, 4),
            //   ),
            // ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fila superior: Icono y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    isControl
                        ? (isOn
                            ? Icons.lightbulb
                            : Icons.lightbulb_outline)
                        : Icons.thermostat,
                    size: 32,
                    color: iconColor,
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor.withValues(alpha: 0.6),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),

              // Fila inferior: Nombre
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
