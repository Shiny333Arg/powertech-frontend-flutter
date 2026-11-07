import 'conversiones.dart';
import 'opcion_fiscal.dart';

/// Los datos fiscales del cliente, tal como los arma `UsuarioResource`.
///
/// Tres cosas pueden faltar por separado y el Resource lo documenta:
/// `razonSocial`, `telefono`, y cada una de las dos referencias fiscales.
/// `CheckoutService::problemaDeFacturacion()` bloquea la compra justamente
/// cuando falta `condicionIva` o `tipoDocumento`, asi que modelarlas como no
/// nulas haria imposible mostrar el motivo.
class Cliente {
  const Cliente({
    required this.id,
    required this.nroDoc,
    this.razonSocial,
    this.telefono,
    this.tipoDocumento,
    this.condicionIva,
  });

  final int id;
  final String nroDoc;
  final String? razonSocial;
  final String? telefono;
  final OpcionFiscal? tipoDocumento;
  final OpcionFiscal? condicionIva;

  /// Replica la regla de `problemaDeFacturacion()` en su parte mas simple:
  /// sin estos dos campos no se puede facturar. La regla completa —la del
  /// responsable inscripto sin CUIT— la sigue decidiendo el backend; esto
  /// solo sirve para anticipar el aviso en la app.
  bool get tieneDatosParaFacturar =>
      tipoDocumento != null && condicionIva != null;

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: comoEntero(json['id']),
      nroDoc: comoTexto(json['nro_doc']),
      razonSocial: comoTextoOpcional(json['razon_social']),
      telefono: comoTextoOpcional(json['telefono']),
      tipoDocumento: _opcion(json['tipo_documento']),
      condicionIva: _opcion(json['condicion_iva']),
    );
  }

  static OpcionFiscal? _opcion(dynamic crudo) {
    final mapa = comoMapa(crudo);
    return mapa == null ? null : OpcionFiscal.fromJson(mapa);
  }
}
