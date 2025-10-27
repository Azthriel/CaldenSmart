import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:caldensmart/Global/stored_data.dart';
import 'package:caldensmart/aws/mqtt/mqtt.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caldensmart/secret.dart';

class WifiPage extends ConsumerStatefulWidget {
  const WifiPage({super.key});

  @override
  ConsumerState<WifiPage> createState() => WifiPageState();
}

class WifiPageState extends ConsumerState<WifiPage>
    with WidgetsBindingObserver {
  final Map<String, bool> _expandedStates = {};
  final Set<String> _processingGroups = {};
  final Set<String> _processingCadenas = {};
  final Set<String> _processingRiegos = {};
  StreamSubscription<String>? _cadenaCompletedSubscription;
  StreamSubscription<String>? _riegoCompletedSubscription;

  // Flags para control de riego
  bool _isPumpShuttingDown = false;
  bool _isAutoStarting = false;

  // Mapa para almacenar permisos de WiFi por dispositivo
  Map<String, bool> _wifiPermissions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    setState(() {
      _buildDeviceListFromLoadedData();
    });

    // Verificar el estado de las cadenas al inicializar
    _checkCadenasStatus();

    // Verificar el estado de los riegos al inicializar
    _checkRiegosStatus();

    // Escuchar notificaciones de cadenas completadas
    _setupCadenaCompletedListener();

    // Escuchar notificaciones de riegos completados
    _setupRiegoCompletedListener();

    // Cargar permisos de WiFi
    _loadWifiPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cadenaCompletedSubscription?.cancel();
    _riegoCompletedSubscription?.cancel();
    super.dispose();
  }

  // Configurar listener para cadenas completadas en tiempo real
  void _setupCadenaCompletedListener() {
    _cadenaCompletedSubscription =
        cadenaCompletedController.stream.listen((cadenaName) {
      printLog.i(
          'Recibida notificación de cadena completada en WiFi UI: $cadenaName');
      if (mounted) {
        setState(() {
          _processingCadenas.remove(cadenaName);
        });
        showToast('🎉 ¡Cadena "$cadenaName" completada exitosamente!');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Verificar el estado cuando la app vuelve al foreground
      _checkCadenasStatus();
      _checkRiegosStatus();
      _loadWifiPermissions(); // Recargar permisos de WiFi
    }
  }

  // Verificar el estado de las cadenas en SharedPreferences
  Future<void> _checkCadenasStatus() async {
    List<String> executingCadenas = await getExecutingCadenas(currentUserEmail);
    setState(() {
      _processingCadenas.clear();
      _processingCadenas.addAll(executingCadenas);
    });
    printLog.i('Cadenas en ejecución recuperadas: $executingCadenas');
  }

  // Verificar el estado de los riegos en SharedPreferences
  Future<void> _checkRiegosStatus() async {
    List<String> executingRiegos = await getExecutingRiegos(currentUserEmail);
    setState(() {
      _processingRiegos.clear();
      _processingRiegos.addAll(executingRiegos);
    });
    printLog.i('Riegos en ejecución recuperados: $executingRiegos');
  }

  // Configurar listener para riegos completados en tiempo real
  void _setupRiegoCompletedListener() {
    _riegoCompletedSubscription =
        riegoCompletedController.stream.listen((riegoName) {
      printLog.i(
          'Recibida notificación de riego completado en WiFi UI: $riegoName');
      if (mounted) {
        setState(() {
          _processingRiegos.remove(riegoName);
        });
        showToast('🌱 ¡Rutina de riego "$riegoName" completada exitosamente!');
      }
    });
  }

  // Cargar permisos de WiFi para todos los dispositivos
  Future<void> _loadWifiPermissions() async {
    Map<String, bool> permissions = {};

    // Usar la lista de dispositivos ya construida
    for (var device in todosLosDispositivos) {
      if (device.value.isNotEmpty) {
        try {
          String deviceName = device.value;
          String pc = DeviceManager.getProductCode(deviceName);
          String sn = DeviceManager.extractSerialNumber(deviceName);
          String key = '$pc/$sn';

          bool hasPermission = await checkAdminWifiPermission(deviceName);
          permissions[key] = hasPermission;
        } catch (e) {
          printLog
              .e('Error verificando permisos WiFi para ${device.value}: $e');
          String pc = DeviceManager.getProductCode(device.value);
          String sn = DeviceManager.extractSerialNumber(device.value);
          String key = '$pc/$sn';
          permissions[key] = true; // En caso de error, permitir acceso
        }
      }
    }

    if (mounted) {
      setState(() {
        _wifiPermissions = permissions;
      });
    }
  }

  // Construir la lista de dispositivos desde datos ya cargados
  void _buildDeviceListFromLoadedData() {
    try {
      todosLosDispositivos.clear();

      // Agregar individuales
      for (String device in previusConnections) {
        MapEntry<String, String> newEntry = MapEntry('individual', device);
        bool exists = todosLosDispositivos
            .any((e) => e.key == newEntry.key && e.value == newEntry.value);
        if (!exists) {
          todosLosDispositivos.add(newEntry);
        }
      }

      // Agregar eventos (grupos, cadenas y riego)
      for (var evento in eventosCreados) {
        if (evento['evento'] == 'grupo' ||
            evento['evento'] == 'cadena' ||
            evento['evento'] == 'riego' ||
            evento['evento'] == 'clima' ||
            evento['evento'] == 'disparador' ||
            evento['evento'] == 'horario') {
          MapEntry<String, String> newEntry = MapEntry(
              evento['title'] ?? 'Evento',
              (evento['deviceGroup'] as List<dynamic>).join(','));
          bool exists = todosLosDispositivos
              .any((e) => e.key == newEntry.key && e.value == newEntry.value);
          if (!exists) {
            todosLosDispositivos.add(newEntry);
          }
        }
      }

      printLog.i(
          'Lista de dispositivos construida: ${todosLosDispositivos.length} elementos');

      if (savedOrder.isNotEmpty) {
        List<MapEntry<String, String>> orderedList = [];
        for (var item in savedOrder) {
          MapEntry<String, String> entry =
              MapEntry(item['key']!, item['value']!);
          // Filtrar: solo agregar si existe en la lista actual
          if (todosLosDispositivos
              .any((e) => e.key == entry.key && e.value == entry.value)) {
            orderedList.add(entry);
          }
        }
        // Agrega los dispositivos nuevos que no estaban en el orden guardado
        for (var entry in todosLosDispositivos) {
          bool exists = orderedList
              .any((e) => e.key == entry.key && e.value == entry.value);
          if (!exists) {
            orderedList.add(entry);
          }
        }
        todosLosDispositivos
          ..clear()
          ..addAll(orderedList);
      }

      printLog.i('Lista de dispositivos: $todosLosDispositivos');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      printLog.e('Error construyendo lista de dispositivos: $e');
    }
  }

  //*-Prender y apagar los equipos-*\\
  void toggleState(String deviceName, bool newState) async {
    String deviceSerialNumber = DeviceManager.extractSerialNumber(deviceName);
    String productCode = DeviceManager.getProductCode(deviceName);
    globalDATA['$productCode/$deviceSerialNumber']!['w_status'] = newState;
    saveGlobalData(globalDATA);
    String topic = 'devices_rx/$productCode/$deviceSerialNumber';
    String topic2 = 'devices_tx/$productCode/$deviceSerialNumber';
    String message = jsonEncode({"w_status": newState});
    bool result = await sendMQTTMessageWithPermission(
        deviceName,
        message,
        topic,
        topic2,
        newState
            ? 'Encendió dispositivo desde WiFi'
            : 'Apagó dispositivo desde WiFi');

    if (!result) {
      showToast('No tienes permisos de controlar el equipo');
    }
  }
  //*-Prender y apagar los equipos-*\\

  //*-Borrar equipo de la lista-*\\
  void _confirmDelete(String deviceName, String equipo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: color1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: const BorderSide(color: color4, width: 2.0),
          ),
          title: Text(
            'Confirmación',
            style: GoogleFonts.poppins(color: color0),
          ),
          content: Text(
            '¿Seguro que quieres eliminar el dispositivo de la lista?',
            style: GoogleFonts.poppins(color: color0),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: color0),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Aceptar',
                style: GoogleFonts.poppins(color: color0),
              ),
              onPressed: () {
                // Cerrar el diálogo inmediatamente
                Navigator.of(context).pop();

                // Ejecutar las operaciones de eliminación de forma asíncrona
                _performDelete(deviceName, equipo);
              },
            ),
          ],
        );
      },
    );
  }
  //*-Borrar equipo de la lista-*\\

  //*-Ejecutar operaciones de eliminación-*\\
  Future<void> _performDelete(String deviceName, String equipo) async {
    // Remover de listas locales
    previusConnections.remove(deviceName);
    alexaDevices.removeWhere((d) => d.contains(deviceName));
    todosLosDispositivos.removeWhere((e) => e.value == deviceName);
    await _saveOrder();

    setState(() {});
    final String sn = DeviceManager.extractSerialNumber(deviceName);

    // Actualizar datos remotos - usar marcador fantasma si la lista queda vacía
    bool isListEmpty = previusConnections.isEmpty;
    await putPreviusConnections(currentUserEmail, previusConnections,
        isIntentionalClear: isListEmpty);
    await putDevicesForAlexa(currentUserEmail, previusConnections);
    await removeFromActiveUsers(equipo, sn, currentUserEmail);

    final topic = 'devices_tx/$equipo/$sn';
    unSubToTopicMQTT(topic);
    topicsToSub.remove(topic);
  }
  //*-Ejecutar operaciones de eliminación-*\\

  //*-Determina si el grupo está online-*\\
  bool isGroupOnline(String devicesInGroup) {
    // 1. Convertir el string a lista
    List<String> deviceList = devicesInGroup
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.trim())
        .toList();

    for (String deviceName in deviceList) {
      String equipo = DeviceManager.getProductCode(deviceName);
      String serial = DeviceManager.extractSerialNumber(deviceName);

      Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

      bool online = deviceDATA['cstate'] ?? false;

      if (!online) {
        return false;
      }
    }

    return true;
  }
//*-Determina si el grupo está online-*\\

  //*-Determina si la cadena está online-*\\
  bool isCadenaOnline(List<dynamic> deviceGroup) {
    for (dynamic deviceName in deviceGroup) {
      String deviceStr = deviceName.toString();
      String equipo = DeviceManager.getProductCode(deviceStr);
      String serial = DeviceManager.extractSerialNumber(deviceStr);

      Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

      bool online = deviceDATA['cstate'] ?? false;

      if (!online) {
        return false;
      }
    }

    return true;
  }
