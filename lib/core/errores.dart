import 'package:dio/dio.dart';

/// Jerarquia de errores de la API.
///
/// Existe para que la UI no tenga que mirar codigos HTTP sueltos. La
/// distincion importante del contrato de PowerTech:
///
///   401 en ruta autenticada  -> sesion vencida  -> hay que relogear
///   403                      -> acceso denegado -> cuenta de gestion
///                               intentando entrar a la app de clientes
///
/// El catalogo NUNCA da 401: con token vencido responde 200 tratando al
/// visitante como invitado. Por eso `ErrorSesionVencida` solo puede aparecer
/// en rutas protegidas, y es el unico disparador legitimo de "volve a entrar".
sealed class ErrorApi implements Exception {
  const ErrorApi(this.mensaje);

  final String mensaje;

  @override
  String toString() => '$runtimeType: $mensaje';
}

/// No se pudo llegar al servidor: sin internet, host equivocado, backend
/// apagado, timeout. En el emulador el sospechoso #1 es usar `localhost`
/// en vez de `10.0.2.2`.
class ErrorRed extends ErrorApi {
  const ErrorRed(super.mensaje, {this.causa});

  final Object? causa;
}

/// 401 en una ruta autenticada. El token expiro o fue revocado.
class ErrorSesionVencida extends ErrorApi {
  const ErrorSesionVencida([super.mensaje = 'La sesion expiro.']);
}

/// 403. No es sesion vencida: es una cuenta sin permiso para esta app.
class ErrorAccesoDenegado extends ErrorApi {
  const ErrorAccesoDenegado([
    super.mensaje = 'Esta cuenta no puede usar la app de clientes.',
  ]);
}

/// 404.
class ErrorNoEncontrado extends ErrorApi {
  const ErrorNoEncontrado([super.mensaje = 'El recurso no existe.']);
}

/// 422 de Laravel. `errores` trae el mapa campo -> lista de mensajes
/// tal cual lo arma el FormRequest.
class ErrorValidacion extends ErrorApi {
  const ErrorValidacion(super.mensaje, this.errores);

  final Map<String, List<String>> errores;

  /// Primer mensaje de un campo, o null si ese campo no fallo.
  String? primeroDe(String campo) {
    final lista = errores[campo];
    return (lista == null || lista.isEmpty) ? null : lista.first;
  }
}

/// Cualquier otro codigo HTTP de error (500, 503, 429...).
class ErrorServidor extends ErrorApi {
  const ErrorServidor(super.mensaje, this.codigo);

  final int? codigo;
}

/// El servidor respondio 200 pero el cuerpo no tiene la forma esperada.
/// Casi siempre significa que pegamos a una URL que no es la API
/// (por ejemplo el HTML de la web Blade, o la pagina de aviso de ngrok).
class ErrorFormato extends ErrorApi {
  const ErrorFormato(super.mensaje);
}

/// Traduce cualquier excepcion de Dio a un [ErrorApi].
ErrorApi mapearError(Object error) {
  if (error is ErrorApi) return error;

  if (error is! DioException) {
    return ErrorFormato('Error inesperado: $error');
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ErrorRed(
        'El servidor no respondio a tiempo. Revisa que Laravel este corriendo '
        'y que la URL base sea la correcta.',
        causa: error,
      );

    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return ErrorRed(
        'No se pudo conectar con el servidor.\n'
        'URL: ${error.requestOptions.uri}\n'
        '${error.message ?? ''}',
        causa: error,
      );

    case DioExceptionType.cancel:
      return const ErrorRed('La peticion fue cancelada.');

    case DioExceptionType.badCertificate:
      return const ErrorRed('El certificado TLS del servidor no es valido.');

    case DioExceptionType.badResponse:
      return _mapearRespuesta(error.response);
  }
}

ErrorApi _mapearRespuesta(Response<dynamic>? respuesta) {
  final codigo = respuesta?.statusCode;
  final cuerpo = respuesta?.data;

  final mensaje = (cuerpo is Map && cuerpo['message'] is String)
      ? cuerpo['message'] as String
      : 'El servidor respondio con el codigo $codigo.';

  switch (codigo) {
    case 401:
      return ErrorSesionVencida(mensaje);
    case 403:
      return ErrorAccesoDenegado(mensaje);
    case 404:
      return ErrorNoEncontrado(mensaje);
    case 422:
      return ErrorValidacion(mensaje, _extraerErrores(cuerpo));
    default:
      return ErrorServidor(mensaje, codigo);
  }
}

Map<String, List<String>> _extraerErrores(dynamic cuerpo) {
  if (cuerpo is! Map || cuerpo['errors'] is! Map) return const {};

  final crudo = cuerpo['errors'] as Map;
  final resultado = <String, List<String>>{};

  crudo.forEach((clave, valor) {
    if (valor is List) {
      resultado['$clave'] = valor.map((m) => '$m').toList();
    } else {
      resultado['$clave'] = ['$valor'];
    }
  });

  return resultado;
}
