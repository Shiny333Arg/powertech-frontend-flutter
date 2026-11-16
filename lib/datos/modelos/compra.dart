import 'conversiones.dart';
import 'etiquetado.dart';

/// Una compra en el historial: `GET /api/v1/compras`. Espejo de
/// `CompraResource`.
///
/// **No trae las líneas y no es una omisión.** La tarjeta del historial
/// muestra número, fecha, estado, modo de entrega, total y cuántos productos
/// son. El detalle de cada venta está en [CompraDetalle], a un toque de
/// distancia; mandarlo en una página de diez compras sería un orden de
/// magnitud más de JSON para pintar un contador.
///
/// **Incluye las compras del mostrador.** Una compra en el local también es
/// una compra del cliente y aparece acá con su etiqueta de canal. Lo que no
/// aparece son los presupuestos: el backend los filtra, porque un presupuesto
/// es un precio ofertado y no una compra.
class Compra {
  const Compra({
    required this.id,
    required this.numero,
    required this.numeroFormateado,
    required this.canal,
    required this.estado,
    required this.modoEntrega,
    required this.total,
    required this.cantidadLineas,
    required this.pago,
    this.fecha,
  });

  final int id;

  /// El correlativo interno, crudo.
  final int numero;

  /// El mismo número ya formateado por el backend (`V-0000142`). **Es el que
  /// se muestra**: es lo que el cliente dicta en el local, y armarlo en Dart
  /// sería repetir el relleno de `Venta::numeroFormateado()`.
  final String numeroFormateado;

  /// Null si la venta no tiene fecha cargada, que no debería pasar. La UI
  /// muestra un guion antes que inventar una.
  final DateTime? fecha;

  /// `online` o `mostrador`, con su etiqueta.
  final Etiquetado canal;

  final EstadoCompra estado;

  /// `retiro` o `envio`, con su etiqueta.
  final Etiquetado modoEntrega;

  final double total;

  /// Líneas, no unidades: es el "3 productos" de la tarjeta.
  final int cantidadLineas;

  /// En qué quedó el cobro. **No se deriva del estado de la venta**: el
  /// backend suma los pagos acreditados.
  final ResumenPago pago;

  /// Si la compra se hizo en el local. La tarjeta lo aclara, porque el
  /// cliente no la hizo desde la app y puede no reconocerla.
  bool get esDelMostrador => canal.es('mostrador');

  factory Compra.fromJson(Map<String, dynamic> json) {
    return Compra(
      id: comoEntero(json['id']),
      numero: comoEntero(json['numero']),
      numeroFormateado: comoTexto(json['numero_formateado']),
      fecha: comoFechaOpcional(json['fecha']),
      canal: Etiquetado.obligatorio(json['canal']),
      estado: EstadoCompra.fromJson(comoMapa(json['estado']) ?? const {}),
      modoEntrega: Etiquetado.obligatorio(json['modo_entrega']),
      total: comoDecimalOpcional(json['total']) ?? 0,
      cantidadLineas: comoEnteroOpcional(json['cantidad_lineas']) ?? 0,
      pago: ResumenPago.fromJson(comoMapa(json['pago']) ?? const {}),
    );
  }

  static List<Compra> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(Compra.fromJson)
        .toList();
  }
}

// ====================================================================
// Estado del pedido
// ====================================================================

/// El estado de la compra en el lenguaje del cliente, con su gravedad.
///
/// **La etiqueta la escribe el backend** (`EstadoCompraCliente`), que traduce
/// el vocabulario del circuito al del cliente: una venta `confirmada` es, para
/// quien la hizo, "Pendiente de pago". La app no rearma esa traducción.
///
/// **El [tono] es lo que permite diferenciarlos visualmente** sin comparar
/// textos ni conocer los doce estados de `EstadoVenta`. El backend decide la
/// gravedad; la app elige los colores.
class EstadoCompra {
  const EstadoCompra({
    required this.valor,
    required this.etiqueta,
    required this.tono,
  });

