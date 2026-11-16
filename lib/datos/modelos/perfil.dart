import 'cliente.dart';
import 'conversiones.dart';
import 'usuario.dart';

/// Lo que el formulario de perfil necesita: `GET /api/v1/perfil`. Espejo de
/// `PerfilResource`.
///
/// **El usuario viene con el mismo contrato que `/auth/yo`**, así que se
/// parsea con el [Usuario] que ya existía y no con un segundo modelo. No es
/// sólo comodidad: dos formas del usuario terminarían mostrando datos
/// distintos en "Mi cuenta" y en el formulario que los edita.
///
/// **Lo único que este endpoint agrega es [documentoBloqueado]**, y es la
/// razón de que exista: `/auth/yo` no lo trae porque es una consulta a
/// `ventas` y esa ruta corre en cada arranque de la app.
///
/// Las listas desplegables no vienen acá: ya las sirve `/datos-fiscales`, que
/// la app consume con `datosFiscalesProvider` desde el registro.
class Perfil {
  const Perfil({
    required this.usuario,
    required this.documentoBloqueado,
    required this.tienePassword,
    this.motivoDocumentoBloqueado,
  });

  final Usuario usuario;

  /// La cuenta ya tiene una contraseña elegida.
  ///
  /// **Es un booleano, no la contraseña.** Decide si el formulario pide la
  /// contraseña actual para poder cambiarla: `users.password` es nullable, y
  /// quien se registró con Google todavía no eligió una, así que la primera
  /// que elija la crea.
  ///
  /// Hoy llega siempre en true, porque el login de la app es correo más
  /// contraseña y una cuenta sin contraseña no puede entrar. Se respeta igual:
  /// es la misma condición que evalúa el backend.
  final bool tienePassword;

  /// El tipo y el número de documento no se pueden editar.
  ///
  /// **Lo decide el backend.** La app no lo deduce de "tiene compras": no
  /// tiene por qué conocer la regla, y el historial puede verse vacío en
  /// pantalla mientras la cuenta tiene una compra de mostrador.
  final bool documentoBloqueado;

  /// Por qué está bloqueado, en texto listo para mostrar. null cuando no lo
  /// está: la app pregunta por el texto y no por la bandera.
  final String? motivoDocumentoBloqueado;

  /// null cuando la cuenta no tiene ficha en `clientes`. En ese caso no hay
  /// datos fiscales que editar —el backend rechaza el PATCH— y la pantalla
  /// muestra el aviso en lugar del formulario.
  Cliente? get cliente => usuario.cliente;

  bool get tieneFichaDeCliente => usuario.cliente != null;

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      usuario: Usuario.fromJson(comoMapa(json['usuario']) ?? const {}),
      documentoBloqueado: comoBool(json['documento_bloqueado']),
      motivoDocumentoBloqueado:
          comoTextoOpcional(json['motivo_documento_bloqueado']),
      // Ante una clave ausente se asume que sí tiene contraseña: es lo que
      // vale para toda cuenta que pueda haber entrado a la app, y pedir la
      // actual de más es preferible a dejar cambiarla sin confirmarla.
      tienePassword: json['tiene_password'] == null
          ? true
          : comoBool(json['tiene_password']),
    );
  }
}

/// El resultado de `PATCH /api/v1/perfil`.
///
/// **Trae el perfil completo y no un "ok".** Importa en un caso concreto: si
/// cambió el correo, el backend baja `email_verificado` a false y el carrito y
/// el checkout quedan bloqueados hasta que el cliente confirme la dirección
/// nueva. Una respuesta sin datos dejaría a la app creyendo que puede comprar.
///
/// También trae el `razon_social` que el backend completó solo cuando se
/// manda vacío ("Apellido Nombres"), así que el formulario puede mostrar el
/// valor real que quedó guardado.
class PerfilGuardado {
  const PerfilGuardado({
    required this.perfil,
    required this.mensaje,
    required this.emailReverificacionPendiente,
  });

  final Perfil perfil;

  /// Qué decirle al cliente. **Lo escribe el backend**, porque depende de si
  /// cambió el correo: no es lo mismo "guardamos tus datos" que "te mandamos
  /// un enlace a tu correo nuevo".
  final String mensaje;

  /// El correo cambió y hay una verificación pendiente. Viaja como bandera
  /// para que la app no tenga que comparar el correo anterior con el nuevo.
  final bool emailReverificacionPendiente;
}
