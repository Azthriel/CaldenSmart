// Modelo para el estado de un evento (Cadena, Riego, Grupo)
class EventoEstado {
  final String status;
  final int pasoActual;
  final int totalPasos;
  final int timestamp;
  final String mensaje;
  final String? error;
  final int? tiempoRestanteEstimado;

  EventoEstado({
    required this.status,
    required this.pasoActual,
    required this.totalPasos,
    required this.timestamp,
    required this.mensaje,
    this.error,
    this.tiempoRestanteEstimado,
  });

  factory EventoEstado.fromJson(Map<String, dynamic> json) {
    return EventoEstado(
      status: json['status'] ?? 'idle',
      pasoActual: json['paso_actual'] ?? 0,
      totalPasos: json['total_pasos'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      mensaje: json['mensaje'] ?? '',
      error: json['error'],
      tiempoRestanteEstimado: json['tiempo_restante_estimado'],
    );
  }

  factory EventoEstado.idle() {
    return EventoEstado(
      status: 'idle',
      pasoActual: 0,
      totalPasos: 0,
      timestamp: 0,
      mensaje: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'paso_actual': pasoActual,
      'total_pasos': totalPasos,
      'timestamp': timestamp,
      'mensaje': mensaje,
      'error': error,
      'tiempo_restante_estimado': tiempoRestanteEstimado,
    };
  }

  // Getters de estado
  bool get isRunning => status == 'running';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasError => status == 'error';
  bool get isIdle => status == 'idle';

  // Extrae los pasos completados del mensaje (fuente de verdad)
  // Formatos soportados:
  // - Cadena: "X pasos completados de Y"
  // - Riego: "Ejecutando paso X de Y" o "Regando - Paso X de Y"
  int get pasosCompletadosFromMensaje {
    if (mensaje.isEmpty) return 0;
    
    // Si está completado, todos los pasos están completados
    if (isCompleted) return totalPasos;
    
    // Si está cancelado, retornar el paso actual
    if (isCancelled) return pasoActual;
    
    try {
      // Formato Riego: "Ejecutando paso X de Y" o "Riego reanudado - Ejecutando paso X de Y"
      var match = RegExp(r'Ejecutando\s+paso\s+(\d+)\s+de\s+(\d+)', caseSensitive: false).firstMatch(mensaje);
      if (match != null && match.groupCount >= 1) {
        // En riego, si está ejecutando el paso X, el progreso es X (no X-1)
        // Porque está EN PROGRESO de ese paso
        final pasoEnEjecucion = int.parse(match.group(1)!);
        return pasoEnEjecucion;
      }
      
      // Formato Riego alternativo: "Regando - Paso X de Y"
      match = RegExp(r'Regando\s*-?\s*Paso\s+(\d+)\s+de\s+(\d+)', caseSensitive: false).firstMatch(mensaje);
      if (match != null && match.groupCount >= 1) {
        final pasoEnEjecucion = int.parse(match.group(1)!);
        return pasoEnEjecucion;
      }
      
      // Formato genérico: "Paso X de Y" (captura cualquier variante)
      match = RegExp(r'[Pp]aso\s+(\d+)\s+de\s+(\d+)').firstMatch(mensaje);
      if (match != null && match.groupCount >= 1) {
        final pasoEnEjecucion = int.parse(match.group(1)!);
        return pasoEnEjecucion;
      }
      
      // Formato Cadena: "X pasos completados de Y"
      match = RegExp(r'(\d+)\s+pasos?\s+completados?').firstMatch(mensaje);
      if (match != null && match.groupCount >= 1) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      // Si falla el parsing, retornar 0
    }
    
    return 0;
  }

  // Cálculo de progreso basado en el mensaje (única fuente de verdad)
  // Soporta dos formatos:
  // - Cadena: "X pasos completados de Y" -> progreso = X / Y
  // - Riego: "Ejecutando paso X de Y" -> progreso = X / Y (porque está EN PROGRESO del paso X)
  double get progresoPortentaje {
    if (totalPasos == 0) return 0.0;
    final pasosCompletados = pasosCompletadosFromMensaje;
    return (pasosCompletados / totalPasos * 100).clamp(0.0, 100.0);
  }

  double get progresoDecimal {
    if (totalPasos == 0) return 0.0;
    final pasosCompletados = pasosCompletadosFromMensaje;
    return (pasosCompletados / totalPasos).clamp(0.0, 1.0);
  }

  EventoEstado copyWith({
    String? status,
    int? pasoActual,
    int? totalPasos,
    int? timestamp,
    String? mensaje,
    String? error,
    int? tiempoRestanteEstimado,
  }) {
    return EventoEstado(
      status: status ?? this.status,
      pasoActual: pasoActual ?? this.pasoActual,
      totalPasos: totalPasos ?? this.totalPasos,
      timestamp: timestamp ?? this.timestamp,
      mensaje: mensaje ?? this.mensaje,
      error: error ?? this.error,
      tiempoRestanteEstimado:
          tiempoRestanteEstimado ?? this.tiempoRestanteEstimado,
    );
  }
}
