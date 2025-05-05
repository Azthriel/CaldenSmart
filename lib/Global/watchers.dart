import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';

typedef VoidAsync = Future<void> Function();

class BluetoothWatcher {
  // ---------- singleton ----------
  static final BluetoothWatcher _inst = BluetoothWatcher._internal();
  factory BluetoothWatcher() => _inst;
  BluetoothWatcher._internal();

  StreamSubscription<BluetoothAdapterState>? _sub;
  bool _dialogOpen = false;

  void start({VoidAsync? onTurnedOff}) {
    _sub ??= FlutterBluePlus.adapterState.listen((state) async {
      if (state == BluetoothAdapterState.off && !_dialogOpen) {
        _dialogOpen = true;

        await onTurnedOff?.call();

        // pide al usuario que lo encienda
        await _askUserToTurnOn();

        _dialogOpen = false;
      }
    });
  }

  Future<void> _askUserToTurnOn() async {
    if (Platform.isAndroid) {
      // diálogo nativo de sistema
      await FlutterBluePlus
          .turnOn(); // Android only :contentReference[oaicite:1]{index=1}
    } else {
      // iOS ⇒ abre Ajustes (ver sección 3)
      await _openBluetoothSettingsIOS();
    }
  }

  // expuesto para test o para llamar desde botones
  Future<void> openSettingsIOS() => _openBluetoothSettingsIOS();

  // ------------- housekeeping -------------
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  // -------- iOS native bridge -------------
  static const _channel = MethodChannel('com.caldensmart.sime/native');

  Future<void> _openBluetoothSettingsIOS() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } on PlatformException catch (e) {
      debugPrint('No se pudo abrir ajustes: ${e.code} ${e.message}');
    }
  }
}

class LocationWatcher {
  /* ---------- singleton ---------- */
  static final LocationWatcher _inst = LocationWatcher._();
  
  factory LocationWatcher() => _inst;
  LocationWatcher._();

  /* ---------- channels ---------- */
  static const _event = EventChannel('com.caldensmart.sime/locationStream');
  static const _method = MethodChannel('com.caldensmart.sime/native');

  StreamSubscription? _sub;
  bool   _dialogOpen = false;
  /* ---------- start / stop ---------- */
  void start() {
    _sub ??= _event.receiveBroadcastStream().listen((enabled) async {
      if (enabled == false && !_dialogOpen) {
        _dialogOpen = true;
        await _askUserToTurnOn();
        _dialogOpen = false;
      }
    });
  }

  void dispose() => _sub?.cancel();

  /* ---------- helpers ---------- */
  Future<void> _askUserToTurnOn() async {
    // En ambos SO abrimos Ajustes.
    await _method.invokeMethod('openLocationSettings');
  }
}
