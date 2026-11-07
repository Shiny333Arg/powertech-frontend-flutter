import 'cliente.dart';
import 'conversiones.dart';

/// El usuario tal como lo devuelve `UsuarioResource`.
///
/// No trae rol ni permisos y es deliberado del lado del backend: la app de la
/// tienda no tiene pantallas que mostrar u ocultar segun el rol, y el ambito
/// ya lo garantiza el middleware `api.ambito:tienda`.
///
/// `cliente` puede ser null. No deberia pasar en una cuenta nacida del
/// registro, pero la tabla lo admite y la app tiene que poder distinguir
/// "cuenta sin cliente" de "cliente con datos incompletos".
class Usuario {
  const Usuario({
    required this.id,
    required this.nombres,
    required this.apellido,
    required this.nombreCompleto,
    required this.email,
    required this.emailVerificado,
    this.cliente,
  });

  final int id;
  final String nombres;
  final String apellido;
  final String nombreCompleto;
  final String email;

  /// Segundo de los tres estados del plan: el cliente existe y tiene token,
  /// pero carrito y checkout lo van a rechazar por el middleware `verified`.
  /// Viene en el Resource para poder mostrar la pantalla correcta antes de
  /// chocar con el 403.
  final bool emailVerificado;

  final Cliente? cliente;

  /// Puede pasar al carrito y al checkout.
  bool get puedeComprar => emailVerificado && cliente != null;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final cliente = comoMapa(json['cliente']);

    return Usuario(
      id: comoEntero(json['id']),
      nombres: comoTexto(json['nombres']),
      apellido: comoTexto(json['apellido']),
      nombreCompleto: comoTexto(json['nombre_completo']),
      email: comoTexto(json['email']),
      emailVerificado: comoBool(json['email_verificado']),
      cliente: cliente == null ? null : Cliente.fromJson(cliente),
    );
  }
}
