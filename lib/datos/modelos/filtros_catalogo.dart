import 'conversiones.dart';

/// Una opción de orden, tal como la ofrece el backend: `{valor, etiqueta}`.
///
/// **La lista la dicta la respuesta, nunca la app.** `ordenesDisponibles()`
/// recorta las dos opciones de precio cuando el visitante no puede verlas: en
/// el JSON del invitado llegan cuatro y en el del cliente seis. Tener acá un
/// enum con los seis casos obligaría a decidir en Flutter cuáles mostrar, que
/// es justo lo que el backend ya decidió.
class OpcionOrden {
  const OpcionOrden({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  factory OpcionOrden.fromJson(Map<String, dynamic> json) {
    return OpcionOrden(
      valor: comoTexto(json['valor']),
      etiqueta: comoTexto(json['etiqueta']),
    );
  }

  static List<OpcionOrden> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(OpcionOrden.fromJson)
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OpcionOrden && other.valor == valor);

  @override
  int get hashCode => valor.hashCode;
}

/// Los siete filtros de `GET /productos`, con los nombres exactos del
/// querystring que acepta `BusquedaProductoRequest`.
///
/// Esta clase se usa para dos cosas distintas y conviene tenerlas separadas en
/// la cabeza:
///
///  - **lo que la app pide**: lo que el usuario eligió en la pantalla de
///    filtros;
///  - **lo que el backend aplicó**: el bloque `filtros` de la respuesta.
///
/// No son lo mismo. Para un invitado, `precio_min`, `precio_max` y un orden
/// por precio vuelven cambiados: el rango en null y el orden en `relevancia`.
/// La pantalla se reconstruye siempre desde lo aplicado, así que nunca queda
/// sosteniendo un filtro que el servidor descartó.
///
/// **La app no valida ninguno de estos valores.** `BusquedaProductoRequest`
/// sanea en lugar de rechazar: recorta largos, da vuelta un min mayor que el
/// max y manda cualquier orden desconocido a relevancia. Repetir esas reglas
/// acá sería un segundo lugar decidiendo lo mismo.
class FiltrosCatalogo {
  const FiltrosCatalogo({
    this.q,
    this.categoriaId,
    this.marca,
    this.precioMin,
    this.precioMax,
    this.promocionId,
    this.orden,
  });

  /// Término de búsqueda. El backend lo recorta a 255.
  final String? q;

  final int? categoriaId;

  /// Texto libre, no una tabla: `marcasDisponibles()` lo saca con `distinct()`
  /// sobre la columna. El backend compara por igualdad exacta, así que acá va
  /// el valor tal como vino de `/marcas`.
  final String? marca;

  final double? precioMin;
  final double? precioMax;

  final int? promocionId;

  /// El `value` de `OrdenCatalogo`: `relevancia`, `precio-asc`, `precio-desc`,
  /// `nombre-asc`, `nombre-desc` o `recientes`. null deja decidir al backend,
  /// que cae en relevancia.
  final String? orden;

  /// Si hay algún filtro puesto además del término de búsqueda y el orden.
  /// Es lo que decide si el botón de filtros muestra un indicador.
  bool get hayFiltrosDeRefinamiento =>
      categoriaId != null ||
      marca != null ||
      precioMin != null ||
      precioMax != null ||
      promocionId != null;

  /// Cuántos chips hay para mostrar arriba de la grilla.
  int get cantidadActivos => [
        q,
        categoriaId,
        marca,
        precioMin,
        precioMax,
        promocionId,
      ].where((v) => v != null).length;

  bool get estaVacio => cantidadActivos == 0 && orden == null;

  /// El querystring que recibe Dio. **Las claves nulas no se incluyen**: una
  /// clave presente con valor vacío no es lo mismo que una clave ausente, y
  /// `aTexto()` del Request trataría `''` como "no filtró" pero igual
  /// aparecería en el `filtros` de la respuesta.
  Map<String, dynamic> aQueryString({int? pagina}) {
    return {
      if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
      if (categoriaId != null) 'categoria': categoriaId,
      if (marca != null && marca!.isNotEmpty) 'marca': marca,
      if (precioMin != null) 'precio_min': precioMin,
      if (precioMax != null) 'precio_max': precioMax,
      if (promocionId != null) 'promocion': promocionId,
      if (orden != null) 'orden': orden,
      if (pagina != null && pagina > 1) 'page': pagina,
    };
  }

  /// El bloque `filtros` de la respuesta: lo que el backend aplicó de verdad.
  factory FiltrosCatalogo.fromJson(Map<String, dynamic> json) {
    return FiltrosCatalogo(
      q: comoTextoOpcional(json['q']),
      categoriaId: comoEnteroOpcional(json['categoria']),
      marca: comoTextoOpcional(json['marca']),
      precioMin: comoDecimalOpcional(json['precio_min']),
      precioMax: comoDecimalOpcional(json['precio_max']),
      promocionId: comoEnteroOpcional(json['promocion']),
      orden: comoTextoOpcional(json['orden']),
    );
  }

  /// Copia con cambios. Los `bool limpiar*` existen porque con un parámetro
  /// opcional no se puede distinguir "no lo toqués" de "ponelo en null", y
  /// quitar un filtro es exactamente ponerlo en null.
  FiltrosCatalogo copiarCon({
    String? q,
    int? categoriaId,
    String? marca,
    double? precioMin,
    double? precioMax,
    int? promocionId,
    String? orden,
    bool limpiarQ = false,
    bool limpiarCategoria = false,
    bool limpiarMarca = false,
    bool limpiarPrecioMin = false,
    bool limpiarPrecioMax = false,
    bool limpiarPromocion = false,
    bool limpiarOrden = false,
  }) {
    return FiltrosCatalogo(
      q: limpiarQ ? null : (q ?? this.q),
      categoriaId: limpiarCategoria ? null : (categoriaId ?? this.categoriaId),
      marca: limpiarMarca ? null : (marca ?? this.marca),
      precioMin: limpiarPrecioMin ? null : (precioMin ?? this.precioMin),
      precioMax: limpiarPrecioMax ? null : (precioMax ?? this.precioMax),
      promocionId: limpiarPromocion ? null : (promocionId ?? this.promocionId),
      orden: limpiarOrden ? null : (orden ?? this.orden),
    );
  }

  /// Quita todo menos la promoción y el término.
  ///
  /// La promoción se conserva porque es el contexto de la pantalla, no un
  /// filtro que el usuario puso: si entró por un banner, "limpiar filtros" no
  /// tiene que sacarlo del listado de esa promoción.
  FiltrosCatalogo limpiarRefinamientos() {
    return FiltrosCatalogo(q: q, promocionId: promocionId, orden: orden);
  }
}
