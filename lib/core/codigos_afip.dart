/// Códigos de ARCA que la app usa **solo para ayudar a escribir**, nunca
/// para decidir si un dato es válido.
///
/// Son los mismos tres de `ReglasDatosCliente`, y esa sigue siendo la
/// autoridad: lo que hace la app con estos números es poner el teclado
/// numérico, limitar el largo del campo y adelantar un aviso. Si el usuario
/// ignora el aviso y manda igual, el 422 de Laravel es el que manda.
///
/// No son ids de la base: son códigos nacionales, estables, y llegan en cada
/// respuesta de `/datos-fiscales`. Lo que nunca se escribe acá es un `id`.
class CodigosAfip {
  const CodigosAfip._();

  /// Tipo de documento: CUIT. Once dígitos.
  static const int cuit = 80;

  /// Tipo de documento: DNI. Siete u ocho dígitos.
  static const int dni = 96;

  /// Condición frente al IVA: consumidor final. Es la única que
  /// `validarCoherenciaFiscal()` deja combinar con DNI.
  static const int consumidorFinal = 5;

  /// Largo máximo para el campo de documento. `nro_doc` es varchar(20) en la
  /// base, así que ese es el techo cuando no sabemos más.
  static int largoMaximo(int? codigoDocumento) {
    if (codigoDocumento == cuit) return 11;
    if (codigoDocumento == dni) return 8;
    return 20;
  }

  /// Texto de ayuda bajo el campo de documento.
  static String? ayudaDocumento(int? codigoDocumento) {
    if (codigoDocumento == cuit) return 'Once dígitos, sin guiones.';
    if (codigoDocumento == dni) return 'Siete u ocho dígitos, sin puntos.';
    return null;
  }

  /// Aviso que la app puede mostrar antes de enviar. Es la misma regla que
  /// `validarCoherenciaFiscal()` verifica del lado del servidor; acá solo se
  /// adelanta para no hacer ir y volver el formulario.
  ///
  /// Devuelve null cuando no hay nada que advertir o cuando falta
  /// información para opinar.
  static String? avisoCoherenciaFiscal({
    required int? codigoDocumento,
    required int? codigoIva,
  }) {
    if (codigoDocumento == null || codigoIva == null) return null;
    if (codigoIva == consumidorFinal) return null;
    if (codigoDocumento == cuit) return null;

    return 'Con esa condición frente al IVA vas a tener que identificarte '
        'con tu CUIT.';
  }
}
