import 'conversiones.dart';

/// Una fila de `tipos_documento` o de `condiciones_iva`.
///
/// El mismo tipo sirve para dos orígenes con forma distinta, y por eso
/// `codigoAfip` es nullable:
///
///  - dentro de `usuario.cliente`, `UsuarioResource` manda solo
///    `{ id, nombre }`;
///  - en `GET /datos-fiscales` manda además `codigo_afip`.
///
/// Un modelo con `int codigoAfip` y default 0 haría que el formulario creyera
/// que un documento guardado es de un tipo desconocido. Nullable obliga a
/// preguntar.
class OpcionFiscal {
  const OpcionFiscal({
    required this.id,
    required this.nombre,
    this.codigoAfip,
  });

  final int id;
  final String nombre;

  /// Código de ARCA. Solo viene de `/datos-fiscales`.
  final int? codigoAfip;

  factory OpcionFiscal.fromJson(Map<String, dynamic> json) {
    return OpcionFiscal(
      id: comoEntero(json['id']),
      nombre: comoTexto(json['nombre']),
      codigoAfip: comoEnteroOpcional(json['codigo_afip']),
    );
  }

  /// Para `DropdownButtonFormField`, que compara por igualdad.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OpcionFiscal && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => nombre;
}

/// Las dos listas de `GET /api/v1/datos-fiscales`.
class DatosFiscales {
  const DatosFiscales({
    required this.tiposDocumento,
    required this.condicionesIva,
  });

  final List<OpcionFiscal> tiposDocumento;
  final List<OpcionFiscal> condicionesIva;

  factory DatosFiscales.fromJson(Map<String, dynamic> json) {
    return DatosFiscales(
      tiposDocumento: _lista(json['tipos_documento']),
      condicionesIva: _lista(json['condiciones_iva']),
    );
  }

  static List<OpcionFiscal> _lista(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(OpcionFiscal.fromJson)
        .toList();
  }
}
