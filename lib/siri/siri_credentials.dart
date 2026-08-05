import 'dart:io';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:caldensmart/logger.dart';
import 'package:flutter/services.dart';

/// Sincroniza las credenciales de Cognito con el Keychain compartido de iOS
/// para que la App Intents Extension (Siri) pueda autenticarse sola.
///
/// En Android no hace nada: los widgets y el asistente van por otro camino.
class SiriCredentials {
  static const _channel = MethodChannel('com.caldensmart.sime/siri');

  /// Escribe el refresh token en el Keychain compartido.
  ///
  /// Llamar despues de cada login exitoso y en cada arranque de la app con
  /// sesion activa. Es idempotente y barato: si el token no cambio, se
  /// reescribe el mismo valor.
  ///
  /// Devuelve true si quedo guardado.
  static Future<bool> sync() async {
    if (!Platform.isIOS) return false;

    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (!session.isSignedIn) {
        await clear();
        return false;
      }

      final tokens = session.userPoolTokensResult.valueOrNull;
      if (tokens == null) {
        printLog.i('[Siri] Sesion sin userPoolTokens, no se sincroniza');
        return false;
      }

      final ok = await _channel.invokeMethod<bool>(
        'saveRefreshToken',
        {'refreshToken': tokens.refreshToken},
      );

      printLog.i('[Siri] Credenciales sincronizadas: $ok');
      return ok ?? false;
    } on PlatformException catch (e) {
      printLog.e('[Siri] Error guardando credenciales: ${e.message}');
      return false;
    } catch (e) {
      printLog.e('[Siri] Error inesperado sincronizando credenciales: $e');
      return false;
    }
  }

  /// Borra las credenciales del Keychain. Llamar SIEMPRE en el logout.
  ///
  /// Si no se llama, Siri sigue controlando los equipos del usuario anterior
  /// hasta que venza el refresh token (30 dias por defecto).
  static Future<void> clear() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('clearCredentials');
      printLog.i('[Siri] Credenciales borradas');
    } on PlatformException catch (e) {
      printLog.e('[Siri] Error borrando credenciales: ${e.message}');
    }
  }

  /// Para diagnostico / UI: saber si Siri tiene con que autenticarse.
  static Future<bool> hasCredentials() async {
    if (!Platform.isIOS) return false;

    try {
      return await _channel.invokeMethod<bool>('hasCredentials') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Cache: la version de iOS no cambia en runtime, y el FutureBuilder
  /// reevalua el future en cada rebuild.
  static bool? _available;

  /// Si el dispositivo soporta App Intents (iOS 16+).
  static Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    if (_available != null) return _available!;

    try {
      _available =
          await _channel.invokeMethod<bool>('isSiriAvailable') ?? false;
    } on PlatformException {
      _available = false;
    }
    return _available!;
  }

  /// Abre la hoja "Añadir a Siri" con el boton que lleva a la app Atajos.
  ///
  /// Sirve para que el usuario arme un atajo con la frase que quiera y pueda
  /// decir "Oye Siri, luces" sin nombrar la app. Requiere iOS 16+; en
  /// versiones anteriores muestra un aviso.
  static Future<void> openSetup() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('openSiriSetup');
    } on PlatformException catch (e) {
      printLog.e('[Siri] Error abriendo setup: ${e.message}');
    }
  }
}
