import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de Sanctum en el almacenamiento cifrado del sistema
/// (Keystore en Android, Keychain en iOS).
///
/// Lo unico que se persiste es el token y su fecha de expiracion. Nunca se
/// cachean precios: `MotorPromociones` resuelve el descuento vigente al
/// momento de mirar, y un precio viejo hace que el backend aborte la compra
/// por diferencia de importe.
class AlmacenSeguro {
  AlmacenSeguro([FlutterSecureStorage? almacen])
      : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  static const _claveToken = 'powertech.token';
  static const _claveExpira = 'powertech.token_expira_el';

  Future<String?> leerToken() => _almacen.read(key: _claveToken);

  Future<DateTime?> leerExpiracion() async {
    final crudo = await _almacen.read(key: _claveExpira);
    if (crudo == null) return null;
    return DateTime.tryParse(crudo);
  }

  Future<void> guardarToken(String token, {DateTime? expiraEl}) async {
    await _almacen.write(key: _claveToken, value: token);
    if (expiraEl != null) {
      await _almacen.write(
        key: _claveExpira,
        value: expiraEl.toIso8601String(),
      );
    }
  }

  Future<void> borrarToken() async {
    await _almacen.delete(key: _claveToken);
    await _almacen.delete(key: _claveExpira);
  }
}
