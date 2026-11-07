/// Configuracion de la app.
///
/// La URL base NUNCA se hardcodea: entra por `--dart-define=API_URL_BASE=...`.
/// `String.fromEnvironment` se resuelve en tiempo de compilacion, por eso es
/// `const` y por eso hay que recompilar (no basta un hot reload) cuando se
/// cambia el valor.
class Config {
  const Config._();

  /// Origen del backend, SIN el prefijo de la API y SIN barra final.
  /// Ej: http://10.0.2.2:8000
  static const String origen = String.fromEnvironment('API_URL_BASE');

  /// Prefijo de la API REST. Separado del origen para que `--dart-define`
  /// solo tenga que cambiar el host al pasar de emulador a ngrok.
  static const String prefijo = String.fromEnvironment(
    'API_PREFIJO',
    defaultValue: '/api/v1',
  );

  /// Milisegundos para conectar y para recibir respuesta.
  static const int timeoutConexionMs = int.fromEnvironment(
    'API_TIMEOUT_CONEXION_MS',
    defaultValue: 10000,
  );

  static const int timeoutRespuestaMs = int.fromEnvironment(
    'API_TIMEOUT_RESPUESTA_MS',
    defaultValue: 15000,
  );

  /// Imprime cada request/response de Dio en la consola. Solo para desarrollo.
  static const bool logHttp = bool.fromEnvironment(
    'API_LOG_HTTP',
    defaultValue: true,
  );

  /// false cuando se olvidaron el --dart-define. La pantalla de diagnostico
  /// lo detecta y avisa en vez de fallar con un error de red confuso.
  static bool get estaConfigurada => origen.trim().isNotEmpty;

  /// Origen normalizado, sin barras al final.
  static String get origenNormalizado =>
      origen.trim().replaceAll(RegExp(r'/+$'), '');

  /// URL base completa que recibe Dio. Ej: http://10.0.2.2:8000/api/v1
  static String get urlBaseApi => '$origenNormalizado$prefijo';
}
