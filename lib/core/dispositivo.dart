import 'dart:io' show Platform;

/// Con que nombre queda registrado el token en `personal_access_tokens`.
///
/// `LoginMovilRequest` lo acepta opcional y lo limita a 120 caracteres. Mas
/// adelante habilita una pantalla de "sesiones activas" con revocacion
/// individual; por ahora alcanza con distinguir un telefono de otro canal.
///
/// Se arma con `dart:io` y nada mas: el modelo real del equipo pediria
/// `device_info_plus`, una dependencia nueva para un dato que todavia no
/// mira nadie.
String nombreDelDispositivo() {
  final sistema = switch (Platform.operatingSystem) {
    'android' => 'Android',
    'ios' => 'iOS',
    'macos' => 'macOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    final otro => otro,
  };

  final nombre = 'App PowerTech ($sistema)';

  return nombre.length <= 120 ? nombre : nombre.substring(0, 120);
}
