import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/conversiones.dart';
import '../modelos/perfil.dart';

/// Perfil del cliente: `/api/v1/perfil`.
///
/// **Las tres rutas exigen sesión** (`auth:sanctum` + `api.activo` +
/// `api.ambito:tienda`) y **ninguna exige correo verificado**, a diferencia
/// del carrito. Es deliberado del backend y replica la web: si editar el
/// perfil pidiera el correo confirmado, un cliente que se equivocó al
/// escribirlo al registrarse no podría corregirlo nunca.
///
/// **Nunca se manda un id.** Ni en la URL ni en el cuerpo: el perfil es
/// siempre el de quien trae el token. No hay nada que manipular para editar
/// otra cuenta, y los FormRequest del backend usan listas blancas de columnas,
/// así que un `user_id` de más tampoco haría nada.
///
/// Errores que pueden salir de acá:
///
///   401                      sesión vencida, revocada o cuenta de baja
///   403 sin codigo            cuenta de gestión
///   403 sin_ficha_de_cliente  la cuenta no tiene fila en `clientes`
///   422                       validación, con los nombres de campo de
///                             `ReglasDatosCliente`
///
/// El último llega como [ErrorAccesoDenegado] con el mensaje del backend, que
/// explica que hay que acercarse al local. No se le dio una clase propia
/// porque la pantalla no debería llegar nunca: `ver()` devuelve
/// `usuario.cliente` en null y el formulario no se dibuja.
class PerfilRepository {
  const PerfilRepository(this._api);

  final ApiClient _api;

  /// GET /perfil
  Future<Perfil> ver() async {
    final respuesta = await _api.enviar((dio) => dio.get<dynamic>('/perfil'));

    return _leer(respuesta.data, 'GET /perfil');
  }

  /// PATCH /perfil
  ///
  /// Los nombres de los campos son los de `ProfileUpdateRequest`, que la API
  /// hereda sin modificar: son las mismas claves con las que vuelven los
  /// errores de validación, así que la pantalla las usa tal cual para ubicar
  /// cada mensaje debajo de su campo.
  ///
  /// **`telefono` y `razon_social` se mandan siempre, incluso vacíos.** Es lo
  /// que hace el formulario web y es lo que permite BORRAR un teléfono ya
  /// cargado: omitir la clave dejaría el valor anterior. Laravel convierte la
  /// cadena vacía en null con `ConvertEmptyStringsToNull`, y con
  /// `razon_social` vacía el backend la completa con "Apellido Nombres".
  ///
  /// **El documento se manda igual cuando está bloqueado.** También es lo que
  /// hace la web, con un input oculto: el backend compara contra lo guardado y
  /// rechaza el cambio si difiere. Mandar los valores actuales no es un
  /// intento de cambio.
  Future<PerfilGuardado> actualizar({
    required String nombres,
    required String apellido,
    required String email,
    required int tipoDocumentoId,
    required String nroDoc,
    required int condicionIvaId,
    required String telefono,
    required String razonSocial,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.patch<dynamic>('/perfil', data: <String, dynamic>{
        'nombres': nombres.trim(),
        'apellido': apellido.trim(),
        'email': email.trim(),
        'tipo_documento_id': tipoDocumentoId,
        'nro_doc': nroDoc.trim(),
        'condicion_iva_id': condicionIvaId,
        'telefono': telefono.trim(),
        'razon_social': razonSocial.trim(),
      }),
    );

    final cuerpo = comoMapa(respuesta.data);

    return PerfilGuardado(
      perfil: _leer(respuesta.data, 'PATCH /perfil'),
      mensaje: comoTextoOpcional(cuerpo?['message']) ??
          'Listo, guardamos tus datos.',
      emailReverificacionPendiente:
          comoBool(cuerpo?['email_reverificacion_pendiente']),
    );
  }

  /// PUT /perfil/password
  ///
  /// Devuelve el mensaje que escribió el backend.
  ///
  /// **`passwordActual` puede ir en null**: un cliente que se registró con
  /// Google todavía no tiene contraseña, y la primera que elige la crea. Quién
  /// está en ese caso lo dice el backend, no la app: la pantalla sólo muestra
  /// el campo cuando corresponde.
  ///
  /// **El token no se revoca ni se renueva.** Cambiar la contraseña no cierra
  /// esta sesión ni las de otros dispositivos, igual que en la web.
  Future<String> cambiarPassword({
    String? passwordActual,
    required String password,
    required String passwordConfirmation,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.put<dynamic>('/perfil/password', data: <String, dynamic>{
        if (passwordActual != null) 'current_password': passwordActual,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final cuerpo = comoMapa(respuesta.data);

    return comoTextoOpcional(cuerpo?['message']) ??
        'Listo, cambiamos tu contraseña.';
  }

  /// Desenvuelve la respuesta y la convierte en [Perfil].
  ///
  /// El controlador devuelve el Resource, así que Laravel lo envuelve en
  /// `data`. Se acepta también el objeto plano, igual que hace el resto de los
  /// repositorios: es una línea y evita que la pantalla deje de abrir por un
  /// cambio de envoltorio.
  Perfil _leer(dynamic cuerpo, String ruta) {
    final raiz = comoMapa(cuerpo);
    final datos = comoMapa(raiz?['data']) ?? raiz;

    // `usuario` es la clave que siempre viene. Si no está, lo que volvió no es
    // esta API: casi siempre HTML de la web Blade o el aviso de ngrok.
    if (datos == null || datos['usuario'] is! Map) {
      throw ErrorFormato(
        'La respuesta de $ruta no trae el perfil. '
        'Llego: ${_recorte(cuerpo)}',
      );
    }

    return Perfil.fromJson(datos);
  }
}

/// Primeros caracteres del cuerpo, para que el mensaje diga algo util cuando
/// lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