//*-Determina si la cadena está online-*\\

  //*-Determina si el grupo está on-*\\
  bool isGroupOn(String devicesInGroup) {
    // 1. Convertir el string a lista
    List<String> deviceList = devicesInGroup
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.trim())
        .toList();

    for (String deviceName in deviceList) {
      if (deviceName.contains('_')) {
        final list = deviceName.split('_');
        String equipo = DeviceManager.getProductCode(list[0]);
        String serial = DeviceManager.extractSerialNumber(list[0]);

        Map<String, dynamic> deviceDATA =
            jsonDecode(globalDATA['$equipo/$serial']?['io${list[1]}']) ?? {};

        bool turnOn = deviceDATA['w_status'] ?? false;

        if (!turnOn) {
          return false;
        }
      } else {
        String equipo = DeviceManager.getProductCode(deviceName);
        String serial = DeviceManager.extractSerialNumber(deviceName);

        Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

        bool turnOn = deviceDATA['w_status'] ?? false;

        if (!turnOn) {
          return false;
        }
      }
    }

    return true;
  }
  //*-Determina si el grupo está on-*\\

  //*-Determina si puedo controlar el grupo-*\\
  bool canControlGroup(String devicesInGroup) {
    // 1. Convertir el string a lista
    List<String> deviceList = devicesInGroup
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.trim())
        .toList();

    for (String deviceName in deviceList) {
      String equipo = DeviceManager.getProductCode(deviceName);
      String serial = DeviceManager.extractSerialNumber(deviceName);

      Map<String, dynamic> deviceDATA = globalDATA['$equipo/$serial'] ?? {};

      List<dynamic> admins = deviceDATA['secondary_admin'] ?? [];

      bool owner = deviceDATA['owner'] == currentUserEmail ||
          admins.contains(currentUserEmail) ||
          deviceDATA['owner'] == '' ||
          deviceDATA['owner'] == null;
      bool canUseWifi = _wifiPermissions['$equipo/$serial'] ?? true;

      if (!owner || !canUseWifi) {
        return false;
      }
    }

    return true;
  }
  //*-Determina si puedo controlar el grupo-*\\

  //*-Controlar el grupo-*\\
  void controlGroup(String email, bool state, String grupo) async {
    // Verificar si el grupo ya está siendo procesado
    if (_processingGroups.contains(grupo)) {
      showToast(
          '⏳ El grupo "$grupo" ya se está procesando, aguarde un momento...');
      return;
    }

    // Agregar el grupo al Set de procesamiento
    _processingGroups.add(grupo);

    String url = controlGruposAPI;
    Uri uri = Uri.parse(url);

    String bd = jsonEncode(
      {
        'email': email,
        'on': state,
        'grupo': grupo,
        'app': app,
      },
    );

    printLog.i('Body: $bd');

    try {
      var response = await http.post(uri, body: bd);

      printLog.i('Response status: ${response.statusCode}');
      printLog.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Respuesta exitosa - todos los dispositivos se controlaron
        final responseData = jsonDecode(response.body);

        printLog.i('Grupo controlado exitosamente');
        showToast(
            '¡Perfecto! Todos los equipos del grupo se ${state ? 'encendieron' : 'apagaron'} correctamente 🎉');

        // Log adicional con detalles
        if (responseData['exitosos'] != null &&
            responseData['total_dispositivos'] != null) {
          printLog.i(
              'Dispositivos procesados: ${responseData['exitosos']}/${responseData['total_dispositivos']}');
        }
      } else if (response.statusCode == 207) {
        // Multi-Status - algunos dispositivos fallaron
        final responseData = jsonDecode(response.body);

        printLog.i('Algunos dispositivos no pudieron ser controlados');

        final exitosos = responseData['exitosos'] ?? 0;
        final fallidos = responseData['fallidos'] ?? 0;
        final dispositivosOffline = responseData['dispositivos_offline'] ?? [];

        // Mostrar mensaje detallado al usuario
        String message = '⚠️ Acción parcialmente completada:\n\n';
        message +=
            '✅ $exitosos equipos se ${state ? 'encendieron' : 'apagaron'} correctamente\n';

        if (fallidos > 0) {
          message += '❌ $fallidos equipos no disponibles en este momento';
          if (dispositivosOffline.isNotEmpty) {
            // Mostrar nombres de dispositivos offline (máximo 3 para no saturar)
            final deviceNames = dispositivosOffline.take(3).map((device) {
              return nicknamesMap[device] ?? device;
            }).join(', ');
            message += '\n\n📱 Equipos sin conexión: $deviceNames';
            if (dispositivosOffline.length > 3) {
              message += ' y ${dispositivosOffline.length - 3} más...';
            }
          }
        }

        showToast(message);
      } else if (response.statusCode == 400) {
        // Error de validación
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['error'] ?? 'Error de validación';

        printLog.e('Error de validación: $errorMessage');
        showToast(
            '🚫 Ups, algo no está bien configurado. Por favor intenta nuevamente');
      } else if (response.statusCode == 404) {
        // Grupo no encontrado
        printLog.e('Grupo no encontrado');
        showToast(
            '🔍 No encontramos el grupo "$grupo". Verifica que tengas permisos para controlarlo');
      } else {
        // Otros errores del servidor
        printLog.e('Error del servidor: ${response.statusCode}');
        showToast(
            '⚡ Hubo un problema en nuestros servidores. Por favor intenta en unos momentos');
      }
    } catch (e) {
      // Error de conexión o parsing
      printLog.e('Error de conexión al controlar el grupo: $e');
      showToast(
          '📶 Sin conexión a internet. Verifica tu red y vuelve a intentar');
    } finally {
      // Remover el grupo del Set de procesamiento
      _processingGroups.remove(grupo);
    }
  }
  //*-Controlar el grupo-*\\

  //*- Controlar la cadena -*\\
  void controlarCadena(String name) async {
    // Verificar si la cadena ya está siendo procesada usando SharedPreferences
    bool isAlreadyExecuting = await isCadenaExecuting(name, currentUserEmail);
    if (isAlreadyExecuting) {
      showToast(
          '⏳ La cadena "$name" ya se está ejecutando, aguarde un momento...');
      return;
    }

    // Agregar la cadena al Set de procesamiento y actualizar UI
    setState(() {
      _processingCadenas.add(name);
    });

    String bd = jsonEncode({'nombreEvento': name, 'email': currentUserEmail});

    printLog.i('Controlling cadena with body: $bd', color: 'rosa');

    try {
      showToast('🔄 Iniciando cadena "$name"...');

      final response = await http.post(
        Uri.parse(controlCadenaAPI),
        body: bd,
      );

      if (response.statusCode == 200) {
        printLog.i('Cadena iniciada exitosamente');
        showToast('✅ Cadena "$name" iniciada exitosamente');

        // Marcar la cadena como en ejecución en SharedPreferences
        await setCadenaExecuting(name, currentUserEmail);

        // Ya no usamos timer, la cadena se desmarcará cuando llegue la notificación
        printLog
            .i('Cadena "$name" marcada como en ejecución en SharedPreferences');
      } else if (response.statusCode == 404) {
        printLog.e('Cadena no encontrada: ${response.statusCode}');
        showToast(
            '🔍 No se encontró la cadena "$name". Verifica que existe y tienes permisos.');
        // Remover inmediatamente si hay error
        setState(() {
          _processingCadenas.remove(name);
        });
      } else if (response.statusCode == 400) {
        printLog.e('Error de validación: ${response.statusCode}');
        showToast(
            '🚫 Error en los datos de la cadena. Por favor intenta nuevamente.');
        // Remover inmediatamente si hay error
        setState(() {
          _processingCadenas.remove(name);
        });
      } else {
        printLog.e('Error al controlar la cadena: ${response.statusCode}');
        showToast('⚡ Error del servidor. Intenta nuevamente en unos momentos.');
        // Remover inmediatamente si hay error
        setState(() {
          _processingCadenas.remove(name);
        });
      }
    } catch (e) {
      printLog.e('Error de conexión al controlar la cadena: $e');
      showToast(
          '📶 Sin conexión a internet. Verifica tu red y vuelve a intentar.');
      // Remover inmediatamente si hay error de conexión
      setState(() {
        _processingCadenas.remove(name);
      });
    }
  }
  //*- Controlar la cadena -*\\

  //*- Guardar orden de equipos -*\\
  Future<void> _saveOrder() async {
    List<Map<String, String>> orderedDevices = todosLosDispositivos
        .map((e) => {'key': e.key, 'value': e.value})
        .toList();
    await saveWifiOrderDevices(orderedDevices, currentUserEmail);
  }
  //*- Guardar orden de equipos -*\\

  void activarRutinaRiego(Map<String, dynamic> eventoRiego) async {
    String name = eventoRiego['title'] ?? 'Rutina de Riego';

    // Verificar si la rutina ya está siendo procesada usando SharedPreferences
    bool isAlreadyExecuting = await isRiegoExecuting(name, currentUserEmail);
    if (isAlreadyExecuting) {
      showToast(
          '⏳ La rutina de riego "$name" ya se está ejecutando, aguarde un momento...');
      return;
    }

    // Agregar la rutina al Set de procesamiento y actualizar UI
    setState(() {
      _processingRiegos.add(name);
    });

    String bd = jsonEncode({'nombreEvento': name, 'email': currentUserEmail});

    printLog.i('Controlling riego with body: $bd', color: 'rosa');

    try {
      showToast('🌱 Iniciando rutina de riego "$name"...');

      final response = await http.post(
        Uri.parse(controlRiegoAPI),
        body: bd,
      );

      if (response.statusCode == 200) {
        printLog.i('Rutina de riego iniciada exitosamente');
        showToast('✅ Rutina de riego "$name" iniciada exitosamente');

        // Marcar la rutina como en ejecución en SharedPreferences
        await setRiegoExecuting(name, currentUserEmail);

        // Ya no usamos timer, la rutina se desmarcará cuando llegue la notificación
        printLog.i(
            'Rutina de riego "$name" marcada como en ejecución en SharedPreferences');
      } else if (response.statusCode == 404) {
        printLog.e('Rutina de riego no encontrada: ${response.statusCode}');
        showToast(
            '🔍 No se encontró la rutina de riego "$name". Verifica que existe y tienes permisos.');
        // Remover inmediatamente si hay error
        setState(() {
          _processingRiegos.remove(name);
        });
      } else if (response.statusCode == 400) {
        printLog.e('Error de validación: ${response.statusCode}');
        showToast(
            '🚫 Error en los datos de la rutina. Por favor intenta nuevamente.');
        // Remover inmediatamente si hay error
        setState(() {
          _processingRiegos.remove(name);
        });
      } else {
        printLog
            .e('Error al controlar la rutina de riego: ${response.statusCode}');
        showToast('⚡ Error del servidor. Intenta nuevamente en unos momentos.');
        // Remover inmediatamente si hay error
        setState(() {
          _processingRiegos.remove(name);
        });
      }
    } catch (e) {
      printLog.e('Error de conexión al controlar la rutina de riego: $e');
      showToast(
          '📶 Sin conexión a internet. Verifica tu red y vuelve a intentar.');
      // Remover inmediatamente si hay error de conexión
      setState(() {
        _processingRiegos.remove(name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispositiosIndividuales = todosLosDispositivos
        .where((device) => device.key == 'individual')
        .toList();

    final eventos = todosLosDispositivos
        .where((device) => device.key != 'individual')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        backgroundColor: color0,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Mis equipos registrados',
            style: GoogleFonts.poppins(color: color0),
          ),
          backgroundColor: color1,
          bottom: TabBar(
            labelColor: color0,
            unselectedLabelColor: color0.withValues(alpha: 0.6),
            indicatorColor: color4,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(HugeIcons.strokeRoundedSmartPhone01, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Individuales (${dispositiosIndividuales.length})',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(HugeIcons.strokeRoundedUserGroup, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Eventos (${eventos.length})',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Container(
          padding: const EdgeInsets.only(bottom: 100.0),
          color: color0,
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildDeviceList(dispositiosIndividuales, 'individual',
                  shrinkWrap: false),
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildDeviceList(eventos, 'grupos', shrinkWrap: true),
                    const SizedBox(height: 10),
                    _buildConfigButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color1.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/escenas');
            if (result == true && mounted) {
              _buildDeviceListFromLoadedData();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color0.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    HugeIcons.strokeRoundedAdd01,
                    color: color0,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Configurar evento',
                  style: GoogleFonts.poppins(
                    color: color0,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(
      List<MapEntry<String, String>> deviceList, String tipo, {bool shrinkWrap = false}) {
    if (deviceList.where((e) => e.value.trim().isNotEmpty).isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tipo == 'individual'
                    ? HugeIcons.strokeRoundedSmartPhone01
                    : HugeIcons.strokeRoundedUserGroup,
                size: 80,
                color: color1.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 20),
              Text(
                tipo == 'individual'
                    ? 'No hay equipos individuales conectados'
                    : 'No hay eventos creados',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tipo == 'individual'
                    ? 'Conecta tus primeros dispositivos para comenzar'
                    : 'Crea eventos para controlar múltiples dispositivos',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: color1.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
            shrinkWrap: shrinkWrap,
      itemCount: deviceList.length,
      footer: SizedBox(height: shrinkWrap ? 10 : 120),
      onReorder: (int oldIndex, int newIndex) async {
        if (newIndex > oldIndex) newIndex -= 1;

        // Ordenar solo la sublista correspondiente
        List<MapEntry<String, String>> sublist = List.from(deviceList);
        final item = sublist.removeAt(oldIndex);
        sublist.insert(newIndex, item);

        // Reconstruir todosLosDispositivos manteniendo el orden de ambas sublistas
        List<MapEntry<String, String>> individuales =
            todosLosDispositivos.where((e) => e.key == 'individual').toList();
        List<MapEntry<String, String>> grupos =
            todosLosDispositivos.where((e) => e.key != 'individual').toList();

        if (tipo == 'individual') {
          individuales = sublist;
        } else {
          grupos = sublist;
        }

        setState(() {
          todosLosDispositivos
            ..clear()
            ..addAll(individuales)
            ..addAll(grupos);
        });

        await _saveOrder();
      },
      itemBuilder: (BuildContext context, int index) {
        final String grupo = deviceList[index].key;
        final String deviceName = deviceList[index].value;

        final bool esGrupo = grupo != 'individual';

        // Escuchar cambios en todos los datos globales para detectar cambios en extensiones de riego
        final allGlobalData = ref.watch(globalDataProvider);

        final topicData =
            allGlobalData['${DeviceManager.getProductCode(deviceName)}/'
                    '${DeviceManager.extractSerialNumber(deviceName)}'] ??
                {};

        if (!esGrupo) {
          String productCode = DeviceManager.getProductCode(deviceName);
          String serialNumber = DeviceManager.extractSerialNumber(deviceName);

          globalDATA
              .putIfAbsent('$productCode/$serialNumber', () => {})
              .addAll(topicData);
          saveGlobalData(globalDATA);
          Map<String, dynamic> deviceDATA =
              globalDATA['$productCode/$serialNumber'] ?? {};
          // printLog.i(deviceDATA, 'cyan');

          // printLog.i(
          //     "Las keys del equipo ${deviceDATA.keys}", 'rojo');

          bool online = deviceDATA['cstate'] ?? false;

          List<dynamic> admins = deviceDATA['secondary_admin'] ?? [];

          bool owner = deviceDATA['owner'] == currentUserEmail ||
              admins.contains(currentUserEmail) ||
              deviceDATA['owner'] == '' ||
              deviceDATA['owner'] == null;

          // Verificar restricciones de WiFi para administradores secundarios
          bool canUseWifi =
              _wifiPermissions['$productCode/$serialNumber'] ?? true;
          bool isRestrictedAdmin = admins.contains(currentUserEmail) &&
              deviceDATA['owner'] != currentUserEmail &&
              !canUseWifi;

          // Ocultar extensiones de riego (solo mostrar el maestro)
          String? riegoMaster = deviceDATA['riegoMaster'];
          if (riegoMaster != null &&
              riegoMaster.isNotEmpty &&
              riegoMaster != '' &&
              riegoMaster.trim().isNotEmpty) {
            return SizedBox.shrink(
              key: ValueKey('extension_$deviceName'),
            );
          }

          try {
            switch (productCode) {
              case '015773_IOT':
                int ppmCO = deviceDATA['ppmco'] ?? 0;
                int ppmCH4 = deviceDATA['ppmch4'] ?? 0;
                bool alert = deviceDATA['alert'] == 1;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: ListTile(
                                title: online
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PPM CO: $ppmCO',
                                            style: GoogleFonts.poppins(
                                              color: color0,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'CH4 LIE: ${(ppmCH4 / 500).round()}%',
                                            style: GoogleFonts.poppins(
                                              color: color0,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                alert ? 'PELIGRO' : 'AIRE PURO',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              alert
                                                  ? const Icon(
                                                      HugeIcons
                                                          .strokeRoundedAlert02,
                                                      color: color4,
                                                    )
                                                  : const Icon(
                                                      HugeIcons
                                                          .strokeRoundedLeaf01,
                                                      color: Colors.green,
                                                    ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'El equipo debe estar\nconectado para su uso',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: 8.0, bottom: 8.0),
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _confirmDelete(deviceName, productCode);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              case '022000_IOT':
                bool estado = deviceDATA['w_status'] ?? false;
                bool heaterOn = deviceDATA['f_status'] ?? false;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: online
                                          ? Row(
                                              children: [
                                                estado
                                                    ? Row(
                                                        children: [
                                                          if (heaterOn) ...[
                                                            Text(
                                                              'Calentando',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .amber[800],
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            Icon(
                                                              HugeIcons
                                                                  .strokeRoundedFlash,
                                                              size: 15,
                                                              color: Colors
                                                                  .amber[800],
                                                            ),
                                                          ] else ...[
                                                            Text(
                                                              'Encendido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      )
                                                    : Text(
                                                        'Apagado',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color4,
                                                                fontSize: 15),
                                                      ),
                                                const SizedBox(width: 5),
                                                owner
                                                    ? Switch(
                                                        activeThumbColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        activeTrackColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveThumbColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveTrackColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        value: estado,
                                                        onChanged: (newValue) {
                                                          toggleState(
                                                              deviceName,
                                                              newValue);
                                                          setState(() {
                                                            estado = newValue;
                                                          });
                                                        },
                                                      )
                                                    : const SizedBox(
                                                        height: 0, width: 0),
                                              ],
                                            )
                                          : Text(
                                              'El equipo debe estar\nconectado para su uso',
                                              style: GoogleFonts.poppins(
                                                color: color3,
                                                fontSize: 15,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              case '027000_IOT':
                bool estado = deviceDATA['w_status'] ?? false;
                bool heaterOn = deviceDATA['f_status'] ?? false;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: online
                                          ? Row(
                                              children: [
                                                estado
                                                    ? Row(
                                                        children: [
                                                          if (heaterOn) ...[
                                                            Text(
                                                              'Calentando',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .amber[800],
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            Icon(
                                                              HugeIcons
                                                                  .strokeRoundedFire,
                                                              size: 15,
                                                              color: Colors
                                                                  .amber[800],
                                                            ),
                                                          ] else ...[
                                                            Text(
                                                              'Encendido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      )
                                                    : Text(
                                                        'Apagado',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: color4,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                const SizedBox(width: 5),
                                                Switch(
                                                    activeThumbColor:
                                                        const Color(0xFF9C9D98),
                                                    activeTrackColor:
                                                        const Color(0xFFB2B5AE),
                                                    inactiveThumbColor:
                                                        const Color(0xFFB2B5AE),
                                                    inactiveTrackColor:
                                                        const Color(0xFF9C9D98),
                                                    value: estado,
                                                    onChanged: online
                                                        ? (newValue) {
                                                            toggleState(
                                                                deviceName,
                                                                newValue);
                                                            setState(
                                                              () {
                                                                estado =
                                                                    newValue;
                                                                if (!newValue) {
                                                                  heaterOn =
                                                                      false;
                                                                }
                                                              },
                                                            );
                                                          }
                                                        : null),
                                              ],
                                            )
                                          : Text(
                                              'El equipo debe estar\nconectado para su uso',
                                              style: GoogleFonts.poppins(
                                                color: color3,
                                                fontSize: 15,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              case '020010_IOT':

                // Verificar si es un equipo de riego
                bool isRiegoActive = deviceDATA['riegoActive'] == true;
                if (isRiegoActive) {
                  return _buildRiegoCard(deviceName, productCode, serialNumber,
                      deviceDATA, online, owner);
                }

                // Código original para equipos normales
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : online
                                ? Column(
                                    children: [
                                      ...(deviceDATA.keys
                                              .where((key) =>
                                                  key.startsWith('io') &&
                                                  RegExp(r'^io\d+$')
                                                      .hasMatch(key))
                                              .where((ioKey) =>
                                                  deviceDATA[ioKey] != null)
                                              .toList()
                                            ..sort((a, b) {
                                              int indexA =
                                                  int.parse(a.substring(2));
                                              int indexB =
                                                  int.parse(b.substring(2));
                                              return indexA.compareTo(indexB);
                                            }))
                                          .map((ioKey) {
                                        // Extraer el índice del ioKey (ejemplo: "io0" -> 0)
                                        int i = int.parse(ioKey.substring(2));
                                        Map<String, dynamic> equipo =
                                            jsonDecode(deviceDATA[ioKey]);
                                        printLog.i(
                                          'Voy a realizar el cambio: $equipo',
                                        );
                                        String tipoWifi =
                                            equipo['pinType'].toString() == '0'
                                                ? 'Salida'
                                                : 'Entrada';
                                        bool estadoWifi = equipo['w_status'];
                                        String comunWifi =
                                            (equipo['r_state'] ?? '0')
                                                .toString();
                                        bool entradaWifi =
                                            tipoWifi == 'Entrada';
                                        return ListTile(
                                          title: Row(
                                            children: [
                                              Text(
                                                nicknamesMap[
                                                        '${deviceName}_$i'] ??
                                                    '$tipoWifi $i',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                            ],
                                          ),
                                          subtitle: Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                entradaWifi
                                                    ? estadoWifi
                                                        ? comunWifi == '1'
                                                            ? Text(
                                                                'Cerrado',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                            : Text(
                                                                'Abierto',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color4,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                        : comunWifi == '1'
                                                            ? Text(
                                                                'Abierto',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color4,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                            : Text(
                                                                'Cerrado',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                    : estadoWifi
                                                        ? Text(
                                                            'Encendido',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color:
                                                                  Colors.green,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          )
                                                        : Text(
                                                            'Apagado',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color4,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                              ],
                                            ),
                                          ),
                                          trailing: owner
                                              ? entradaWifi
                                                  ? estadoWifi
                                                      ? comunWifi == '1'
                                                          ? const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: Color(
                                                                0xff9b9b9b,
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: color4,
                                                            )
                                                      : comunWifi == '1'
                                                          ? const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: color4,
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: Color(
                                                                0xff9b9b9b,
                                                              ),
                                                            )
                                                  : Switch(
                                                      activeThumbColor:
                                                          const Color(
                                                        0xFF9C9D98,
                                                      ),
                                                      activeTrackColor:
                                                          const Color(
                                                        0xFFB2B5AE,
                                                      ),
                                                      inactiveThumbColor:
                                                          const Color(
                                                        0xFFB2B5AE,
                                                      ),
                                                      inactiveTrackColor:
                                                          const Color(
                                                        0xFF9C9D98,
                                                      ),
                                                      value: estadoWifi,
                                                      onChanged: (value) async {
                                                        String topic =
                                                            'devices_rx/$productCode/$serialNumber';
                                                        String topic2 =
                                                            'devices_tx/$productCode/$serialNumber';
                                                        String message =
                                                            jsonEncode({
                                                          'pinType': tipoWifi ==
                                                                  'Salida'
                                                              ? 0
                                                              : 1,
                                                          'index': i,
                                                          'w_status': value,
                                                          'r_state': comunWifi,
                                                        });
                                                        bool result =
                                                            await sendMQTTMessageWithPermission(
                                                                deviceName,
                                                                message,
                                                                topic,
                                                                topic2,
                                                                value
                                                                    ? 'Encendió dispositivo desde WiFi'
                                                                    : 'Apagó dispositivo desde WiFi');
                                                        if (result) {
                                                          setState(() {
                                                            estadoWifi = value;
                                                          });
                                                          globalDATA
                                                              .putIfAbsent(
                                                                  '$productCode/$serialNumber',
                                                                  () => {})
                                                              .addAll({
                                                            'io$i': message
                                                          });
                                                          saveGlobalData(
                                                              globalDATA);
                                                        } else {
                                                          showToast(
                                                            'No tienes permisos para realizar esta acción en este momento',
                                                          );
                                                        }
                                                      },
                                                    )
                                              : null,
                                        );
                                      }),
                                    ],
                                  )
                                : const SizedBox(height: 0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 16.0),
                                child: !online
                                    ? Text(
                                        'El equipo debe estar\nconectado para su uso',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      )
                                    : const SizedBox(height: 0),
                              ),
                            ),
                            if (!online)
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 8.0, bottom: 8.0),
                                child: IconButton(
                                  icon: const Icon(
                                    HugeIcons.strokeRoundedDelete02,
                                    color: color0,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _confirmDelete(deviceName, productCode);
                                  },
                                ),
                              ),
                          ],
                        ),
                        if (online)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  right: 16.0, bottom: 8.0),
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _confirmDelete(deviceName, productCode);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              case '027313_IOT':

                // Verificar si es un equipo de riego
                bool isRiegoActive = deviceDATA['riegoActive'] == true;
                if (isRiegoActive) {
                  return _buildRiegoCard(deviceName, productCode, serialNumber,
                      deviceDATA, online, owner);
                }

                // Código original para equipos normales (cerraduras)
                bool estado = deviceDATA['w_status'] ?? false;
                bool hasEntry = deviceDATA['hasEntry'] ?? false;
                String hardv = deviceDATA['HardwareVersion'] ?? '000000A';
                // bool isNC = deviceDATA['isNC'] ?? false;

                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        if (Versioner.isPrevious(hardv, '241220A')) ...{
                          isRestrictedAdmin
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 5.0),
                                        child: Text(
                                          'El dueño del equipo restringió su uso por wifi.',
                                          style: GoogleFonts.poppins(
                                            color: color3,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 5.0),
                                            child: online
                                                ? Row(
                                                    children: [
                                                      estado
                                                          ? Text(
                                                              'ENCENDIDO',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                              ),
                                                            )
                                                          : Text(
                                                              'APAGADO',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: color4,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                      const SizedBox(width: 5),
                                                      owner
                                                          ? Switch(
                                                              activeThumbColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              activeTrackColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveThumbColor:
                                                                  const Color(
                                                                      0xFFB2B5AE),
                                                              inactiveTrackColor:
                                                                  const Color(
                                                                      0xFF9C9D98),
                                                              value: estado,
                                                              onChanged:
                                                                  (newValue) {
                                                                toggleState(
                                                                    deviceName,
                                                                    newValue);
                                                                setState(() {
                                                                  estado =
                                                                      newValue;
                                                                });
                                                              },
                                                            )
                                                          : const SizedBox(
                                                              height: 0,
                                                              width: 0),
                                                    ],
                                                  )
                                                : Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 8.0,
                                                            bottom: 8.0),
                                                    child: Text(
                                                      'El equipo debe estar\nconectado para su uso',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color3,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        if (!online)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0, bottom: 8.0),
                                            child: IconButton(
                                              icon: const Icon(
                                                HugeIcons.strokeRoundedDelete02,
                                                color: color0,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _confirmDelete(
                                                    deviceName, productCode);
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (online)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: 16.0, bottom: 8.0),
                                          child: IconButton(
                                            icon: const Icon(
                                              HugeIcons.strokeRoundedDelete02,
                                              color: color0,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _confirmDelete(
                                                  deviceName, productCode);
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                        } else ...{
                          isRestrictedAdmin
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 5.0),
                                        child: Text(
                                          'El dueño del equipo restringió su uso por wifi.',
                                          style: GoogleFonts.poppins(
                                            color: color3,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : online
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // POSICIÓN 0: Salida con switch
                                        if (deviceDATA['io0'] == null) ...[
                                          const SizedBox
                                              .shrink() // No mostrar nada si no hay datos
                                        ] else ...[
                                          if (deviceDATA['io0'] == null) ...[
                                            const SizedBox
                                                .shrink() // No mostrar nada si no hay datos
                                          ] else ...[
                                            if (hasEntry) ...[
                                              ListTile(
                                                title: Text(
                                                  nicknamesMap[
                                                          '${deviceName}_0'] ??
                                                      'Salida 0',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                trailing: owner
                                                    ? Switch(
                                                        activeThumbColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        activeTrackColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveThumbColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveTrackColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        value: (jsonDecode(
                                                                    deviceDATA[
                                                                        'io0'])[
                                                                'w_status'] ??
                                                            false),
                                                        onChanged:
                                                            (value) async {
                                                          final deviceSerialNumber =
                                                              DeviceManager
                                                                  .extractSerialNumber(
                                                                      deviceName);
                                                          final productCode =
                                                              DeviceManager
                                                                  .getProductCode(
                                                                      deviceName);
                                                          final topicRx =
                                                              'devices_rx/$productCode/$deviceSerialNumber';
                                                          final topicTx =
                                                              'devices_tx/$productCode/$deviceSerialNumber';
                                                          final Map<String,
                                                                  dynamic>
                                                              io0Map =
                                                              jsonDecode(
                                                                  deviceDATA[
                                                                      'io0']);
                                                          final rState =
                                                              (io0Map['r_state'] ??
                                                                      '0')
                                                                  .toString();
                                                          final message =
                                                              jsonEncode({
                                                            'pinType': 0,
                                                            'index': 0,
                                                            'w_status': value,
                                                            'r_state': rState,
                                                          });
                                                          bool result =
                                                              await sendMQTTMessageWithPermission(
                                                                  deviceName,
                                                                  message,
                                                                  topicRx,
                                                                  topicTx,
                                                                  value
                                                                      ? 'Encendió dispositivo desde WiFi'
                                                                      : 'Apagó dispositivo desde WiFi');

                                                          if (result) {
                                                            setState(() {});
                                                            globalDATA
                                                                .putIfAbsent(
                                                                    '$productCode/$deviceSerialNumber',
                                                                    () => {})
                                                                .addAll({
                                                              'io0': message
                                                            });
                                                            saveGlobalData(
                                                                globalDATA);
                                                          } else {
                                                            showToast(
                                                              'No tienes permisos para realizar esta acción en este momento',
                                                            );
                                                          }
                                                        },
                                                      )
                                                    : null,
                                              ),
                                            ] else ...[
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16.0,
                                                  vertical: 5.0,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    online
                                                        ? Row(
                                                            children: [
                                                              (jsonDecode(deviceDATA[
                                                                              'io0'])[
                                                                          'w_status'] ??
                                                                      false)
                                                                  ? Text(
                                                                      'ENCENDIDO',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color: Colors
                                                                            .green,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    )
                                                                  : Text(
                                                                      'APAGADO',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        color:
                                                                            color4,
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                              const SizedBox(
                                                                  width: 5),
                                                              owner
                                                                  ? Switch(
                                                                      activeThumbColor:
                                                                          const Color(
                                                                              0xFF9C9D98),
                                                                      activeTrackColor:
                                                                          const Color(
                                                                              0xFFB2B5AE),
                                                                      inactiveThumbColor:
                                                                          const Color(
                                                                              0xFFB2B5AE),
                                                                      inactiveTrackColor:
                                                                          const Color(
                                                                              0xFF9C9D98),
                                                                      value: (jsonDecode(
                                                                              deviceDATA['io0'])['w_status'] ??
                                                                          false),
                                                                      onChanged:
                                                                          (value) async {
                                                                        final topicRx =
                                                                            'devices_rx/$productCode/$serialNumber';
                                                                        final topicTx =
                                                                            'devices_tx/$productCode/$serialNumber';
                                                                        final Map<String,
                                                                                dynamic>
                                                                            io0Map =
                                                                            jsonDecode(deviceDATA['io0']);
                                                                        final rState =
                                                                            (io0Map['r_state'] ?? '0').toString();
                                                                        final message =
                                                                            jsonEncode({
                                                                          'pinType':
                                                                              0,
                                                                          'index':
                                                                              0,
                                                                          'w_status':
                                                                              value,
                                                                          'r_state':
                                                                              rState,
                                                                        });
                                                                        bool result = await sendMQTTMessageWithPermission(
                                                                            deviceName,
                                                                            message,
                                                                            topicRx,
                                                                            topicTx,
                                                                            value
                                                                                ? 'Encendió dispositivo desde WiFi'
                                                                                : 'Apagó dispositivo desde WiFi');
                                                                        if (result) {
                                                                          setState(
                                                                              () {});
                                                                          globalDATA.putIfAbsent('$productCode/$serialNumber', () => {}).addAll({
                                                                            'io0':
                                                                                message
                                                                          });
                                                                          saveGlobalData(
                                                                              globalDATA);
                                                                        } else {
                                                                          showToast(
                                                                            'No tienes permisos para realizar esta acción en este momento',
                                                                          );
                                                                        }
                                                                      },
                                                                    )
                                                                  : const SizedBox(
                                                                      height: 0,
                                                                      width: 0),
                                                            ],
                                                          )
                                                        : Text(
                                                            'El equipo debe estar\nconectado para su uso',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color3,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                  ],
                                                ),
                                              )
                                            ],
                                          ],
                                        ],
                                        // POSICIÓN 1: Entrada, solo si hasEntry == true
                                        if (hasEntry) ...[
                                          if (deviceDATA['io1'] == null) ...[
                                            const SizedBox
                                                .shrink() // No mostrar nada si no hay datos
                                          ] else ...[
                                            ListTile(
                                              title: Text(
                                                nicknamesMap[
                                                        '${deviceName}_1'] ??
                                                    'Entrada 1',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              trailing: Icon(
                                                Icons.new_releases,
                                                color: (() {
                                                  final io1 = jsonDecode(
                                                      deviceDATA['io1']);
                                                  final bool wStatus =
                                                      io1['w_status'] ?? false;
                                                  final String rState =
                                                      (io1['r_state'] ?? '0')
                                                          .toString();
                                                  final bool mismatch =
                                                      (rState == '0' &&
                                                              wStatus) ||
                                                          (rState == '1' &&
                                                              !wStatus);
                                                  return mismatch
                                                      ? color4
                                                      : const Color(0xFF9C9D98);
                                                })(),
                                              ),
                                            ),
                                          ]
                                        ]
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16.0, bottom: 16.0),
                                            child: Text(
                                              'El equipo debe estar\nconectado para su uso',
                                              style: GoogleFonts.poppins(
                                                color: color3,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 8.0, bottom: 8.0),
                                          child: IconButton(
                                            icon: const Icon(
                                              HugeIcons.strokeRoundedDelete02,
                                              color: color0,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _confirmDelete(
                                                  deviceName, productCode);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                          if (online)
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _confirmDelete(deviceName, productCode);
                                },
                              ),
                            ),
                        }
                      ],
                    ),
                  ),
                );
              case '050217_IOT':
                bool estado = deviceDATA['w_status'] ?? false;
                bool heaterOn = deviceDATA['f_status'] ?? false;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: online
                                          ? Row(
                                              children: [
                                                estado
                                                    ? Row(
                                                        children: [
                                                          if (heaterOn) ...[
                                                            Text(
                                                              'Calentando',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .amber[800],
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons.water_drop,
                                                              size: 15,
                                                              color: Colors
                                                                  .amber[800],
                                                            ),
                                                          ] else ...[
                                                            Text(
                                                              'Encendido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      )
                                                    : Text(
                                                        'Apagado',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color4,
                                                                fontSize: 15),
                                                      ),
                                                const SizedBox(width: 5),
                                                owner
                                                    ? Switch(
                                                        activeThumbColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        activeTrackColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveThumbColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveTrackColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        value: estado,
                                                        onChanged: (newValue) {
                                                          toggleState(
                                                              deviceName,
                                                              newValue);
                                                          setState(() {
                                                            estado = newValue;
                                                          });
                                                        },
                                                      )
                                                    : const SizedBox(
                                                        height: 0, width: 0),
                                              ],
                                            )
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0, bottom: 8.0),
                                              child: Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color3,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              case '020020_IOT':
                // Verificar si es un equipo de riego
                bool isRiegoActive = deviceDATA['riegoActive'] == true;
                if (isRiegoActive) {
                  return _buildRiegoCard(deviceName, productCode, serialNumber,
                      deviceDATA, online, owner);
                }

                // Código original para equipos normales
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : online
                                ? Column(
                                    children: [
                                      ...(deviceDATA.keys
                                              .where((key) =>
                                                  key.startsWith('io') &&
                                                  RegExp(r'^io\d+$')
                                                      .hasMatch(key))
                                              .where((ioKey) =>
                                                  deviceDATA[ioKey] != null)
                                              .toList()
                                            ..sort((a, b) {
                                              int indexA =
                                                  int.parse(a.substring(2));
                                              int indexB =
                                                  int.parse(b.substring(2));
                                              return indexA.compareTo(indexB);
                                            }))
                                          .map((ioKey) {
                                        // Extraer el índice del ioKey (ejemplo: "io0" -> 0)
                                        int i = int.parse(ioKey.substring(2));
                                        Map<String, dynamic> equipo =
                                            jsonDecode(deviceDATA[ioKey]);
                                        printLog.i(
                                          'Voy a realizar el cambio: $equipo',
                                        );
                                        String tipoWifi =
                                            equipo['pinType'].toString() == '0'
                                                ? 'Salida'
                                                : 'Entrada';
                                        bool estadoWifi = equipo['w_status'];
                                        String comunWifi =
                                            (equipo['r_state'] ?? '0')
                                                .toString();
                                        bool entradaWifi =
                                            tipoWifi == 'Entrada';
                                        return ListTile(
                                          title: Row(
                                            children: [
                                              Text(
                                                nicknamesMap[
                                                        '${deviceName}_$i'] ??
                                                    '$tipoWifi $i',
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                            ],
                                          ),
                                          subtitle: Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                entradaWifi
                                                    ? estadoWifi
                                                        ? comunWifi == '1'
                                                            ? Text(
                                                                'Cerrado',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                            : Text(
                                                                'Abierto',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color4,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                        : comunWifi == '1'
                                                            ? Text(
                                                                'Abierto',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: color4,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                            : Text(
                                                                'Cerrado',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                    : estadoWifi
                                                        ? Text(
                                                            'Encendido',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color:
                                                                  Colors.green,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          )
                                                        : Text(
                                                            'Apagado',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: color4,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                              ],
                                            ),
                                          ),
                                          trailing: owner
                                              ? entradaWifi
                                                  ? estadoWifi
                                                      ? comunWifi == '1'
                                                          ? const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: Color(
                                                                0xff9b9b9b,
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: color4,
                                                            )
                                                      : comunWifi == '1'
                                                          ? const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: color4,
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .new_releases,
                                                              color: Color(
                                                                0xff9b9b9b,
                                                              ),
                                                            )
                                                  : Switch(
                                                      activeThumbColor:
                                                          const Color(
                                                        0xFF9C9D98,
                                                      ),
                                                      activeTrackColor:
                                                          const Color(
                                                        0xFFB2B5AE,
                                                      ),
                                                      inactiveThumbColor:
                                                          const Color(
                                                        0xFFB2B5AE,
                                                      ),
                                                      inactiveTrackColor:
                                                          const Color(
                                                        0xFF9C9D98,
                                                      ),
                                                      value: estadoWifi,
                                                      onChanged: (value) async {
                                                        String topic =
                                                            'devices_rx/$productCode/$serialNumber';
                                                        String topic2 =
                                                            'devices_tx/$productCode/$serialNumber';
                                                        String message =
                                                            jsonEncode({
                                                          'pinType': tipoWifi ==
                                                                  'Salida'
                                                              ? 0
                                                              : 1,
                                                          'index': i,
                                                          'w_status': value,
                                                          'r_state': comunWifi,
                                                        });
                                                        bool result =
                                                            await sendMQTTMessageWithPermission(
                                                                deviceName,
                                                                message,
                                                                topic,
                                                                topic2,
                                                                value
                                                                    ? 'Encendió dispositivo desde WiFi'
                                                                    : 'Apagó dispositivo desde WiFi');
                                                        if (result) {
                                                          setState(() {
                                                            estadoWifi = value;
                                                          });
                                                          globalDATA
                                                              .putIfAbsent(
                                                                  '$productCode/$serialNumber',
                                                                  () => {})
                                                              .addAll({
                                                            'io$i': message
                                                          });
                                                          saveGlobalData(
                                                              globalDATA);
                                                        } else {
                                                          showToast(
                                                            'No tienes permisos para realizar esta acción en este momento',
                                                          );
                                                        }
                                                      },
                                                    )
                                              : null,
                                        );
                                      }),
                                    ],
                                  )
                                : const SizedBox(height: 0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 16.0),
                                child: !online
                                    ? Text(
                                        'El equipo debe estar\nconectado para su uso',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      )
                                    : const SizedBox(height: 0),
                              ),
                            ),
                            if (!online)
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 8.0, bottom: 8.0),
                                child: IconButton(
                                  icon: const Icon(
                                    HugeIcons.strokeRoundedDelete02,
                                    color: color0,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _confirmDelete(deviceName, productCode);
                                  },
                                ),
                              ),
                          ],
                        ),
                        if (online)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  right: 16.0, bottom: 8.0),
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _confirmDelete(deviceName, productCode);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              case '041220_IOT':
                bool estado = deviceDATA['w_status'] ?? false;
                bool heaterOn = deviceDATA['f_status'] ?? false;

                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 5.0),
                                        child: online
                                            ? Row(
                                                children: [
                                                  estado
                                                      ? Row(
                                                          children: [
                                                            if (heaterOn) ...[
                                                              Text(
                                                                'Calentando',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                          .amber[
                                                                      800],
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                              Icon(
                                                                HugeIcons
                                                                    .strokeRoundedFlash,
                                                                size: 15,
                                                                color: Colors
                                                                    .amber[800],
                                                              ),
                                                            ] else ...[
                                                              Text(
                                                                'Encendido',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        )
                                                      : Text(
                                                          'Apagado',
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: color4,
                                                                  fontSize: 15),
                                                        ),
                                                  const SizedBox(width: 5),
                                                  owner
                                                      ? Switch(
                                                          activeThumbColor:
                                                              const Color(
                                                                  0xFF9C9D98),
                                                          activeTrackColor:
                                                              const Color(
                                                                  0xFFB2B5AE),
                                                          inactiveThumbColor:
                                                              const Color(
                                                                  0xFFB2B5AE),
                                                          inactiveTrackColor:
                                                              const Color(
                                                                  0xFF9C9D98),
                                                          value: estado,
                                                          onChanged:
                                                              (newValue) {
                                                            toggleState(
                                                                deviceName,
                                                                newValue);
                                                            setState(() {
                                                              estado = newValue;
                                                            });
                                                          },
                                                        )
                                                      : const SizedBox(
                                                          height: 0, width: 0),
                                                ],
                                              )
                                            : Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color3,
                                                  fontSize: 15,
                                                ),
                                              )),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              case '028000_IOT':
                bool estado = deviceDATA['w_status'] ?? false;
                bool heaterOn = deviceDATA['f_status'] ?? false;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 16.0),
                                        child: online
                                            ? Row(
                                                children: [
                                                  estado
                                                      ? Row(
                                                          children: [
                                                            if (heaterOn) ...[
                                                              Text(
                                                                'Enfriando',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .lightBlueAccent
                                                                      .shade400,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                              Icon(
                                                                HugeIcons
                                                                    .strokeRoundedSnow,
                                                                size: 15,
                                                                color: Colors
                                                                    .lightBlueAccent
                                                                    .shade400,
                                                              ),
                                                            ] else ...[
                                                              Text(
                                                                'Encendido',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        )
                                                      : Text(
                                                          'Apagado',
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: color4,
                                                                  fontSize: 15),
                                                        ),
                                                  const SizedBox(width: 5),
                                                  owner
                                                      ? Switch(
                                                          activeThumbColor:
                                                              const Color(
                                                                  0xFF9C9D98),
                                                          activeTrackColor:
                                                              const Color(
                                                                  0xFFB2B5AE),
                                                          inactiveThumbColor:
                                                              const Color(
                                                                  0xFFB2B5AE),
                                                          inactiveTrackColor:
                                                              const Color(
                                                                  0xFF9C9D98),
                                                          value: estado,
                                                          onChanged:
                                                              (newValue) {
                                                            toggleState(
                                                                deviceName,
                                                                newValue);
                                                            setState(() {
                                                              estado = newValue;
                                                            });
                                                          },
                                                        )
                                                      : const SizedBox(
                                                          height: 0, width: 0),
                                                ],
                                              )
                                            : Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color3,
                                                  fontSize: 15,
                                                ),
                                              )),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              case '023430_IOT':
                String temp = deviceDATA['actualTemp'].toString();
                bool alertMaxFlag = deviceDATA['alert_maxflag'] ?? false;
                bool alertMinFlag = deviceDATA['alert_minflag'] ?? false;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: online
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Temperatura: $temp °C',
                                                  style: GoogleFonts.poppins(
                                                    color: color0,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Alerta máxima:',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color0,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    alertMaxFlag
                                                        ? const Icon(
                                                            HugeIcons
                                                                .strokeRoundedAlert02,
                                                            color: color4,
                                                          )
                                                        : const Icon(
                                                            HugeIcons
                                                                .strokeRoundedTemperature,
                                                            color: Colors.green,
                                                          ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Alerta mínima:',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: color0,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    alertMinFlag
                                                        ? const Icon(
                                                            HugeIcons
                                                                .strokeRoundedAlert02,
                                                            color: color4,
                                                          )
                                                        : const Icon(
                                                            HugeIcons
                                                                .strokeRoundedTemperature,
                                                            color: Colors.green,
                                                          ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0, bottom: 8.0),
                                              child: Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color3,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              case '027345_IOT':
                bool estado = deviceDATA['w_status'] ?? false;
                bool heaterOn = deviceDATA['f_status'] ?? false;
                return Card(
                  key: ValueKey(deviceName),
                  color: color1,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  elevation: 2,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      iconColor: color4,
                      collapsedIconColor: color4,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: Text(
                                  nicknamesMap[deviceName] ?? deviceName,
                                  style: GoogleFonts.poppins(
                                    color: color0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    online ? '● CONECTADO' : '● DESCONECTADO',
                                    style: GoogleFonts.poppins(
                                      color: online ? Colors.green : color3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    online ? Icons.cloud : Icons.cloud_off,
                                    color: online ? Colors.green : color3,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: <Widget>[
                        isRestrictedAdmin
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: Text(
                                        'El dueño del equipo restringió su uso por wifi.',
                                        style: GoogleFonts.poppins(
                                          color: color3,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 5.0),
                                      child: online
                                          ? Row(
                                              children: [
                                                estado
                                                    ? Row(
                                                        children: [
                                                          if (heaterOn) ...[
                                                            Text(
                                                              'Calentando',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .amber[800],
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons.water_drop,
                                                              size: 15,
                                                              color: Colors
                                                                  .amber[800],
                                                            ),
                                                          ] else ...[
                                                            Text(
                                                              'Encendido',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      )
                                                    : Text(
                                                        'Apagado',
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: color4,
                                                                fontSize: 15),
                                                      ),
                                                const SizedBox(width: 5),
                                                owner
                                                    ? Switch(
                                                        activeThumbColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        activeTrackColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveThumbColor:
                                                            const Color(
                                                                0xFFB2B5AE),
                                                        inactiveTrackColor:
                                                            const Color(
                                                                0xFF9C9D98),
                                                        value: estado,
                                                        onChanged: (newValue) {
                                                          toggleState(
                                                              deviceName,
                                                              newValue);
                                                          setState(() {
                                                            estado = newValue;
                                                          });
                                                        },
                                                      )
                                                    : const SizedBox(
                                                        height: 0, width: 0),
                                              ],
                                            )
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0, bottom: 8.0),
                                              child: Text(
                                                'El equipo debe estar\nconectado para su uso',
                                                style: GoogleFonts.poppins(
                                                  color: color3,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, bottom: 8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        HugeIcons.strokeRoundedDelete02,
                                        color: color0,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _confirmDelete(deviceName, productCode);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );

              default:
                return Container(
                  key: ValueKey(deviceName),
                );
            }
          } catch (e) {
            printLog.e('Error al procesar el equipo $deviceName: $e');
            return Card(
              key: ValueKey('${deviceName}_error'),
              color: color1,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              elevation: 2,
              child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(
                          nicknamesMap[deviceName] ?? deviceName,
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Por favor, verifica la conexión y actualice su equipo.',
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  )),
            );
          }
        } else {
          // Detectar si es una cadena
          final eventoCadena = eventosCreados
                  .where(
                    (evento) =>
                        evento['evento'] == 'cadena' &&
                        evento['title'] == grupo &&
                        (evento['deviceGroup'] as List<dynamic>).join(',') ==
                            deviceName,
                  )
                  .isNotEmpty
              ? eventosCreados.firstWhere(
                  (evento) =>
                      evento['evento'] == 'cadena' &&
                      evento['title'] == grupo &&
                      (evento['deviceGroup'] as List<dynamic>).join(',') ==
                          deviceName,
                )
              : null;

          // Detectar si es un evento de riego
          final eventoRiego = eventosCreados
                  .where(
                    (evento) =>
                        evento['evento'] == 'riego' &&
                        evento['title'] == grupo &&
                        (evento['deviceGroup'] as List<dynamic>).join(',') ==
                            deviceName,
                  )
                  .isNotEmpty
              ? eventosCreados.firstWhere(
                  (evento) =>
                      evento['evento'] == 'riego' &&
                      evento['title'] == grupo &&
                      (evento['deviceGroup'] as List<dynamic>).join(',') ==
                          deviceName,
                )
              : null;

          // Detectar si es un evento de clima
          final eventoClima = eventosCreados
                  .where(
                    (evento) =>
                        evento['evento'] == 'clima' &&
                        evento['title'] == grupo &&
                        (evento['deviceGroup'] as List<dynamic>).join(',') ==
                            deviceName,
                  )
                  .isNotEmpty
              ? eventosCreados.firstWhere(
                  (evento) =>
                      evento['evento'] == 'clima' &&
                      evento['title'] == grupo &&
                      (evento['deviceGroup'] as List<dynamic>).join(',') ==
                          deviceName,
                )
              : null;

          // Detectar si es un evento de disparador
          final eventoDisparador = eventosCreados
                  .where(
                    (evento) =>
                        evento['evento'] == 'disparador' &&
                        evento['title'] == grupo &&
                        (evento['deviceGroup'] as List<dynamic>).join(',') ==
                            deviceName,
                  )
                  .isNotEmpty
              ? eventosCreados.firstWhere(
                  (evento) =>
                      evento['evento'] == 'disparador' &&
                      evento['title'] == grupo &&
                      (evento['deviceGroup'] as List<dynamic>).join(',') ==
                          deviceName,
                )
              : null;

          // Detectar si es un evento de horario
          final eventoHorario = eventosCreados
                  .where(
                    (evento) =>
                        evento['evento'] == 'horario' &&
                        evento['title'] == grupo &&
                        (evento['deviceGroup'] as List<dynamic>).join(',') ==
                            deviceName,
                  )
                  .isNotEmpty
              ? eventosCreados.firstWhere(
                  (evento) =>
                      evento['evento'] == 'horario' &&
                      evento['title'] == grupo &&
                      (evento['deviceGroup'] as List<dynamic>).join(',') ==
                          deviceName,
                )
              : null;

          if (eventoCadena != null) {
            try {
              // Verificar si todos los equipos de la cadena están online
              bool cadenaOnline =
                  isCadenaOnline(eventoCadena['deviceGroup'] as List<dynamic>);

              return Card(
                key: ValueKey('cadena_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    iconColor: color4,
                    collapsedIconColor: color4,
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _expandedStates[deviceName] = expanded;
                      });
                    },
                    title: Row(
                      children: [
                        const Icon(HugeIcons.strokeRoundedLink01,
                            color: color4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grupo,
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color0.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CADENA',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!cadenaOnline) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.wifi_off,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Todos los equipos deben estar conectados para activar la cadena',
                                        style: GoogleFonts.poppins(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Botón para activar la cadena
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: (cadenaOnline &&
                                        !_processingCadenas.contains(grupo))
                                    ? () => controlarCadena(grupo)
                                    : null,
                                icon: _processingCadenas.contains(grupo)
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  color0),
                                        ),
                                      )
                                    : Icon(
                                        HugeIcons.strokeRoundedPlay,
                                        color:
                                            cadenaOnline ? color0 : Colors.grey,
                                        size: 20,
                                      ),
                                label: Text(
                                  _processingCadenas.contains(grupo)
                                      ? 'Ejecutando Cadena...'
                                      : 'Activar Cadena',
                                  style: GoogleFonts.poppins(
                                    color: (cadenaOnline ||
                                            _processingCadenas.contains(grupo))
                                        ? color0
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (cadenaOnline ||
                                          _processingCadenas.contains(grupo))
                                      ? color4
                                      : Colors.grey.withValues(alpha: 0.3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: (cadenaOnline ||
                                          _processingCadenas.contains(grupo))
                                      ? 3
                                      : 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Pasos de la cadena:',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...((eventoCadena['pasos'] ?? []) as List<dynamic>)
                                .asMap()
                                .entries
                                .map((entry) {
                              final paso = entry.value;
                              final idx = entry.key + 1;

                              // Si paso es String, intentar parsearlo para compatibilidad
                              dynamic pasoProcessed = paso;
                              if (paso is String) {
                                try {
                                  pasoProcessed = parseMapString(paso);
                                } catch (e) {
                                  printLog
                                      .e('Error parseando paso de cadena: $e');
                                  return const SizedBox.shrink();
                                }
                              }

                              // Validar que los campos requeridos existan
                              if (pasoProcessed == null ||
                                  pasoProcessed['devices'] == null ||
                                  pasoProcessed['actions'] == null) {
                                printLog.i(
                                    'Paso de cadena incompleto, saltando...');
                                return const SizedBox.shrink();
                              }

                              final devices =
                                  pasoProcessed['devices'] as List<dynamic>;
                              if (pasoProcessed['actions'].runtimeType ==
                                  String) {
                                pasoProcessed['actions'] =
                                    parseMapString(pasoProcessed['actions']);
                              }
                              final actions = pasoProcessed['actions'];
                              final stepDelay = pasoProcessed['stepDelay'];
                              final stepDelayUnit =
                                  pasoProcessed['stepDelayUnit'] as String? ??
                                      'seg';

                              // Formatear tiempo
                              String delayText = 'Instantáneo';
                              if (stepDelay != null) {
                                if (stepDelay is Duration) {
                                  int totalSeconds = stepDelay.inSeconds;
                                  if (totalSeconds > 0) {
                                    int minutes = (totalSeconds / 60).floor();

                                    if (stepDelayUnit == 'min') {
                                      delayText =
                                          '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
                                    } else {
                                      delayText =
                                          '$totalSeconds ${totalSeconds == 1 ? 'segundo' : 'segundos'}';
                                    }
                                  }
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color0.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: color4.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            color: color4,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$idx',
                                              style: GoogleFonts.poppins(
                                                color: color1,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Paso $idx',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: color4,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                color0.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            delayText,
                                            style: GoogleFonts.poppins(
                                              color: color0,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...devices.map((device) {
                                      final deviceStr = device.toString();
                                      if (actions[deviceStr].runtimeType ==
                                          String) {
                                        actions[deviceStr] =
                                            actions[deviceStr] == 'true';
                                      }
                                      final action =
                                          actions[deviceStr] ?? false;

                                      // Formatear nombre del dispositivo igual que en grupos
                                      String displayName = '';
                                      if (deviceStr.contains('_')) {
                                        final parts = deviceStr.split('_');
                                        displayName = nicknamesMap[deviceStr] ??
                                            '${nicknamesMap[parts[0]] ?? parts[0]} salida ${parts[1]}';
                                      } else {
                                        displayName = nicknamesMap[deviceStr] ??
                                            deviceStr;
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 32),
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                style: GoogleFonts.poppins(
                                                  color: color0,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: action
                                                    ? Colors.green
                                                        .withValues(alpha: 0.2)
                                                    : Colors.red
                                                        .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                action ? 'ON' : 'OFF',
                                                style: GoogleFonts.poppins(
                                                  color: action
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                  ],
                                ),
                              );
                            }),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                ),
                                tooltip: 'Eliminar evento de cadena',
                                onPressed: () {
                                  showAlertDialog(
                                    context,
                                    false,
                                    const Text(
                                      '¿Eliminar este evento de cadena?',
                                      style: TextStyle(color: color0),
                                    ),
                                    const Text(
                                      'Esta acción no se puede deshacer.',
                                      style: TextStyle(color: color0),
                                    ),
                                    <Widget>[
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Cancelar'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Confirmar'),
                                        onPressed: () {
                                          setState(() {
                                            eventosCreados.removeAt(index);
                                            putEventos(currentUserEmail,
                                                eventosCreados);
                                            printLog.d(grupo, color: 'naranja');
                                            deleteEventoControlPorCadena(
                                                currentUserEmail, grupo);
                                            todosLosDispositivos.removeWhere(
                                                (entry) => entry.key == grupo);
                                          });
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              printLog.e('Error al procesar la cadena $grupo: $e');
              return Card(
                key: ValueKey('cadena_error_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ListTile(
                    title: Text(
                      'Error al cargar la cadena $grupo',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Por favor, elimine el evento y vuelva a crearlo.',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          // Manejar evento de riego
          if (eventoRiego != null) {
            try {
              // Verificar si el equipo creador del evento de riego está online
              String creatorDevice = eventoRiego['creator'] ?? '';
              String productCode = DeviceManager.getProductCode(creatorDevice);
              String serialNumber =
                  DeviceManager.extractSerialNumber(creatorDevice);

              Map<String, dynamic> deviceDATA =
                  globalDATA['$productCode/$serialNumber'] ?? {};
              bool riegoOnline = deviceDATA['cstate'] ?? false;

              return Card(
                key: ValueKey('riego_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    iconColor: color4,
                    collapsedIconColor: color4,
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _expandedStates[deviceName] = expanded;
                      });
                    },
                    title: Row(
                      children: [
                        const Icon(HugeIcons.strokeRoundedPlant03,
                            color: color4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grupo,
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color0.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RIEGO',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!riegoOnline) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.wifi_off,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'El equipo de riego debe estar conectado para activar la rutina',
                                        style: GoogleFonts.poppins(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Botón para activar la rutina de riego
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: (riegoOnline &&
                                        !_processingRiegos.contains(grupo))
                                    ? () => activarRutinaRiego(eventoRiego)
                                    : null,
                                icon: _processingRiegos.contains(grupo)
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  color0),
                                        ),
                                      )
                                    : Icon(
                                        HugeIcons.strokeRoundedPlay,
                                        color:
                                            riegoOnline ? color0 : Colors.grey,
                                        size: 20,
                                      ),
                                label: Text(
                                  _processingRiegos.contains(grupo)
                                      ? 'Ejecutando Rutina...'
                                      : 'Activar Rutina de Riego',
                                  style: GoogleFonts.poppins(
                                    color: (riegoOnline ||
                                            _processingRiegos.contains(grupo))
                                        ? color0
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (riegoOnline ||
                                          _processingRiegos.contains(grupo))
                                      ? color4
                                      : Colors.grey.withValues(alpha: 0.3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: (riegoOnline ||
                                          _processingRiegos.contains(grupo))
                                      ? 3
                                      : 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Zonas de riego:',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...((eventoRiego['pasos'] ?? []) as List<dynamic>)
                                .asMap()
                                .entries
                                .map((entry) {
                              final paso = entry.value;
                              final idx = entry.key + 1;

                              // Validar que los campos requeridos existan
                              if (paso == null ||
                                  paso['device'] == null ||
                                  paso['duration'] == null) {
                                return const SizedBox.shrink();
                              }

                              final device = paso['device'].toString();
                              final duration = paso['duration'];

                              // Formatear nombre del dispositivo
                              String displayName = '';
                              if (device.contains('_')) {
                                final parts = device.split('_');
                                displayName = nicknamesMap[device] ??
                                    '${nicknamesMap[parts[0]] ?? parts[0]} Zona ${parts[1]}';
                              } else {
                                displayName = nicknamesMap[device] ?? device;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color0.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: color4.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: color4,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$idx',
                                          style: GoogleFonts.poppins(
                                            color: color1,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blue.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$duration min',
                                        style: GoogleFonts.poppins(
                                          color: Colors.blue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                             Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                ),
                                tooltip: 'Eliminar rutina de riego',
                                onPressed: () {
                                  printLog.d('sexoooooooo $grupo');
                                  showAlertDialog(
                                    context,
                                    false,
                                    const Text(
                                      '¿Eliminar esta rutina de riego?',
                                      style: TextStyle(color: color0),
                                    ),
                                    const Text(
                                      'Esta acción no se puede deshacer.',
                                      style: TextStyle(color: color0),
                                    ),
                                    <Widget>[
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Cancelar'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Confirmar'),
                                        onPressed: () {
                                          setState(() {
                                            printLog.d(
                                                'se viene $eventosCreados',
                                                color: 'naranja');
                                            printLog.d(
                                                'se viene $todosLosDispositivos',
                                                color: 'naranja');
                                            eventosCreados.removeWhere(
                                                (evento) =>
                                                    evento['title'] == grupo &&
                                                    evento['evento'] ==
                                                        'riego');
                                            putEventos(currentUserEmail,
                                                eventosCreados);
                                            deleteEventoControlDeRiego(
                                                currentUserEmail, grupo);
                                            todosLosDispositivos.removeWhere(
                                                (entry) => entry.key == grupo);
                                            printLog.d(
                                                'se viene $eventosCreados',
                                                color: 'rosa');
                                            printLog.d(
                                                'se viene $todosLosDispositivos',
                                                color: 'rosa');
                                          });
                                          _saveOrder();
                                          Navigator.of(context).pop();
                                          showToast('Rutina eliminada');
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              printLog.e('Error al procesar el evento de riego $grupo: $e');
              return Card(
                key: ValueKey('riego_error_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ListTile(
                    title: Text(
                      'Error al cargar el evento de riego $grupo',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Por favor, elimine el evento y vuelva a crearlo.',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          // Manejar evento de clima
          if (eventoClima != null) {
            try {
              String condition = eventoClima['condition'] ?? '';

              // Obtener las acciones de los dispositivos
              Map<String, dynamic> devicesActions =
                  Map<String, dynamic>.from(eventoClima['deviceActions'] ?? {});

              // Crear lista de nombres de dispositivos
              String devicesInGroup = deviceName;
              List<String> deviceList = devicesInGroup
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .split(',');
              List<String> climaNicksList = [];
              for (String equipo in deviceList) {
                String displayName = '';
                if (equipo.contains('_')) {
                  final parts = equipo.split('_');
                  displayName = nicknamesMap[equipo.trim()] ??
                      '${parts[0]} salida ${parts[1]}';
                } else {
                  displayName = nicknamesMap[equipo.trim()] ?? equipo.trim();
                }
                climaNicksList.add(displayName);
              }

              // Determinar icono según la condición
              IconData climaIcon;
              switch (condition) {
                case 'Lluvia':
                  climaIcon = HugeIcons.strokeRoundedCloudAngledRain;
                  break;
                case 'Nublado':
                  climaIcon = HugeIcons.strokeRoundedSunCloud02;
                  break;
                case 'Viento Fuerte':
                  climaIcon = HugeIcons.strokeRoundedFastWind;
                  break;
                case 'Soleado':
                  climaIcon = HugeIcons.strokeRoundedSun03;
                  break;
                default:
                  climaIcon = HugeIcons.strokeRoundedCloudSnow;
              }

              return Card(
                key: ValueKey('clima_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    iconColor: color4,
                    collapsedIconColor: color4,
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _expandedStates[deviceName] = expanded;
                      });
                    },
                    title: Row(
                      children: [
                        const Icon(HugeIcons.strokeRoundedCloudAngledRainZap,
                            color: color4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grupo,
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color0.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CLIMA',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Información de condición climática (simplificado)
                            Row(
                              children: [
                                Icon(climaIcon, color: color4, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Condición',
                                        style: GoogleFonts.poppins(
                                          color: color0.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        condition,
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Dispositivos afectados
                            Text(
                              'Dispositivos afectados:',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...climaNicksList.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              String deviceNick = entry.value;
                              final equipo = deviceList[entry.key].trim();

                              // Verificar si es un evento buscando en eventosCreados
                              bool isEvento = false;
                              bool isCadena = false;
                              bool isRiego = false;
                              bool isGrupo = false;

                              final eventoEncontrado =
                                  eventosCreados.firstWhere(
                                (evento) => evento['title'] == equipo,
                                orElse: () => <String, dynamic>{},
                              );

                              if (eventoEncontrado.isNotEmpty) {
                                // Es un evento (grupo, cadena o riego)
                                final eventoType =
                                    eventoEncontrado['evento'] as String;
                                deviceNick = equipo;
                                isEvento = true;
                                isCadena = eventoType == 'cadena';
                                isRiego = eventoType == 'riego';
                                isGrupo = eventoType == 'grupo';
                              }

                              // Definir acción, ícono y color según el tipo
                              String actionText = '';
                              IconData actionIcon =
                                  HugeIcons.strokeRoundedSettings02;
                              Color actionColor = color0;

                              if (isEvento) {
                                // Manejo especial para eventos
                                if (isCadena) {
                                  actionText = 'Se ejecutará';
                                  actionIcon =
                                      HugeIcons.strokeRoundedPlayCircle;
                                  actionColor = Colors.orange;
                                } else if (isRiego) {
                                  actionText = 'Se ejecutará';
                                  actionIcon = HugeIcons.strokeRoundedLeaf01;
                                  actionColor = Colors.blue;
                                } else if (isGrupo) {
                                  // Es un grupo
                                  final action =
                                      devicesActions['$equipo:grupo'] ?? false;
                                  actionText = action ? "Encenderá" : "Apagará";
                                  actionIcon = action
                                      ? HugeIcons.strokeRoundedPlug01
                                      : HugeIcons.strokeRoundedPlugSocket;
                                  actionColor =
                                      action ? Colors.green : Colors.red;
                                } else {
                                  // Evento desconocido
                                  actionText = 'Se ejecutará';
                                  actionIcon =
                                      HugeIcons.strokeRoundedSettings02;
                                  actionColor = color4;
                                }
                              } else {
                                // Es un dispositivo individual
                                final action = devicesActions[equipo] ?? false;
                                actionText = action ? "Encenderá" : "Apagará";
                                actionIcon = action
                                    ? HugeIcons.strokeRoundedPlug01
                                    : HugeIcons.strokeRoundedPlugSocket;
                                actionColor =
                                    action ? Colors.green : Colors.red;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: color4,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$idx',
                                          style: GoogleFonts.poppins(
                                            color: color1,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        deviceNick,
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      actionIcon,
                                      color: actionColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      actionText,
                                      style: GoogleFonts.poppins(
                                        color: actionColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                ),
                                tooltip: 'Eliminar evento de clima',
                                onPressed: () {
                                  showAlertDialog(
                                    context,
                                    false,
                                    const Text(
                                      '¿Eliminar este evento clima?',
                                      style: TextStyle(color: color0),
                                    ),
                                    const Text(
                                      'Esta acción no se puede deshacer.',
                                      style: TextStyle(color: color0),
                                    ),
                                    <Widget>[
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Cancelar'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Confirmar'),
                                        onPressed: () {
                                          setState(() {
                                            eventosCreados.removeAt(index);
                                            putEventos(currentUserEmail,
                                                eventosCreados);
                                            printLog.d(grupo, color: 'naranja');
                                            deleteEventoControlPorGrupos(
                                                currentUserEmail, grupo);
                                            todosLosDispositivos.removeWhere(
                                                (entry) => entry.key == grupo);
                                          });
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              printLog.e('Error al procesar el evento de clima $grupo: $e');
              return Card(
                key: ValueKey('clima_error_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ListTile(
                    title: Text(
                      'Error al cargar el evento de clima $grupo',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Por favor, elimine el evento y vuelva a crearlo.',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          // Manejar evento de disparador
          if (eventoDisparador != null) {
            try {
              List<dynamic> deviceGroup = eventoDisparador['deviceGroup'] ?? [];

              // Obtener las acciones de los dispositivos ejecutores
              Map<String, dynamic> devicesActions = Map<String, dynamic>.from(
                  eventoDisparador['deviceActions'] ?? {});

              // Crear lista de nombres de dispositivos
              String devicesInGroup = deviceName;
              List<String> deviceList = devicesInGroup
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .split(',');
              List<String> disparadorNicksList = [];
              for (String equipo in deviceList) {
                String displayName = '';
                if (equipo.contains('_')) {
                  final parts = equipo.split('_');
                  displayName = nicknamesMap[equipo.trim()] ??
                      '${parts[0]} salida ${parts[1]}';
                } else {
                  displayName = nicknamesMap[equipo.trim()] ?? equipo.trim();
                }
                disparadorNicksList.add(displayName);
              }

              // El primer dispositivo es el activador, el resto son ejecutores
              String activador = disparadorNicksList.isNotEmpty
                  ? disparadorNicksList.first
                  : '';
              List<String> ejecutores = disparadorNicksList.length > 1
                  ? disparadorNicksList.sublist(1)
                  : [];

              // Verificar si el activador es un termómetro
              bool isTermometro = deviceGroup.isNotEmpty &&
                  deviceGroup.first.toString().contains('Termometro');

              // Obtener estado de alerta y termómetro
              String? estadoAlerta =
                  eventoDisparador['estadoAlerta']?.toString();
              String? estadoTermometro =
                  eventoDisparador['estadoTermometro']?.toString();

              return Card(
                key: ValueKey('disparador_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    iconColor: color4,
                    collapsedIconColor: color4,
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _expandedStates[deviceName] = expanded;
                      });
                    },
                    title: Row(
                      children: [
                        const Icon(HugeIcons.strokeRoundedPlayCircle,
                            color: color4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grupo,
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color0.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'DISPARADOR',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sección Activador
                            Row(
                              children: [
                                const Icon(
                                    HugeIcons.strokeRoundedTouchInteraction02,
                                    color: color4,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'ACTIVADOR',
                                  style: GoogleFonts.poppins(
                                    color: color4,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (activador.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isTermometro
                                          ? HugeIcons.strokeRoundedThermometer
                                          : HugeIcons.strokeRoundedAlert01,
                                      color: color4,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        activador,
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Condiciones del disparador
                            if (estadoAlerta != null)
                              Card(
                                color: Colors.transparent,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: (estadoAlerta == "1"
                                            ? Colors.orange
                                            : Colors.blueGrey)
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        estadoAlerta == "1"
                                            ? HugeIcons.strokeRoundedAlert02
                                            : HugeIcons
                                                .strokeRoundedCheckmarkCircle02,
                                        color: estadoAlerta == "1"
                                            ? Colors.orange
                                            : Colors.blueGrey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                  text:
                                                      "El evento se accionará cuando el activador esté en "),
                                              TextSpan(
                                                text: estadoAlerta == "1"
                                                    ? "ALERTA"
                                                    : "REPOSO",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  color: estadoAlerta == "1"
                                                      ? Colors.orange
                                                      : Colors.blueGrey,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const TextSpan(text: "."),
                                            ],
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color:
                                                color0.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (isTermometro && estadoTermometro != null)
                              Card(
                                color: Colors.transparent,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: (estadoTermometro == "1"
                                            ? Colors.red
                                            : Colors.lightBlue)
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.thermostat,
                                        color: estadoTermometro == "1"
                                            ? Colors.red
                                            : Colors.lightBlue,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                  text:
                                                      "Condición usada: Temperatura "),
                                              TextSpan(
                                                text: estadoTermometro == "1"
                                                    ? "MÁXIMA"
                                                    : "MÍNIMA",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  color: estadoTermometro == "1"
                                                      ? Colors.red
                                                      : Colors.lightBlue,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const TextSpan(
                                                  text: " del termómetro."),
                                            ],
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color:
                                                color0.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Sección Ejecutores
                            if (ejecutores.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(HugeIcons.strokeRoundedSettings02,
                                      color: color4, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'EJECUTORES',
                                    style: GoogleFonts.poppins(
                                      color: color4,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...ejecutores.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                String ejecutorName = entry.value;
                                // +1 porque el índice 0 es el activador
                                final equipoOriginal =
                                    deviceList[entry.key + 1].trim();

                                // Verificar si es un evento buscando en eventosCreados
                                bool isEvento = false;
                                bool isCadena = false;
                                bool isRiego = false;
                                bool isGrupo = false;

                                final eventoEncontrado =
                                    eventosCreados.firstWhere(
                                  (evento) => evento['title'] == equipoOriginal,
                                  orElse: () => <String, dynamic>{},
                                );

                                if (eventoEncontrado.isNotEmpty) {
                                  // Es un evento (grupo, cadena o riego)
                                  final eventoType =
                                      eventoEncontrado['evento'] as String;
                                  ejecutorName = equipoOriginal;
                                  isEvento = true;
                                  isCadena = eventoType == 'cadena';
                                  isRiego = eventoType == 'riego';
                                  isGrupo = eventoType == 'grupo';
                                }

                                // Definir acción, ícono y color según el tipo
                                String actionText = '';
                                IconData actionIcon =
                                    HugeIcons.strokeRoundedSettings02;
                                Color actionColor = color0;
                                String fullActionText = '';

                                if (isEvento) {
                                  // Manejo especial para eventos
                                  if (isCadena) {
                                    actionText = 'ejecutará';
                                    fullActionText = 'Se ejecutará';
                                    actionIcon =
                                        HugeIcons.strokeRoundedPlayCircle;
                                    actionColor = Colors.orange;
                                  } else if (isRiego) {
                                    actionText = 'ejecutará';
                                    fullActionText = 'Se ejecutará';
                                    actionIcon = HugeIcons.strokeRoundedLeaf01;
                                    actionColor = Colors.blue;
                                  } else if (isGrupo) {
                                    // Es un grupo
                                    final action = devicesActions[
                                            '$equipoOriginal:grupo'] ??
                                        false;
                                    actionText =
                                        action ? "Encenderá" : "Apagará";
                                    fullActionText = 'Se $actionText';
                                    actionIcon = action
                                        ? HugeIcons.strokeRoundedPlug01
                                        : HugeIcons.strokeRoundedPlugSocket;
                                    actionColor =
                                        action ? Colors.green : Colors.red;
                                  } else {
                                    // Evento desconocido
                                    actionText = 'ejecutará';
                                    fullActionText = 'Se ejecutará';
                                    actionIcon =
                                        HugeIcons.strokeRoundedSettings02;
                                    actionColor = color4;
                                  }
                                } else {
                                  // Es un dispositivo individual
                                  final action =
                                      devicesActions[equipoOriginal] ?? false;
                                  actionText = action ? "Encenderá" : "Apagará";
                                  fullActionText = 'Se $actionText';
                                  actionIcon = action
                                      ? HugeIcons.strokeRoundedPlug01
                                      : HugeIcons.strokeRoundedPlugSocket;
                                  actionColor = action ? Colors.green : color4;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: actionColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: actionColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: color4,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$idx',
                                            style: GoogleFonts.poppins(
                                              color: color1,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ejecutorName,
                                              style: GoogleFonts.poppins(
                                                color: color0,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  actionIcon,
                                                  color: actionColor,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  fullActionText,
                                                  style: GoogleFonts.poppins(
                                                    color: actionColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        actionIcon,
                                        color: actionColor,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(
                                    HugeIcons.strokeRoundedDelete02,
                                    color: color0,
                                  ),
                                  tooltip: 'Eliminar evento de disparadores',
                                  onPressed: () {
                                    showAlertDialog(
                                      context,
                                      false,
                                      const Text(
                                        '¿Eliminar este evento de control por disparador?',
                                        style: TextStyle(color: color0),
                                      ),
                                      const Text(
                                        'Esta acción no se puede deshacer.',
                                        style: TextStyle(color: color0),
                                      ),
                                      <Widget>[
                                        TextButton(
                                          style: ButtonStyle(
                                            foregroundColor:
                                                WidgetStateProperty.all(color0),
                                          ),
                                          child: const Text('Cancelar'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          style: ButtonStyle(
                                            foregroundColor:
                                                WidgetStateProperty.all(color0),
                                          ),
                                          child: const Text('Confirmar'),
                                          onPressed: () {
                                            setState(() {
                                              eventosCreados.removeAt(index);
                                              putEventos(currentUserEmail,
                                                  eventosCreados);
                                              printLog.d(grupo,
                                                  color: 'naranja');

                                              String sortKey =
                                                  '$currentUserEmail:$grupo';

                                              removeEjecutoresFromDisparador(
                                                  activador, sortKey);
                                              todosLosDispositivos.removeWhere(
                                                  (entry) =>
                                                      entry.key == grupo);
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              printLog
                  .e('Error al procesar el evento de disparador $grupo: $e');
              return Card(
                key: ValueKey('disparador_error_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ListTile(
                    title: Text(
                      'Error al cargar el evento de disparador $grupo',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Por favor, elimine el evento y vuelva a crearlo.',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          // Manejar evento de horario
          if (eventoHorario != null) {
            try {
              List<String> selectedDays =
                  List<String>.from(eventoHorario['selectedDays'] ?? []);
              String selectedTime = eventoHorario['selectedTime'] ?? '';

              // Obtener las acciones de los dispositivos
              Map<String, dynamic> devicesActions = Map<String, dynamic>.from(
                  eventoHorario['deviceActions'] ?? {});
              // Crear lista de nombres de dispositivos
              String devicesInGroup = deviceName;
              List<String> deviceList = devicesInGroup
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .split(',');
              List<String> horarioNicksList = [];
              for (String equipo in deviceList) {
                String displayName = '';
                if (equipo.contains('_')) {
                  final parts = equipo.split('_');
                  displayName = nicknamesMap[equipo.trim()] ??
                      '${parts[0]} salida ${parts[1]}';
                } else {
                  displayName = nicknamesMap[equipo.trim()] ?? equipo.trim();
                }
                horarioNicksList.add(displayName);
              }

              // Formatear días
              String formatDays(List<String> days) {
                if (days.isEmpty) return 'No hay días seleccionados';
                if (days.length == 1) return days.first;
                final primeros = days.sublist(0, days.length - 1);
                return '${primeros.join(', ')} y ${days.last}';
              }

              return Card(
                key: ValueKey('horario_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    iconColor: color4,
                    collapsedIconColor: color4,
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _expandedStates[deviceName] = expanded;
                      });
                    },
                    title: Row(
                      children: [
                        const Icon(HugeIcons.strokeRoundedClock01,
                            color: color4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grupo,
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color0.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'HORARIO',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Información de días y hora (simplificado)
                            Row(
                              children: [
                                const Icon(
                                  HugeIcons.strokeRoundedCalendar01,
                                  color: color4,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Días',
                                        style: GoogleFonts.poppins(
                                          color: color0.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        formatDays(selectedDays),
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(
                                  HugeIcons.strokeRoundedTime01,
                                  color: color4,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hora',
                                        style: GoogleFonts.poppins(
                                          color: color0.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        selectedTime.isNotEmpty
                                            ? selectedTime
                                            : 'No especificada',
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Dispositivos afectados
                            Text(
                              'Dispositivos afectados:',
                              style: GoogleFonts.poppins(
                                color: color0,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...horarioNicksList.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              String deviceNick = entry.value;
                              final equipo = deviceList[entry.key].trim();

                              // Verificar si es un evento buscando en eventosCreados
                              bool isEvento = false;
                              bool isCadena = false;
                              bool isRiego = false;
                              bool isGrupo = false;

                              final eventoEncontrado =
                                  eventosCreados.firstWhere(
                                (evento) => evento['title'] == equipo,
                                orElse: () => <String, dynamic>{},
                              );

                              if (eventoEncontrado.isNotEmpty) {
                                // Es un evento (grupo, cadena o riego)
                                final eventoType =
                                    eventoEncontrado['evento'] as String;
                                deviceNick = equipo;
                                isEvento = true;
                                isCadena = eventoType == 'cadena';
                                isRiego = eventoType == 'riego';
                                isGrupo = eventoType == 'grupo';
                              }

                              // Definir acción, ícono y color según el tipo
                              String actionText = '';
                              IconData actionIcon =
                                  HugeIcons.strokeRoundedSettings02;
                              Color actionColor = color0;

                              if (isEvento) {
                                // Manejo especial para eventos
                                if (isCadena) {
                                  actionText = 'Se ejecutará';
                                  actionIcon =
                                      HugeIcons.strokeRoundedPlayCircle;
                                  actionColor = Colors.orange;
                                } else if (isRiego) {
                                  actionText = 'Se ejecutará';
                                  actionIcon = HugeIcons.strokeRoundedLeaf01;
                                  actionColor = Colors.blue;
                                } else if (isGrupo) {
                                  // Es un grupo
                                  final action =
                                      devicesActions['$equipo:grupo'] ?? false;
                                  actionText = action ? "Encenderá" : "Apagará";
                                  actionIcon = action
                                      ? HugeIcons.strokeRoundedPlug01
                                      : HugeIcons.strokeRoundedPlugSocket;
                                  actionColor =
                                      action ? Colors.green : Colors.red;
                                } else {
                                  // Evento desconocido
                                  actionText = 'Se ejecutará';
                                  actionIcon =
                                      HugeIcons.strokeRoundedSettings02;
                                  actionColor = color4;
                                }
                              } else {
                                // Es un dispositivo individual
                                final action =
                                    devicesActions['$equipo:dispositivo'] ??
                                        false;
                                actionText = action ? "Encenderá" : "Apagará";
                                actionIcon = action
                                    ? HugeIcons.strokeRoundedPlug01
                                    : HugeIcons.strokeRoundedPlugSocket;
                                actionColor =
                                    action ? Colors.green : Colors.red;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: color4,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$idx',
                                          style: GoogleFonts.poppins(
                                            color: color1,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        deviceNick,
                                        style: GoogleFonts.poppins(
                                          color: color0,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      actionIcon,
                                      color: actionColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      actionText,
                                      style: GoogleFonts.poppins(
                                        color: actionColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: color0,
                                ),
                                tooltip: 'Eliminar evento de horario',
                                onPressed: () {
                                  showAlertDialog(
                                    context,
                                    false,
                                    const Text(
                                      '¿Eliminar este evento de control por horario?',
                                      style: TextStyle(color: color0),
                                    ),
                                    const Text(
                                      'Esta acción no se puede deshacer.',
                                      style: TextStyle(color: color0),
                                    ),
                                    <Widget>[
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Cancelar'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        style: ButtonStyle(
                                          foregroundColor:
                                              WidgetStateProperty.all(color0),
                                        ),
                                        child: const Text('Confirmar'),
                                        onPressed: () {
                                          setState(() {
                                            eventosCreados.removeAt(index);
                                            putEventos(currentUserEmail,
                                                eventosCreados);
                                            deleteEventoControlPorHorarios(
                                                selectedTime,
                                                currentUserEmail,
                                                grupo);
                                            todosLosDispositivos.removeWhere(
                                                (entry) => entry.key == grupo);
                                          });
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              printLog.e('Error al procesar el evento de horario $grupo: $e');
              return Card(
                key: ValueKey('horario_error_$grupo'),
                color: color1,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ListTile(
                    title: Text(
                      'Error al cargar el evento de horario $grupo',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Por favor, elimine el evento y vuelva a crearlo.',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          String devicesInGroup = deviceName;
          List<String> deviceList =
              devicesInGroup.replaceAll('[', '').replaceAll(']', '').split(',');
          List<String> nicksList = [];
          for (String equipo in deviceList) {
            String displayName = '';
            if (equipo.contains('_')) {
              final parts = equipo.split('_');
              displayName = nicknamesMap[equipo.trim()] ??
                  '${parts[0]} salida ${parts[1]}';
            } else {
              displayName = nicknamesMap[equipo.trim()] ?? equipo.trim();
            }

            nicksList.add(displayName);
          }

          for (String device in deviceList) {
            String equipo = DeviceManager.getProductCode(device);
            String serial = DeviceManager.extractSerialNumber(
              device,
            );

            final deviceSpecificData = ref.watch(
              globalDataProvider.select(
                (map) => map['$equipo/$serial'] ?? {},
              ),
            );

            globalDATA
                .putIfAbsent('$equipo/$serial', () => {})
                .addAll(deviceSpecificData);
          }

          bool online = isGroupOnline(devicesInGroup);
          bool estado = isGroupOn(devicesInGroup);
          bool owner = canControlGroup(devicesInGroup);

          try {
            return Card(
              key: ValueKey('grupo_$grupo'),
              color: color1,
              margin: const EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 10,
              ),
              elevation: 2,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                  ),
                  iconColor: color4,
                  collapsedIconColor: color4,
                  onExpansionChanged: (bool expanded) {
                    setState(() {
                      _expandedStates[deviceName] = expanded;
                    });
                  },
                  title: Row(
                    children: [
                      const Icon(HugeIcons.strokeRoundedUserGroup,
                          color: color4),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          grupo[0].toUpperCase() + grupo.substring(1),
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color0.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'GRUPO',
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!online) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.wifi_off,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Todos los equipos deben estar conectados para su uso',
                                      style: GoogleFonts.poppins(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            // Control del grupo cuando está online
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: estado
                                    ? color0.withValues(alpha: 0.1)
                                    : color0.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color0,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    estado ? Icons.power : Icons.power_off,
                                    color: estado ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      estado
                                          ? 'Grupo encendido'
                                          : 'Grupo apagado',
                                      style: GoogleFonts.poppins(
                                        color: estado ? Colors.green : color4,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (owner)
                                    Switch(
                                      activeThumbColor: Colors.green,
                                      activeTrackColor:
                                          Colors.green.withValues(alpha: 0.3),
                                      inactiveThumbColor: color4,
                                      inactiveTrackColor:
                                          color4.withValues(alpha: 0.3),
                                      value: estado,
                                      onChanged: (newValue) {
                                        controlGroup(
                                          currentUserEmail,
                                          newValue,
                                          grupo,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'Dispositivos en el grupo:',
                            style: GoogleFonts.poppins(
                              color: color0,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...nicksList.map((deviceDisplayName) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: color1.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color0.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      deviceDisplayName,
                                      style: GoogleFonts.poppins(
                                        color: color0,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(
                                HugeIcons.strokeRoundedDelete02,
                                color: color0,
                              ),
                              tooltip: 'Eliminar evento de grupos',
                              onPressed: () {
                                showAlertDialog(
                                  context,
                                  false,
                                  const Text(
                                    '¿Eliminar este evento de control por grupos?',
                                    style: TextStyle(color: color0),
                                  ),
                                  const Text(
                                    'Esta acción no se puede deshacer.',
                                    style: TextStyle(color: color0),
                                  ),
                                  <Widget>[
                                    TextButton(
                                      style: ButtonStyle(
                                        foregroundColor:
                                            WidgetStateProperty.all(color0),
                                      ),
                                      child: const Text('Cancelar'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      style: ButtonStyle(
                                        foregroundColor:
                                            WidgetStateProperty.all(color0),
                                      ),
                                      child: const Text('Confirmar'),
                                      onPressed: () {
                                        setState(() {
                                          eventosCreados.removeAt(index);
                                          putEventos(
                                              currentUserEmail, eventosCreados);
                                          printLog.d(grupo, color: 'naranja');
                                          deleteEventoControlPorGrupos(
                                              currentUserEmail, grupo);
                                          todosLosDispositivos.removeWhere(
                                              (entry) => entry.key == grupo);
                                        });
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } catch (e) {
            printLog.e('Error al procesar el grupo $grupo: $e');
            return Card(
              key: ValueKey('grupo_error_$grupo'),
              color: color1,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              elevation: 2,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ListTile(
                  title: Text(
                    'Error al cargar el grupo $grupo',
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Por favor, elimine el evento y vuelva a crearlo.',
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      },
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(
          color: Colors.transparent,
          child: child,
        );
      },
    );
  }

  // Función para construir tarjeta de equipo de riego
  Widget _buildRiegoCard(
      String deviceName,
      String productCode,
      String serialNumber,
      Map<String, dynamic> deviceDATA,
      bool online,
      bool owner) {
    // Verificar si es un equipo maestro (riegoActive = true) o extensión
    bool isRiegoActive = deviceDATA['riegoActive'] == true;

    if (!isRiegoActive) {
      // Es una extensión, no debería mostrarse aquí (ya está filtrado arriba)
      return SizedBox.shrink(key: ValueKey(deviceName));
    }

    // Obtener extensiones vinculadas
    List<String> extensionesVinculadas = [];
    globalDATA.forEach((key, value) {
      if (value['riegoMaster'] == deviceName &&
          (key.startsWith('020020_IOT/') ||
              key.startsWith('020010_IOT/') ||
              key.startsWith('027313_IOT/'))) {
        String pc = key.split('/')[0];
        String sn = key.split('/')[1];
        String extensionName = DeviceManager.recoverDeviceName(pc, sn);
        extensionesVinculadas.add(extensionName);
      }
    });

    return Card(
      key: ValueKey(deviceName),
      color: color1,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      elevation: 2,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
          iconColor: color4,
          collapsedIconColor: color4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(
                      nicknamesMap[deviceName] ?? deviceName,
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Text(
                        online ? '● CONECTADO' : '● DESCONECTADO',
                        style: GoogleFonts.poppins(
                          color: online ? Colors.green : color3,
                          fontSize: 15,
                        ),
                      ),
                      Icon(
                        online ? Icons.cloud : Icons.cloud_off,
                        color: online ? Colors.green : color3,
                        size: 15,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'RIEGO',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          children: <Widget>[
            if (online) ...[
              // Mostrar salidas del equipo principal (solo salidas, no entradas)
              ...((deviceDATA.keys
                      .where((key) =>
                          key.startsWith('io') &&
                          RegExp(r'^io\d+$').hasMatch(key))
                      .where((ioKey) {
                if (deviceDATA[ioKey] == null) return false;
                try {
                  var ioData = jsonDecode(deviceDATA[ioKey]);
                  return ioData['pinType'] == '0';
                } catch (e) {
                  return false;
                }
              }).toList()
                    ..sort((a, b) {
                      int indexA = int.parse(a.substring(2));
                      int indexB = int.parse(b.substring(2));
                      return indexA.compareTo(indexB);
                    }))
                  .map((ioKey) => _buildRiegoOutput(deviceName, productCode,
                      serialNumber, ioKey, deviceDATA, owner))),

              // Mostrar extensiones si las hay
              if (extensionesVinculadas.isNotEmpty) ...[
                const Divider(color: color0, thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Extensiones Vinculadas',
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...extensionesVinculadas.map((extension) =>
                    _buildExtensionCard(extension, deviceName, owner)),
              ],
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'El equipo debe estar conectado para su uso',
                  style: GoogleFonts.poppins(
                    color: color3,
                    fontSize: 15,
                  ),
                ),
              ),
            ],

            // Botón de eliminar
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                child: IconButton(
                  icon: const Icon(
                    HugeIcons.strokeRoundedDelete02,
                    color: color0,
                    size: 20,
                  ),
                  onPressed: () {
                    _confirmDelete(deviceName, productCode);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Función para construir una salida de riego
  Widget _buildRiegoOutput(
      String deviceName,
      String productCode,
      String serialNumber,
      String ioKey,
      Map<String, dynamic> deviceDATA,
      bool owner) {
    int outputIndex = int.parse(ioKey.substring(2));
    Map<String, dynamic> outputData = jsonDecode(deviceDATA[ioKey]);

    String pinType = outputData['pinType'].toString();
    bool isOutput = pinType == '0';

    // En equipos de riego, solo mostrar salidas (ocultar entradas)
    if (!isOutput) {
      return const SizedBox.shrink();
    }

    bool currentStatus = outputData['w_status'] ?? false;
    String rState = (outputData['r_state'] ?? '0').toString();

    // Para la bomba (salida 0), usar lógica especial
    bool isBomb = outputIndex == 0 && isOutput;

    // Para las zonas, verificar lógica de riego
    String displayName;
    if (isBomb) {
      displayName = 'Bomba'; // La bomba siempre se llama "Bomba", sin nickname
    } else {
      displayName =
          nicknamesMap['${deviceName}_$outputIndex'] ?? 'Zona $outputIndex';
    }

    return ListTile(
      title: Text(
        displayName,
        style: GoogleFonts.poppins(
          color: color0,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        _getRiegoStatusText(currentStatus, isOutput, isBomb, rState),
        style: GoogleFonts.poppins(
          color: _getRiegoStatusColor(currentStatus, isOutput, isBomb, rState),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: owner && isOutput
          ? Switch(
              activeThumbColor: const Color(0xFF9C9D98),
              activeTrackColor: const Color(0xFFB2B5AE),
              inactiveThumbColor: const Color(0xFFB2B5AE),
              inactiveTrackColor: const Color(0xFF9C9D98),
              value: currentStatus,
              onChanged: (value) => _controlRiegoOutput(deviceName, productCode,
                  serialNumber, outputIndex, value, isBomb),
            )
          : isOutput
              ? null
              : Icon(
                  Icons.sensors,
                  color: _getRiegoStatusColor(
                      currentStatus, isOutput, isBomb, rState),
                ),
    );
  }

  // Función para construir tarjeta de extensión
  Widget _buildExtensionCard(
      String extension, String masterDevice, bool owner) {
    String extensionPc = DeviceManager.getProductCode(extension);
    String extensionSn = DeviceManager.extractSerialNumber(extension);
    String key = '$extensionPc/$extensionSn';

    Map<String, dynamic> extensionData = globalDATA[key] ?? {};
    bool isExtensionOnline = extensionData['cstate'] ?? false;

    // Obtener solo las salidas de la extensión
    List<MapEntry<String, dynamic>> outputs = [];
    extensionData.forEach((k, v) {
      if (k.startsWith('io') && v is String) {
        try {
          var decoded = jsonDecode(v);
          if (decoded['pinType'] == '0') {
            outputs.add(MapEntry(k, decoded));
          }
        } catch (e) {
          printLog.e('Error decodificando datos I/O: $e');
        }
      }
    });

    outputs.sort((a, b) {
      int indexA = int.tryParse(a.key.replaceAll('io', '')) ?? 0;
      int indexB = int.tryParse(b.key.replaceAll('io', '')) ?? 0;
      return indexA.compareTo(indexB);
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color: color0.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExtensionOnline ? Icons.cloud : Icons.cloud_off,
                  color: isExtensionOnline ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nicknamesMap[extension] ?? extension,
                    style: GoogleFonts.poppins(
                      color: color0,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isExtensionOnline && outputs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...outputs.map((output) {
                int outputIndex = int.parse(output.key.replaceAll('io', ''));
                bool isOn = output.value['w_status'] ?? false;
                String zoneLabel = nicknamesMap['${extension}_$outputIndex'] ??
                    'Zona ${_getZoneNumber(masterDevice, extension, outputIndex)}';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          zoneLabel,
                          style: GoogleFonts.poppins(
                            color: color0,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        isOn ? 'Encendido' : 'Apagado',
                        style: GoogleFonts.poppins(
                          color: isOn ? Colors.green : color4,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (owner)
                        Switch(
                          activeThumbColor: const Color(0xFF9C9D98),
                          activeTrackColor: const Color(0xFFB2B5AE),
                          inactiveThumbColor: const Color(0xFFB2B5AE),
                          inactiveTrackColor: const Color(0xFF9C9D98),
                          value: isOn,
                          onChanged: (value) => _controlExtensionOutput(
                              extension, outputIndex, value, masterDevice),
                        ),
                    ],
                  ),
                );
              }),
            ] else if (!isExtensionOnline) ...[
              const SizedBox(height: 8),
              Text(
                'Extensión desconectada',
                style: GoogleFonts.poppins(
                  color: color3,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Función auxiliar para obtener el número de zona consecutivo
  int _getZoneNumber(String masterDevice, String extension, int outputIndex) {
    int zoneCounter = 1;

    // Contar zonas del maestro primero
    String masterPc = DeviceManager.getProductCode(masterDevice);
    String masterSn = DeviceManager.extractSerialNumber(masterDevice);
    Map<String, dynamic> masterData = globalDATA['$masterPc/$masterSn'] ?? {};

    masterData.forEach((key, value) {
      if (key.startsWith('io') && key != 'io0' && value is String) {
        try {
          var decoded = jsonDecode(value);
          if (decoded['pinType'] == '0') {
            zoneCounter++;
          }
        } catch (e) {
          // Error handling
        }
      }
    });

    // Luego contar zonas de extensiones anteriores a esta
    List<String> extensionesVinculadas = [];
    globalDATA.forEach((key, value) {
      if (value['riegoMaster'] == masterDevice &&
          key !=
              '${DeviceManager.getProductCode(extension)}/${DeviceManager.extractSerialNumber(extension)}') {
        String pc = key.split('/')[0];
        String sn = key.split('/')[1];
        String extensionName = DeviceManager.recoverDeviceName(pc, sn);
        extensionesVinculadas.add(extensionName);
      }
    });

    for (String ext in extensionesVinculadas) {
      if (ext == extension) break;

      String extPc = DeviceManager.getProductCode(ext);
      String extSn = DeviceManager.extractSerialNumber(ext);
      Map<String, dynamic> extData = globalDATA['$extPc/$extSn'] ?? {};

      extData.forEach((key, value) {
        if (key.startsWith('io') && value is String) {
          try {
            var decoded = jsonDecode(value);
            if (decoded['pinType'] == '0') {
              zoneCounter++;
            }
          } catch (e) {
            // Error handling
          }
        }
      });
    }

    // Agregar el índice de salida actual
    String extPc = DeviceManager.getProductCode(extension);
    String extSn = DeviceManager.extractSerialNumber(extension);
    Map<String, dynamic> extData = globalDATA['$extPc/$extSn'] ?? {};

    List<int> outputs = [];
    extData.forEach((key, value) {
      if (key.startsWith('io') && value is String) {
        try {
          var decoded = jsonDecode(value);
          if (decoded['pinType'] == '0') {
            outputs.add(int.parse(key.replaceAll('io', '')));
          }
        } catch (e) {
          // Error handling
        }
      }
    });

    outputs.sort();
    int indexInExtension = outputs.indexOf(outputIndex);

    return zoneCounter + indexInExtension;
  }

  // Funciones auxiliares para el estado de riego
  String _getRiegoStatusText(
      bool status, bool isOutput, bool isBomb, String rState) {
    if (isOutput) {
      if (isBomb) {
        return status ? 'Encendida' : 'Apagada';
      } else {
        return status ? 'Regando' : 'Apagada';
      }
    } else {
      return status
          ? (rState == '1' ? 'Cerrado' : 'Abierto')
          : (rState == '1' ? 'Abierto' : 'Cerrado');
    }
  }

  Color _getRiegoStatusColor(
      bool status, bool isOutput, bool isBomb, String rState) {
    if (isOutput) {
      return status ? Colors.green : color4;
    } else {
      bool isNormalClosed = rState == '1';
      return status == isNormalClosed ? Colors.green : color4;
    }
  }

  // Función para controlar salidas de riego individual
  void _controlRiegoOutput(String deviceName, String productCode,
      String serialNumber, int outputIndex, bool value, bool isBomb) {
    // Verificar si hay procesos en curso
    if (_isPumpShuttingDown) {
      showToast('Espere, la bomba se está apagando...');
      return;
    }

    if (_isAutoStarting) {
      showToast('Espere, se está iniciando automáticamente...');
      return;
    }

    // Aplicar lógica similar a riego.dart
    Map<String, dynamic> deviceDATA =
        globalDATA['$productCode/$serialNumber'] ?? {};
    bool freeBomb = deviceDATA['freeBomb'] ?? false;

    // Validación especial para control directo de bomba
    if (isBomb && !freeBomb) {
      if (value) {
        // Intentando ENCENDER la bomba - verificar si hay zonas activas
        int activeZones = _countActiveZonesForDevice(productCode, serialNumber);
        int activeExtensionZones =
            _countActiveZonesForAllExtensions(deviceName);
        int totalActiveZones = activeZones + activeExtensionZones;

        if (totalActiveZones == 0) {
          showToast('No se puede encender la bomba sin zonas activas.');
          return;
        }
      }
      // Si llegamos aquí, permitir el control directo de la bomba
      _sendRiegoCommand(productCode, serialNumber, outputIndex, value);
      return;
    }

    if (!freeBomb && !isBomb) {
      // Lógica para zonas con bomba automática
      if (value) {
        // ENCENDER: zona primero, luego bomba
        _sendRiegoCommand(productCode, serialNumber, outputIndex, value);

        // Verificar si la bomba está apagada
        if (deviceDATA['io0'] != null) {
          try {
            var bombData = jsonDecode(deviceDATA['io0']);
            bool bombStatus = bombData['w_status'] ?? false;

            if (!bombStatus) {
              setState(() {
                _isAutoStarting = true;
              });

              // Delay de 1 segundo antes de encender bomba
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  _sendRiegoCommand(productCode, serialNumber, 0, true);
                  setState(() {
                    _isAutoStarting = false;
                  });
                }
              });
            }
          } catch (e) {
            // Error handling
          }
        }
        return;
      } else {
        // APAGAR: verificar si es la última activa (incluyendo extensiones)
        int activeZones = _countActiveZonesForDevice(productCode, serialNumber);
        int activeExtensionZones =
            _countActiveZonesForAllExtensions(deviceName);
        int totalActiveZones = activeZones + activeExtensionZones;

        if (totalActiveZones == 1) {
          setState(() {
            _isPumpShuttingDown = true;
          });

          // Esta es la última zona activa - bomba primero, luego zona
          _sendRiegoCommand(productCode, serialNumber, 0, false);

          // Delay de 1 segundo antes de apagar zona
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _sendRiegoCommand(productCode, serialNumber, outputIndex, value);
              setState(() {
                _isPumpShuttingDown = false;
              });
            }
          });
          return;
        }
      }
    }

    // Envío normal
    _sendRiegoCommand(productCode, serialNumber, outputIndex, value);
  }

  // Función para controlar salidas de extensión
  void _controlExtensionOutput(
      String extension, int outputIndex, bool value, String masterDevice) {
    // Verificar si hay procesos en curso
    if (_isPumpShuttingDown) {
      showToast('Espere, la bomba se está apagando...');
      return;
    }

    if (_isAutoStarting) {
      showToast('Espere, se está iniciando automáticamente...');
      return;
    }

    String extensionPc = DeviceManager.getProductCode(extension);
    String extensionSn = DeviceManager.extractSerialNumber(extension);

    // Obtener datos del maestro para la lógica de bomba
    String masterPc = DeviceManager.getProductCode(masterDevice);
    String masterSn = DeviceManager.extractSerialNumber(masterDevice);
    Map<String, dynamic> masterData = globalDATA['$masterPc/$masterSn'] ?? {};
    bool freeBomb = masterData['freeBomb'] ?? false;

    if (!freeBomb) {
      // Aplicar lógica de bomba automática
      if (value) {
        // ENCENDER: extensión primero, luego bomba del maestro
        _sendRiegoCommand(extensionPc, extensionSn, outputIndex, value);

        // Verificar si la bomba del maestro está apagada
        if (masterData['io0'] != null) {
          try {
            var bombData = jsonDecode(masterData['io0']);
            bool bombStatus = bombData['w_status'] ?? false;

            if (!bombStatus) {
              setState(() {
                _isAutoStarting = true;
              });

              // Delay de 1 segundo antes de encender bomba
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  _sendRiegoCommand(masterPc, masterSn, 0, true);
                  setState(() {
                    _isAutoStarting = false;
                  });
                }
              });
            }
          } catch (e) {
            // Error handling
          }
        }
        return;
      } else {
        // APAGAR: verificar si es la última zona activa
        int totalActiveZones = _countActiveZonesForDevice(masterPc, masterSn) +
            _countActiveZonesForAllExtensions(masterDevice);

        if (totalActiveZones == 1) {
          setState(() {
            _isPumpShuttingDown = true;
          });

          // Última zona activa - bomba primero, luego extensión
          _sendRiegoCommand(masterPc, masterSn, 0, false);

          // Delay de 1 segundo antes de apagar extensión
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _sendRiegoCommand(extensionPc, extensionSn, outputIndex, value);
              setState(() {
                _isPumpShuttingDown = false;
              });
            }
          });
          return;
        }
      }
    }

    // Envío normal para extensión
    _sendRiegoCommand(extensionPc, extensionSn, outputIndex, value);
  }

  // Función para enviar comando MQTT de riego
  void _sendRiegoCommand(String productCode, String serialNumber,
      int outputIndex, bool value) async {
    bool hasPermission = await checkAdminTimePermission(deviceName);
    if (!hasPermission) {
      showToast('No tiene permiso para controlar el riego ahora.');
      return;
    }
    String message = jsonEncode({
      'pinType': '0', // Siempre salida para riego
      'index': outputIndex,
      'w_status': value,
      'r_state': '0',
    });

    String topic = 'devices_rx/$productCode/$serialNumber';
    String topic2 = 'devices_tx/$productCode/$serialNumber';

    sendMessagemqtt(topic, message);
    sendMessagemqtt(topic2, message);

    // Actualizar datos locales
    globalDATA
        .putIfAbsent('$productCode/$serialNumber', () => {})
        .addAll({'io$outputIndex': message});
    saveGlobalData(globalDATA);

    setState(() {});
  }

  // Función para contar zonas activas de un dispositivo
  int _countActiveZonesForDevice(String productCode, String serialNumber) {
    Map<String, dynamic> deviceDATA =
        globalDATA['$productCode/$serialNumber'] ?? {};
    int count = 0;

    deviceDATA.forEach((key, value) {
      if (key.startsWith('io') && key != 'io0' && value is String) {
        try {
          var decoded = jsonDecode(value);
          if (decoded['pinType'] == '0' && decoded['w_status'] == true) {
            count++;
          }
        } catch (e) {
          // Error handling
        }
      }
    });

    return count;
  }

  // Función para contar zonas activas de todas las extensiones
  int _countActiveZonesForAllExtensions(String masterDevice) {
    int count = 0;

    globalDATA.forEach((key, value) {
      if (value['riegoMaster'] == masterDevice) {
        Map<String, dynamic> extensionData = value;

        extensionData.forEach((ioKey, ioValue) {
          if (ioKey.startsWith('io') && ioValue is String) {
            try {
              var decoded = jsonDecode(ioValue);
              if (decoded['pinType'] == '0' && decoded['w_status'] == true) {
                count++;
              }
            } catch (e) {
              // Error handling
            }
          }
        });
      }
    });

    return count;
  }
}
