import 'package:dio/dio.dart';

/// Jerarquia de errores de la API.
///
/// Existe para que la UI no tenga que mirar codigos HTTP sueltos. La
/// distincion importante del contrato de PowerTech:
///
///   401 en ruta autenticada  -> sesion vencida  -> hay que relogear
///   403 sin `codigo`         -> acceso denegado -> cuenta de gestion
///                               intentando entrar a la app de clientes
///   403 codigo=email_no_     -> falta verificar -> la credencial es buena,
///       verificado                                 falta tocar el enlace
///                                                  del correo
///
/// **Los dos 403 no se pueden confundir y por eso el `codigo` se lee.** El
/// primero es definitivo: esa cuenta no entra a la app de clientes nunca y
/// corresponde cerrar sesion. El segundo es un paso pendiente que el usuario
/// resuelve solo, sin volver a ingresar. Tratarlos igual le diria a un cliente
/// recien registrado que su cuenta no sirve, que es falso y lo deja sin
/// salida.
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

/// 403 con `codigo: "email_no_verificado"`.
///
/// Lo devuelve el middleware `api.verificado` del backend en las rutas que lo
/// exigen: hoy el carrito, y el checkout cuando exista. Es la misma regla que
/// `routes/web.php` aplica con `verified`.
///
/// **No es sesion vencida ni acceso denegado.** El token es valido y la
/// cuenta es de tienda; lo unico que falta es que el cliente toque el enlace
/// que le llego por correo. No hay que cerrar sesion: hay que llevarlo a la
/// pantalla de verificacion, que ya tiene su boton de reenvio.
///
/// En condiciones normales la app no deberia llegar a este error: `Usuario`
/// trae `emailVerificado` justamente para poder mostrar la pantalla correcta
/// antes de pedir. Esto cubre el caso en que el estado local quedo viejo.
class ErrorEmailNoVerificado extends ErrorApi {
  const ErrorEmailNoVerificado([
    super.mensaje = 'Necesitás confirmar tu correo para usar el carrito.',
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

/// 429. El throttle por IP de `routes/api.php` cortó la llamada.
///
/// No confundir con el de cinco intentos por correo + IP que vive en
/// `LoginMovilRequest`: ese sale como 422 sobre el campo `email`, con el
/// texto de `auth.throttle` ya en castellano, y se muestra debajo del campo
/// como cualquier otro error de validacion. Este es el de afuera, el que
/// cuenta llamadas por minuto sin mirar de quien son, y Laravel lo contesta
/// en ingles: por eso el mensaje se arma aca.
///
/// `segundos` sale de la cabecera `Retry-After` cuando el servidor la manda.
class ErrorDemasiadosIntentos extends ErrorApi {
  const ErrorDemasiadosIntentos(super.mensaje, {this.segundos});

  final int? segundos;
}

/// Cualquier otro codigo HTTP de error (500, 502, 503...).
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
    // Los dos 403 del contrato se separan por el campo `codigo`, no por el
    // texto del mensaje. Un 403 sin `codigo` sigue cayendo donde caia antes,
    // asi que nada de lo que ya funcionaba cambia.
    case 403:
      return _codigoDe(cuerpo) == 'email_no_verificado'
          ? ErrorEmailNoVerificado(mensaje)
          : ErrorAccesoDenegado(mensaje);
    case 404:
      return ErrorNoEncontrado(mensaje);
    case 422:
      return ErrorValidacion(mensaje, _extraerErrores(cuerpo));
    case 429:
      return _mapearDemasiadosIntentos(respuesta);
    default:
      return ErrorServidor(mensaje, codigo);
  }
}

/// El `codigo` que algunas respuestas de error traen junto al `message`.
///
/// Solo lo emiten los errores que la app tiene que distinguir por algo mas
/// que el codigo HTTP. Hoy hay uno: `email_no_verificado`.
String? _codigoDe(dynamic cuerpo) {
  if (cuerpo is! Map) return null;

  final codigo = cuerpo['codigo'];

  return codigo is String && codigo.isNotEmpty ? codigo : null;
}

/// El mensaje de Laravel para el 429 es "Too Many Attempts.", asi que no se
/// reutiliza: se arma uno en castellano con los segundos de `Retry-After`.
ErrorApi _mapearDemasiadosIntentos(Response<dynamic>? respuesta) {
  final segundos = int.tryParse(
    respuesta?.headers.value('retry-after')?.trim() ?? '',
  );

  if (segundos == null || segundos <= 0) {
    return const ErrorDemasiadosIntentos(
      'Hiciste demasiados intentos seguidos. Esperá un momento y probá de nuevo.',
    );
  }

  final espera = segundos < 60
      ? '$segundos segundos'
      : '${(segundos / 60).ceil()} minutos';

  return ErrorDemasiadosIntentos(
    'Hiciste demasiados intentos seguidos. Probá de nuevo en $espera.',
    segundos: segundos,
  );
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
