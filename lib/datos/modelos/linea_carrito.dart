import 'conversiones.dart';
import 'producto.dart';

/// Una línea del carrito. Espejo de `CarritoLineaResource`.
///
/// **Los importes son `double` y no `double?`, al revés que en [Producto].**
/// La diferencia es real y vale la pena entenderla: el catálogo es público y
/// al invitado no le llega el bloque de precio, por eso allá `precio` tiene
/// que ser opcional. El carrito, en cambio, está detrás de `auth:sanctum` y
/// `api.verificado`: no existe un visitante sin precio que pueda llegar acá.
/// Si falta un importe no es un invitado, es un contrato roto, y un 0 se ve
/// enseguida.
///
/// Para una línea no disponible el backend manda los importes en 0 por su
/// cuenta: no es un default de la app, es el valor que eligió el servidor
/// para que esa línea no sume.
///
/// **Las dos preguntas sobre preventa son distintas y las dos vienen
/// resueltas.** [enPreventa] es del PRODUCTO —no queda ninguna unidad libre,
/// `stock_disponible <= 0`— y es exactamente el mismo campo que trae el
/// catálogo. [unidadesEnPreventa] es de la LÍNEA: cuántas de las que el
/// cliente pidió no están hoy en el depósito. Un producto con 3 disponibles y
/// una línea de 5 llega con `enPreventa: false` y `unidadesEnPreventa: 2`.
/// Ninguna de las dos se deriva acá.
class LineaCarrito {
  const LineaCarrito({
    required this.id,
    required this.productoId,
    required this.cantidad,
    required this.disponible,
    required this.stockDisponible,
    required this.enPreventa,
    required this.unidadesEnPreventa,
    required this.precioUnitario,
    required this.precioUnitarioFinal,
    required this.subtotal,
    this.producto,
    this.motivoNoDisponible,
    this.tieneDescuento = false,
    this.porcentajeDescuento = 0,
  });

  /// Id de la línea, no del producto. **Es el que va en la URL** de
  /// `PATCH /carrito/{linea}` y `DELETE /carrito/{linea}`.
  final int id;

  final int productoId;

  /// Entre 1 y 99. El backend rechaza 0: quitar es `DELETE`, no cantidad cero.
  final int cantidad;

  /// El mismo `ProductoResource` del catálogo, con su bloque de precio ya
  /// descontado. Se reusa el modelo tal cual: [Producto] parsea este objeto
  /// sin adaptadores, así que `ImagenRemota` y `PrecioProducto` funcionan
  /// sobre él.
  ///
  /// Null solo si el producto desapareció de la base, que
  /// `ProtegeContraBorrado` impide. La línea sigue siendo válida y quitable.
  final Producto? producto;

  /// El producto se sigue vendiendo en la tienda (`activo` y `publicado_app`).
  ///
  /// Cuando es false la línea **igual se muestra**: el cliente tiene que poder
  /// verla para quitarla. Lo que no hace es sumar al total.
  final bool disponible;

  /// Texto listo para mostrar. Null cuando [disponible] es true.
  final String? motivoNoDisponible;

  /// Unidades libres hoy. 0 cuando la línea no está disponible.
  final int stockDisponible;

  /// Del PRODUCTO: `stock_disponible <= 0`.
  final bool enPreventa;

  /// De la LÍNEA: cuántas unidades pedidas no están en el depósito.
  ///
  /// **Preventa no bloquea nada.** No saca la línea del total, no impide
  /// agregar y no baja `puedeComprar`. Es informativa.
  final int unidadesEnPreventa;

  final double precioUnitario;

  /// Con las promociones vigentes aplicadas. Igual al de lista si no hay
  /// descuento.
  final double precioUnitarioFinal;

  final bool tieneDescuento;

  /// Entero ya redondeado por el backend, con el mismo cálculo que el
  /// catálogo y la web.
  final int porcentajeDescuento;

  /// `precioUnitarioFinal × cantidad`, calculado por el backend. 0 si la
  /// línea no está disponible.
  final double subtotal;

  /// Nombre para mostrar aunque el producto no haya venido.
  String get nombre => producto?.nombre ?? 'Producto #$productoId';

  /// Si esta línea pide unidades que todavía no están en el depósito.
  bool get requierePreventa => unidadesEnPreventa > 0;

  /// Cuánto ahorra esta línea, para poder mostrar "ahorrás $X".
  ///
  /// Se obtiene restando dos importes que **los dos calculó el backend**: no
  /// se aplica ningún porcentaje ni se resuelve ninguna promoción acá.
  double? get ahorro {
    if (!tieneDescuento || precioUnitarioFinal >= precioUnitario) return null;

    return (precioUnitario - precioUnitarioFinal) * cantidad;
  }

  factory LineaCarrito.fromJson(Map<String, dynamic> json) {
    final producto = comoMapa(json['producto']);

    return LineaCarrito(
      id: comoEntero(json['id']),
      productoId: comoEntero(json['producto_id']),
      cantidad: comoEntero(json['cantidad']),
      producto: producto == null ? null : Producto.fromJson(producto),
      disponible: comoBool(json['disponible']),
      motivoNoDisponible: comoTextoOpcional(json['motivo_no_disponible']),
      stockDisponible: comoEntero(json['stock_disponible']),
      enPreventa: comoBool(json['en_preventa']),
      unidadesEnPreventa: comoEntero(json['unidades_en_preventa']),
      precioUnitario: comoDecimalOpcional(json['precio_unitario']) ?? 0,
      precioUnitarioFinal:
          comoDecimalOpcional(json['precio_unitario_final']) ?? 0,
      tieneDescuento: comoBool(json['tiene_descuento']),
      porcentajeDescuento: comoEnteroOpcional(json['porcentaje_descuento']) ?? 0,
      subtotal: comoDecimalOpcional(json['subtotal']) ?? 0,
    );
  }

  static List<LineaCarrito> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(LineaCarrito.fromJson)
        .toList();
  }
}
