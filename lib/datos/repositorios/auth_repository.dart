import '../../core/almacenamiento.dart';
import '../../core/api_client.dart';
import '../../core/dispositivo.dart';
import '../../core/errores.dart';
import '../modelos/conversiones.dart';
import '../modelos/sesion.dart';
import '../modelos/usuario.dart';

/// Los cinco endpoints de sesion.
///
/// **Es el unico lugar que escribe en [AlmacenSeguro].** Ni los providers ni
/// las pantallas tocan el token: si manana cambia donde se guarda, cambia
/// este archivo y nada mas.
class AuthRepository {
  const AuthRepository(this._api, this._almacen);

  final ApiClient _api;
  final AlmacenSeguro _almacen;

  // ------------------------------------------------------------------
  // Emision de token
  // ------------------------------------------------------------------

  /// `POST /auth/login`.
  ///
  /// Los cuatro rechazos posibles —credencial incorrecta, cuenta de baja,
  /// cinco intentos fallidos y cuenta de gestion— llegan como 422 sobre el
  /// campo `email`, o sea como [ErrorValidacion]. No se distinguen aca ni
  /// hace falta: el backend ya escribio el mensaje que corresponde a cada
  /// uno y la pantalla lo muestra debajo del campo.
  Future<Sesion> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
        'dispositivo': nombreDelDispositivo(),
      }),
    );

    return _guardar(_sesionDe(respuesta.data, '/auth/login'));
  }

  /// `POST /auth/registro` → 201.
  ///
  /// Los campos son los de `RegistroClienteRequest`: el backend reutiliza el
  /// mismo FormRequest del alta web, asi que las claves de los errores de
  /// validacion son exactamente estos nombres.
  ///
  /// El token se emite aunque el correo no este verificado. Eso es
  /// deliberado del backend: sin token la app no podria ni mostrar el perfil
  /// ni pedir el reenvio, y el cliente quedaria en una pantalla sin salida.
  Future<Sesion> registrar({
    required String nombres,
    required String apellido,
    required String email,
    required String password,
    required String passwordConfirmation,
    required int tipoDocumentoId,
    required String nroDoc,
    required int condicionIvaId,
    String? razonSocial,
    String? telefono,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.post('/auth/registro', data: {
        'nombres': nombres.trim(),
        'apellido': apellido.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'tipo_documento_id': tipoDocumentoId,
        'nro_doc': nroDoc.trim(),
        'condicion_iva_id': condicionIvaId,
        // El backend los acepta nullable y completa razon_social con
        // "Apellido Nombres" si va vacia. Se mandan solo si hay algo.
        if (_hayTexto(razonSocial)) 'razon_social': razonSocial!.trim(),
        if (_hayTexto(telefono)) 'telefono': telefono!.trim(),
        'dispositivo': nombreDelDispositivo(),
      }),
    );

    return _guardar(_sesionDe(respuesta.data, '/auth/registro'));
  }

  // ------------------------------------------------------------------
  // Sesion en curso
  // ------------------------------------------------------------------

  /// `GET /auth/yo`.
  ///
  /// **Aca el usuario viene bajo `data`**, al reves que en login y registro:
  /// el controlador devuelve el Resource directo y Laravel lo envuelve.
  ///
  /// Es la llamada que valida el token al arrancar la app. Puede fallar con
  /// [ErrorSesionVencida] (401: vencido o revocado) o [ErrorAccesoDenegado]
  /// (403: `api.ambito` rechazando una cuenta que paso a gestion despues de
  /// que se emitio el token). Quien decide que hacer con eso es el notifier,
  /// no este metodo.
  Future<Usuario> usuarioActual() async {
    final respuesta = await _api.enviar((dio) => dio.get('/auth/yo'));

    final cuerpo = comoMapa(respuesta.data);
    final usuario = comoMapa(cuerpo?['data']);

    if (usuario == null) {
      throw ErrorFormato(
        'La respuesta de /auth/yo no trae la clave "data" con el usuario. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return Usuario.fromJson(usuario);
  }

  /// `POST /auth/logout`. Revoca el token de ESTE dispositivo.
  ///
  /// El almacenamiento se limpia pase lo que pase con la llamada. Si el
  /// telefono esta sin red, el token sigue vivo del lado del servidor hasta
  /// que venza, pero dejarlo guardado seria peor: el usuario apretó cerrar
  /// sesion y tiene que quedar cerrada en el aparato que tiene en la mano.
  Future<void> cerrarSesion() async {
    try {
      await _api.enviar((dio) => dio.post('/auth/logout'));
    } finally {
      await _almacen.borrarToken();
    }
  }

  /// `POST /auth/verificacion/reenviar`. Devuelve el texto que manda Laravel,
  /// que distingue "ya está verificado" de "te lo reenviamos".
  Future<String> reenviarVerificacion() async {
    final respuesta = await _api.enviar(
      (dio) => dio.post('/auth/verificacion/reenviar'),
    );

    final cuerpo = comoMapa(respuesta.data);
    final mensaje = comoTextoOpcional(cuerpo?['message']);

    return mensaje ?? 'Te reenviamos el correo de verificación.';
  }

  // ------------------------------------------------------------------
  // Token guardado
  // ------------------------------------------------------------------

  Future<String?> tokenGuardado() => _almacen.leerToken();

  /// Fecha de vencimiento guardada, para no gastar una llamada en un token
  /// que ya sabemos muerto.
  Future<DateTime?> expiracionGuardada() => _almacen.leerExpiracion();

  /// Borra el token local. Lo usa el notifier cuando el servidor dice que la
  /// sesion ya no vale (401 o 403), sin pasar por `/auth/logout`: no tiene
  /// sentido revocar un token que el servidor ya rechazo.
  Future<void> olvidarSesion() => _almacen.borrarToken();

  // ------------------------------------------------------------------
  // Auxiliares
  // ------------------------------------------------------------------

  Future<Sesion> _guardar(Sesion sesion) async {
    await _almacen.guardarToken(sesion.token, expiraEl: sesion.expiraEl);
    return sesion;
  }

  Sesion _sesionDe(dynamic cuerpo, String ruta) {
    final mapa = comoMapa(cuerpo);

    if (mapa == null) {
      throw ErrorFormato(
        'La respuesta de $ruta no es un objeto JSON. '
        'Llego: ${_recorte(cuerpo)}',
      );
    }

    try {
      return Sesion.fromJson(mapa);
    } on FormatException catch (e) {
      throw ErrorFormato('La respuesta de $ruta no tiene la forma esperada. ${e.message}');
    }
  }

  static bool _hayTexto(String? valor) =>
      valor != null && valor.trim().isNotEmpty;
}

String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