  /// `pagada`, `en_preparacion`, `cancelada`... La columna, para comparar.
  final String valor;

  /// El texto del chip.
  final String etiqueta;

  final TonoEstado tono;

  factory EstadoCompra.fromJson(Map<String, dynamic> json) {
    return EstadoCompra(
      valor: comoTexto(json['valor']),
      etiqueta: comoTexto(json['etiqueta']),
      tono: TonoEstado.desdeTexto(comoTexto(json['tono'])),
    );
  }
}

/// La gravedad de un estado, para que la interfaz lo distinga de un vistazo.
///
/// Cinco y no uno por estado: lo que el cliente tiene que percibir es si el
/// pedido avanza, si llegó, si está esperando algo, si se cayó o si ya no está
/// en curso.
enum TonoEstado {
  /// Llegó o está listo para retirar.
  exito,

  /// Avanza por el circuito.
  info,

  /// Espera algo: el pago, o la reposición de un producto.
  atencion,

  /// Cancelado.
  error,

  /// Fuera de circuito: devuelto, o un estado que esta versión no conoce.
  neutro;

  /// Un tono que la app no conoce cae en [neutro] en lugar de romper: el chip
  /// se dibuja en gris y la pantalla sigue andando. Es el mismo criterio que
  /// `ResultadoPago.desconocido`, con la diferencia de que acá no hace falta
  /// distinguirlo: un color es decoración.
  static TonoEstado desdeTexto(String valor) => switch (valor) {
        'exito' => TonoEstado.exito,
        'info' => TonoEstado.info,
        'atencion' => TonoEstado.atencion,
        'error' => TonoEstado.error,
        _ => TonoEstado.neutro,
      };
}

// ====================================================================
// Cobro
// ====================================================================

/// En qué quedó el cobro del pedido.
///
/// **No es el estado de la venta.** Son dos preguntas distintas: una venta de
/// mostrador puede estar `confirmada` y cobrada a medias, y una `pagada` lo
/// está porque hay pagos acreditados. El backend suma sólo los acreditados.
///
/// Se llama `ResumenPago` y no `EstadoPago` porque ese nombre ya está tomado
/// en `pago.dart`, que modela el resultado del intento de Mercado Pago durante
/// el checkout. Son cosas distintas: aquello es "¿se acreditó lo que acabo de
/// pagar?", esto es "¿cuánto de este pedido está cobrado?".
class ResumenPago {
  const ResumenPago({
    required this.situacion,
    required this.etiqueta,
    required this.totalAcreditado,
    required this.saldo,
  });

  final SituacionPago situacion;

  /// "Pagado", "Pago parcial", "Pendiente de pago". La escribe el backend.
  final String etiqueta;

  final double totalAcreditado;

  /// Lo que falta cobrar. Cero cuando está pagado.
  final double saldo;

  bool get estaPagado => situacion == SituacionPago.acreditado;

  bool get hayAlgoPendiente =>
      situacion == SituacionPago.pendiente ||
      situacion == SituacionPago.parcial;

  factory ResumenPago.fromJson(Map<String, dynamic> json) {
    return ResumenPago(
      situacion: SituacionPago.desdeTexto(comoTexto(json['situacion'])),
      etiqueta: comoTexto(json['etiqueta']),
      totalAcreditado: comoDecimalOpcional(json['total_acreditado']) ?? 0,
      saldo: comoDecimalOpcional(json['saldo']) ?? 0,
    );
  }
}

enum SituacionPago {
  /// Nada acreditado.
  pendiente,

  /// Algo acreditado, menos que el total.
  parcial,

  /// Cubre el total.
  acreditado,

  /// Un valor que esta versión no conoce. Se trata como pendiente en la UI
  /// —es lo conservador— pero se distingue para poder notarlo.
  desconocido;

  static SituacionPago desdeTexto(String valor) => switch (valor) {
        'pendiente' => SituacionPago.pendiente,
        'parcial' => SituacionPago.parcial,
        'acreditado' => SituacionPago.acreditado,
        _ => SituacionPago.desconocido,
      };
}
