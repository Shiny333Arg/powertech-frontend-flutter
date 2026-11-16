import '../../core/almacenamiento.dart';
import '../../core/api_client.dart';
import '../../core/dispositivo.dart';
import '../../core/errores.dart';
import '../modelos/conversiones.dart';
import '../modelos/sesion.dart';
import '../modelos/usuario.dart';

/// Los endpoints de sesion, mas los dos de contraseña olvidada.
///
/// **Es el unico lugar que escribe en [AlmacenSeguro].** Ni los providers ni
/// las pantallas tocan el token: si manana cambia donde se guarda, cambia
/// este archivo y nada mas.
///
/// **Los dos metodos de recuperacion son los unicos que no tocan el
/// almacenamiento, y es la propiedad que los define.** Estan en esta clase
/// porque pegan a `/auth/...` y porque la pantalla de login es la que los
/// llama, no porque participen de la sesion: no leen el token guardado, no
/// escriben uno y no devuelven [Sesion]. Ver el bloque de mas abajo.
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
  // Contraseña olvidada
  // ------------------------------------------------------------------
  //
  // Las dos rutas son PUBLICAS: quien olvido la contraseña no puede iniciar
  // sesion, asi que no hay token que mandar. El interceptor de [ApiClient]
  // adjunta el guardado si existe y no pasa nada: la ruta no tiene
  // `auth:sanctum`, asi que Laravel lo ignora igual que en el catalogo.
  //
  // **Ninguno de los dos escribe en [AlmacenSeguro] y eso no es un olvido.**
  // El token que viaja en `restablecerPassword` es el del correo, no un token
  // de Sanctum: es de un solo uso, vence a los 60 minutos y no autentica
  // ninguna otra llamada. Guardarlo seria tratar un enlace de correo como una
  // credencial de sesion.
  //
  // **Tampoco inician sesion.** El backend no devuelve token ni usuario, igual
  // que la web, que redirige al login. Cambiar la contraseña y quedar adentro
  // son dos cosas distintas y el cliente hace la segunda escribiendola.

  /// `POST /auth/password/olvide`.
  ///
  /// Pide el correo con el enlace de recuperacion. Devuelve el mensaje que
  /// escribio el backend.
  ///
  /// **Un 200 no significa que el correo exista.** El backend contesta lo
  /// mismo para una cuenta real, para una inexistente y para una dada de
  /// baja: si contestara distinto, este endpoint —que es publico— serviria
  /// para averiguar quien tiene cuenta en PowerTech. La pantalla tiene que
  /// mostrar el mensaje tal cual y no interpretarlo como "el correo era
  /// bueno".
  ///
  /// Lo que si puede fallar: [ErrorValidacion] si el correo esta mal escrito
  /// (422 sobre el campo `email`) y [ErrorDemasiadosIntentos] si se pidio
  /// demasiadas veces (429, `throttle:6,1`).
  Future<String> solicitarEnlaceDeRecuperacion({required String email}) async {
    final respuesta = await _api.enviar(
      (dio) => dio.post<dynamic>('/auth/password/olvide', data: <String, dynamic>{
        'email': email.trim(),
      }),
    );

    final cuerpo = comoMapa(respuesta.data);

    return comoTextoOpcional(cuerpo?['message']) ??
        'Si el correo corresponde a una cuenta de PowerTech, te enviamos un '
            'enlace para elegir una contraseña nueva.';
  }

  /// `POST /auth/password/restablecer`.
  ///
  /// Escribe la contraseña nueva usando el token del correo. Devuelve el
  /// mensaje de confirmacion del backend.
  ///
  /// **El enlace invalido llega como [ErrorValidacion] sobre `email`**, no
  /// como [ErrorSesionVencida] ni [ErrorAccesoDenegado]. Es a proposito del
  /// backend: un 401 dispararia el circuito de relogueo de la app, y aca no
  /// hay sesion que haya vencido. Token equivocado, token vencido, token ya
  /// usado y correo inexistente dan todos el mismo mensaje, por el mismo
  /// motivo que el `olvide` no distingue correos.
  ///
  /// Las reglas de la contraseña son las del backend (`Password::defaults()`,
  /// hoy 8 caracteres) y un incumplimiento vuelve como 422 sobre `password`.
  Future<String> restablecerPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.post<dynamic>(
        '/auth/password/restablecer',
        data: <String, dynamic>{
          'token': token.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      ),
    );

    final cuerpo = comoMapa(respuesta.data);

    return comoTextoOpcional(cuerpo?['message']) ??
        'Listo, cambiamos tu contraseña. Ya podés ingresar con la nueva.';
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
