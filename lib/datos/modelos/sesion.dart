import 'conversiones.dart';
import 'usuario.dart';

/// Lo que devuelven `/auth/login` (200) y `/auth/registro` (201).
///
/// Las dos respuestas tienen la misma forma y el `usuario` viene **plano**,
/// sin el envoltorio `data`: `respuestaConToken()` anida el Resource dentro
/// de un `response()->json([...])` y un Resource anidado no se envuelve.
/// `/auth/yo`, en cambio, devuelve el Resource directo y ahi Laravel si pone
/// el `data`. Esa asimetria la resuelve el repositorio, no este modelo.
class Sesion {
  const Sesion({
    required this.token,
    required this.usuario,
    this.expiraEl,
  });

  final String token;
  final Usuario usuario;

  /// `?->toIso8601String()` en el controlador: puede ser null si el token se
  /// emitio sin vencimiento. Hoy `config('movil.token_dias')` siempre pone
  /// uno, pero el contrato admite que no.
  final DateTime? expiraEl;

  factory Sesion.fromJson(Map<String, dynamic> json) {
    final usuario = comoMapa(json['usuario']);

    if (usuario == null) {
      throw const FormatException('La respuesta no trae el objeto "usuario".');
    }

    return Sesion(
      token: comoTexto(json['token']),
      expiraEl: comoFechaOpcional(json['expira_el']),
      usuario: Usuario.fromJson(usuario),
    );
  }
}
