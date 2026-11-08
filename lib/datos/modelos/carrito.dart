import 'conversiones.dart';
import 'linea_carrito.dart';

/// El carrito del cliente. Espejo de `CarritoResource`.
///
/// **Las cinco operaciones del carrito devuelven este mismo objeto**, con los
/// totales ya recalculados: consultar, agregar, cambiar cantidad, quitar y
/// vaciar. Por eso hay un solo modelo y una sola forma de parsearlo, y por eso
/// la app nunca necesita pedir el carrito de nuevo después de modificarlo.
///
/// **Nada de lo que hay acá se calcula en Flutter.** Ni los totales, ni el
/// descuento, ni las banderas. `MotorPromociones` resuelve el descuento
/// vigente al momento de mirar y el carrito no congela precios: cualquier
/// suma hecha en el teléfono queda vieja en cuanto cambia una promoción, y el
/// desajuste lo paga `exigirImporteExacto()` abortando la compra.
///
/// Por la misma razón **no se cachea en disco**.
class Carrito {
  const Carrito({
    required this.id,
    required this.estado,
    required this.cantidadItems,
    required this.cantidadLineas,
    required this.vacio,
    required this.subtotalLista,
    required this.descuentoTotal,
    required this.total,
    required this.tienePreventa,
    required this.tieneNoDisponibles,
    required this.puedeComprar,
    required this.lineas,
  });

  final int id;

  /// `activo` o `en_checkout`. El backend devuelve el carrito a `activo` solo
  /// con que se lo toque, así que en esta etapa no hay nada que decidir con
  /// este campo: viaja porque es parte del contrato.
  final String estado;

  /// **Unidades totales, no líneas.** Es el número del globito del carrito.
  /// Cuenta también las unidades de las líneas no disponibles, que el cliente
  /// metió y sigue viendo.
  final int cantidadItems;

  final int cantidadLineas;

  /// No hay ninguna línea.
  ///
  /// Se lee del backend en vez de preguntar `lineas.isEmpty`: es el mismo
  /// valor, pero manteniendo una sola autoridad no hay forma de que diverjan
  /// si mañana el resource decide algo distinto.
  final bool vacio;

  /// Suma a precio de lista, **sin** las líneas no disponibles.
  final double subtotalLista;

  /// Cuánto ahorra por promociones.
  final double descuentoTotal;

  /// `subtotalLista − descuentoTotal`. **Es lo que el checkout va a cobrar**,
  /// no la suma de lo que se ve en pantalla: las líneas no disponibles quedan
  /// afuera.
  final double total;

  /// Alguna línea pide unidades que no están en el depósito.
  final bool tienePreventa;

  /// Algún producto dejó de venderse mientras estaba en el carrito.
  final bool tieneNoDisponibles;

  /// **Es la bandera que habilita el botón de checkout, y la decide el
  /// backend.** Hay algo que cobrar y nada que corregir.
  ///
  /// Un carrito donde todo se despublicó tiene líneas y total cero: no es
  /// vacío, pero tampoco se puede pagar. Esa distinción es justamente la que
  /// la app no tiene que derivar sola.
  final bool puedeComprar;

  final List<LineaCarrito> lineas;

  /// Las líneas que ya no se pueden comprar. Para el cartel de cabecera que
  /// dice cuántas hay que quitar.
  List<LineaCarrito> get lineasNoDisponibles =>
      lineas.where((linea) => !linea.disponible).toList();

  /// Un carrito recién creado y vacío, para no tener que tratar con null
  /// mientras se arma la pantalla.
  static const Carrito ninguno = Carrito(
    id: 0,
    estado: 'activo',
    cantidadItems: 0,
    cantidadLineas: 0,
    vacio: true,
    subtotalLista: 0,
    descuentoTotal: 0,
    total: 0,
    tienePreventa: false,
    tieneNoDisponibles: false,
    puedeComprar: false,
    lineas: <LineaCarrito>[],
  );

  factory Carrito.fromJson(Map<String, dynamic> json) {
    return Carrito(
      id: comoEntero(json['id']),
      estado: comoTexto(json['estado']),
      cantidadItems: comoEntero(json['cantidad_items']),
      cantidadLineas: comoEntero(json['cantidad_lineas']),
      vacio: comoBool(json['vacio']),
      subtotalLista: comoDecimalOpcional(json['subtotal_lista']) ?? 0,
      descuentoTotal: comoDecimalOpcional(json['descuento_total']) ?? 0,
      total: comoDecimalOpcional(json['total']) ?? 0,
      tienePreventa: comoBool(json['tiene_preventa']),
      tieneNoDisponibles: comoBool(json['tiene_no_disponibles']),
      puedeComprar: comoBool(json['puede_comprar']),
      lineas: LineaCarrito.listaDe(json['lineas']),
    );
  }
}
