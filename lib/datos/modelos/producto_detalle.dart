import 'conversiones.dart';
import 'producto.dart';
import 'promocion.dart';

/// Ficha de producto: `GET /api/v1/productos/{id}`.
///
/// `ProductoDetalleResource` **extiende** `ProductoResource`, así que el JSON
/// trae los mismos campos de la tarjeta —incluido el bloque de precio cuando
/// corresponde— y le agrega tres cosas que solo tienen sentido en el detalle.
///
/// Acá se modela por composición y no por herencia: [producto] es el mismo
/// tipo que puebla la vitrina y el catálogo, así que [TarjetaProducto],
/// [PrecioProducto] y [GrillaProductos] funcionan sin adaptadores. Heredar de
/// `Producto` obligaría a duplicar el `fromJson` entero para agregar tres
/// campos.
class ProductoDetalle {
  const ProductoDetalle({
    required this.producto,
    required this.promociones,
    required this.relacionados,
    this.descripcion,
  });

  /// Todo lo de la tarjeta, con la misma regla de precio opcional.
  final Producto producto;

  /// Texto libre que carga un administrativo.
  ///
  /// **Acá viven las características técnicas y no se modelan aparte.** Lo
  /// dice el docblock del resource. No hay tabla de especificaciones ni
  /// atributos: es un solo campo de texto, y la app lo muestra tal cual, con
  /// los saltos de línea que tenga. Partirlo en "clave: valor" sería inventar
  /// una estructura que el dato no tiene.
  final String? descripcion;

  /// Las promociones vigentes que efectivamente alcanzan a este producto.
  ///
  /// **Para el invitado llega vacía, no ausente**, y esa diferencia con el
  /// bloque de precio del producto es deliberada del backend. El motivo está
  /// en el docblock del resource y es el mismo de siempre: una promoción de
  /// tipo `precio_especial` guarda un PRECIO en la columna `valor`, así que
  /// nombrarla ya sería filtrar el importe.
  ///
  /// Una lista vacía puede significar dos cosas —invitado, o producto sin
  /// promociones— y la app no necesita distinguirlas: en los dos casos no hay
  /// nada que mostrar.
  final List<Promocion> promociones;

  /// Otros productos de la misma categoría, en orden aleatorio
  /// (`inRandomOrder()` en el backend, hasta cuatro).
  ///
  /// Cada uno es un `ProductoResource` completo, así que respeta la
  /// visibilidad de precio por su cuenta: no hay que filtrarlos acá.
  final List<Producto> relacionados;

  bool get tieneDescripcion =>
      descripcion != null && descripcion!.trim().isNotEmpty;

  bool get tienePromociones => promociones.isNotEmpty;

  factory ProductoDetalle.fromJson(Map<String, dynamic> json) {
    return ProductoDetalle(
      // El mismo `fromJson` de la tarjeta: los campos heredados están en el
      // nivel raíz del objeto, no anidados.
      producto: Producto.fromJson(json),
      descripcion: comoTextoOpcional(json['descripcion']),
      promociones: Promocion.listaDe(json['promociones']),
      relacionados: Producto.listaDe(json['relacionados']),
    );
  }
}
