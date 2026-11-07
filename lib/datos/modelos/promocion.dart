import 'conversiones.dart';

/// Promoción vigente con banner. Espejo de `PromocionResource`.
///
/// **Las promociones también reservan datos de precio, y esto es fácil de
/// pasar por alto.** El contrato tiene un quinto campo oculto además de los
/// cuatro del producto: para el invitado no vienen `tipo`, `tipo_etiqueta`,
/// `unidad` ni `valor`.
///
/// El motivo está en el docblock del resource y es bueno: cuando el tipo es
/// `precio_especial`, `valor` **no** guarda un descuento, guarda el precio
/// final del producto. Publicarlo filtraría el precio exacto de todo lo que
/// esa promoción alcanza. Y como el tipo decide cómo leer la columna, los
/// cuatro campos viajan juntos o no viaja ninguno.
///
/// Lo que sí ve el invitado es la parte editorial: nombre, descripción, banner
/// y vigencia. Alcanza para el carrusel.
class Promocion {
  const Promocion({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.bannerUrl,
    this.vigenciaDesde,
    this.vigenciaHasta,
    this.tipo,
    this.tipoEtiqueta,
    this.unidad,
    this.valor,
  });

  final int id;
  final String nombre;

  /// Texto libre que carga un administrativo. Puede ser null.
  final String? descripcion;

  /// URL absoluta ya armada por el backend. `promocionesVigentes()` solo
  /// devuelve promociones con banner, así que en la práctica no viene null,
  /// pero el contrato lo admite.
  final String? bannerUrl;

  final DateTime? vigenciaDesde;
  final DateTime? vigenciaHasta;

  /// Valor del enum `TipoPromocion` (`porcentaje`, `monto_fijo`,
  /// `precio_especial`). **null para el invitado.**
  final String? tipo;

  /// Etiqueta ya traducida por el enum. **null para el invitado.**
  final String? tipoEtiqueta;

  /// `$` o `%`, según el tipo. **null para el invitado.**
  final String? unidad;

  /// **null para el invitado.** Y cuidado al interpretarlo incluso con
  /// sesión: con `precio_especial` es un precio, no un descuento. Por eso la
  /// app no lo convierte en "X% off" por su cuenta; muestra
  /// [etiquetaDelBeneficio], que respeta la unidad que mandó el backend.
  final double? valor;

  /// Si este visitante recibió el bloque de precio de la promoción.
  bool get tieneDetalleDeBeneficio => valor != null && unidad != null;

  /// "15%" o "$ 15000", con la unidad que dijo el backend. null si el
  /// visitante no puede verlo.
  ///
  /// Deliberadamente **no** dice "de descuento": con `precio_especial` el
  /// número es el precio final, y escribir "descuento" ahí sería mentir. Esa
  /// palabra la pone [tipoEtiqueta], que la escribe el enum del backend.
  String? get etiquetaDelBeneficio {
    final monto = valor;
    if (monto == null || unidad == null) return null;

    final texto = monto == monto.roundToDouble()
        ? monto.toStringAsFixed(0)
        : monto.toStringAsFixed(2).replaceAll('.', ',');

    return unidad == '%' ? '$texto%' : '\$ $texto';
  }

  factory Promocion.fromJson(Map<String, dynamic> json) {
    return Promocion(
      id: comoEntero(json['id']),
      nombre: comoTexto(json['nombre']),
      descripcion: comoTextoOpcional(json['descripcion']),
      bannerUrl: comoTextoOpcional(json['banner_url']),
      vigenciaDesde: comoFechaOpcional(json['vigencia_desde']),
      vigenciaHasta: comoFechaOpcional(json['vigencia_hasta']),

      // El bloque reservado. Ausente = invitado.
      tipo: comoTextoOpcional(json['tipo']),
      tipoEtiqueta: comoTextoOpcional(json['tipo_etiqueta']),
      unidad: comoTextoOpcional(json['unidad']),
      valor: comoDecimalOpcional(json['valor']),
    );
  }

  static List<Promocion> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(Promocion.fromJson)
        .toList();
  }
}
