import 'conversiones.dart';
import 'opcion_fiscal.dart';

/// Producto en una lista: vitrina, resultados de búsqueda, relacionados.
/// Es el espejo de `ProductoResource`.
///
/// **El bloque de precio son cuatro campos opcionales, no cuatro ceros.**
/// `bloqueDePrecio()` devuelve `[]` para el invitado: las claves `precio`,
/// `precio_final`, `tiene_descuento` y `porcentaje_descuento` no vienen
/// vacías, no vienen. Si `precio` fuera `double` con default 0, la vitrina del
/// invitado diría "$ 0,00" en cada tarjeta.
///
/// Van las cuatro juntas o ninguna —así lo decidió el resource— pero el modelo
/// no asume eso: cada una se lee por separado y [tienePrecio] pregunta por la
/// que importa. Si mañana el backend mandara un bloque parcial, la app
/// mostraría menos, no datos inventados.
///
/// **El stock sí lo ve el invitado.** Es requerimiento explícito (3.5): lo
/// único reservado es el precio.
class Producto {
  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.stockDisponible,
    required this.enPreventa,
    required this.destacado,
    this.marca,
    this.imagenUrl,
    this.categoria,
    this.precio,
    this.precioFinal,
    this.tieneDescuento = false,
    this.porcentajeDescuento = 0,
  });

  final int id;
  final String codigo;
  final String nombre;

  /// Texto libre en la base, puede estar vacío.
  final String? marca;

  /// URL absoluta ya armada por `UrlPublica::deStorage()`, o null si el
  /// producto no tiene imagen cargada. La app pone su propio marcador.
  final String? imagenUrl;

  /// Unidades disponibles. Puede ser 0 o negativo: eso no oculta el producto,
  /// lo marca como preventa.
  final int stockDisponible;

  /// **Lo resuelve el backend con `stock_disponible <= 0`**, el mismo criterio
  /// que `tarjeta-producto.blade.php`. No se recalcula acá: dos lugares
  /// decidiendo lo mismo es el bug.
  final bool enPreventa;

  final bool destacado;

  /// `{ id, nombre }`. Se reusa [OpcionFiscal] porque la forma es idéntica y
  /// un modelo nuevo con los mismos dos campos no agrega nada.
  final OpcionFiscal? categoria;

  /// Precio de lista. **null para el invitado.**
  final double? precio;

  /// Precio con las promociones vigentes aplicadas. **null para el
  /// invitado.** Igual al de lista cuando no hay descuento.
  final double? precioFinal;

  final bool tieneDescuento;

  /// Entero ya redondeado por el backend, con el mismo cálculo que
  /// `item/show.blade.php`, para que la app y la web no muestren dos
  /// porcentajes distintos del mismo descuento.
  final int porcentajeDescuento;

  /// Si este visitante recibió el bloque de precio.
  ///
  /// Es la pregunta que decide qué dibuja el widget de precio, y no se
  /// responde mirando la sesión: la autoridad es lo que vino en la respuesta.
  /// El backend ya decidió; preguntarle también al estado de sesión abriría
  /// la puerta a que la app y el servidor discrepen.
  bool get tienePrecio => precio != null;

  /// El importe que hay que cobrar. Cae al de lista si el backend no mandó
  /// final, que es lo mismo que hace `bloqueDePrecio()`.
  double? get precioAPagar => precioFinal ?? precio;

  /// Descuento en plata, para poder mostrar "ahorrás $X".
  double? get ahorro {
    final lista = precio;
    final conPromo = precioFinal;

    if (lista == null || conPromo == null || conPromo >= lista) return null;

    return lista - conPromo;
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    final categoria = comoMapa(json['categoria']);

    return Producto(
      id: comoEntero(json['id']),
      codigo: comoTexto(json['codigo']),
      nombre: comoTexto(json['nombre']),
      marca: comoTextoOpcional(json['marca']),
      imagenUrl: comoTextoOpcional(json['imagen_url']),
      stockDisponible: comoEntero(json['stock_disponible']),
      enPreventa: comoBool(json['en_preventa']),
      destacado: comoBool(json['destacado']),
      categoria: categoria == null ? null : OpcionFiscal.fromJson(categoria),

      // Las cuatro claves del bloque reservado. Ausentes = invitado.
      precio: comoDecimalOpcional(json['precio']),
      precioFinal: comoDecimalOpcional(json['precio_final']),
      tieneDescuento: comoBool(json['tiene_descuento']),
      porcentajeDescuento: comoEnteroOpcional(json['porcentaje_descuento']) ?? 0,
    );
  }

  /// Convierte una lista cruda de la API, descartando lo que no sea un objeto.
  static List<Producto> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(Producto.fromJson)
        .toList();
  }
}
