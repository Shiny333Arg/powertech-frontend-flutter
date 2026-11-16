import 'compra.dart';
import 'conversiones.dart';
import 'etiquetado.dart';

/// El pedido completo: `GET /api/v1/compras/{id}`. Espejo de
/// `CompraDetalleResource`.
///
/// **Una sola llamada trae todo lo que la pantalla muestra**: seguimiento,
/// líneas, importes, entrega, pagos y comprobantes. No hay un segundo GET para
/// la factura ni para los pagos.
///
/// **Y casi nada se calcula acá.** El seguimiento llega con la situación de
/// cada paso resuelta, las instrucciones de entrega en texto, el número del
/// comprobante formateado y el saldo ya restado. Todo eso son reglas del
/// negocio o de ARCA: viven en Laravel, que es donde se pueden verificar.
class CompraDetalle {
  const CompraDetalle({
    required this.id,
    required this.numero,
    required this.numeroFormateado,
    required this.canal,
    required this.estado,
    required this.enCurso,
    required this.seguimiento,
    required this.importes,
    required this.entrega,
    required this.lineas,
    required this.pago,
    required this.pagos,
    required this.facturacion,
    this.fecha,
    this.desenlace,
    this.observaciones,
  });

  final int id;
  final int numero;

  /// Ya formateado por el backend (`V-0000142`).
  final String numeroFormateado;

  final DateTime? fecha;

  final Etiquetado canal;

  final EstadoCompra estado;

  /// False para cancelada, vencida, devuelta y devuelta parcial.
  ///
  /// **Es lo que decide qué bloque mostrar**: con `true` hay [seguimiento] y
  /// [desenlace] es null; con `false` es al revés. Preguntar si la lista está
  /// vacía funcionaría igual, pero este campo dice la intención y no obliga a
  /// la pantalla a deducirla.
  final bool enCurso;

  /// Los pasos del circuito, en orden. Vacío cuando el pedido no está en
  /// curso.
  final List<PasoSeguimiento> seguimiento;

  /// Qué pasó con un pedido que ya no está en curso. Null si sigue vivo.
  final DesenlaceCompra? desenlace;

  final ImportesCompra importes;

  final EntregaCompra entrega;

  /// Lo que el cliente escribió al confirmar. Puede ser multilínea.
  final String? observaciones;

  final List<LineaCompra> lineas;

  /// El resumen del cobro.
  final ResumenPago pago;

  /// Cada pago por separado. Pueden ser varios: `pagos` admite pago mixto y
  /// pagos parciales.
  final List<PagoCompra> pagos;

  final FacturacionCompra facturacion;

  bool get esDelMostrador => canal.es('mostrador');

  /// Unidades, sumando las líneas. El backend no lo manda en el detalle
  /// porque las líneas ya vienen enteras: sumarlas acá no puede desalinearse
  /// de nada.
  int get cantidadItems =>
      lineas.fold<int>(0, (suma, linea) => suma + linea.cantidad);

  bool get tieneDevoluciones => lineas.any((linea) => linea.fueDevuelta);

  factory CompraDetalle.fromJson(Map<String, dynamic> json) {
    // `pago` trae el resumen y, adentro, la lista de pagos. Se leen del mismo
    // mapa en lugar de aplanarlos: el resumen lo calcula el backend y la
    // lista es su detalle, así que viajan juntos.
    final pago = comoMapa(json['pago']) ?? const <String, dynamic>{};

    final desenlace = comoMapa(json['desenlace']);

    return CompraDetalle(
      id: comoEntero(json['id']),
      numero: comoEntero(json['numero']),
      numeroFormateado: comoTexto(json['numero_formateado']),
      fecha: comoFechaOpcional(json['fecha']),
      canal: Etiquetado.obligatorio(json['canal']),
      estado: EstadoCompra.fromJson(comoMapa(json['estado']) ?? const {}),
      enCurso: comoBool(json['en_curso']),
      seguimiento: PasoSeguimiento.listaDe(json['seguimiento']),
      desenlace:
          desenlace == null ? null : DesenlaceCompra.fromJson(desenlace),
      importes:
          ImportesCompra.fromJson(comoMapa(json['importes']) ?? const {}),
      entrega: EntregaCompra.fromJson(comoMapa(json['entrega']) ?? const {}),
      observaciones: comoTextoOpcional(json['observaciones']),
      lineas: LineaCompra.listaDe(json['lineas']),
      pago: ResumenPago.fromJson(pago),
      pagos: PagoCompra.listaDe(pago['pagos']),
      facturacion:
          FacturacionCompra.fromJson(comoMapa(json['facturacion']) ?? const {}),
    );
  }
}

// ====================================================================
// Seguimiento
// ====================================================================

/// Un paso del circuito, con su situación.
///
/// **No tiene fecha, y no es que falte mandarla.** `ventas` no guarda cuándo
/// ocurrió cada transición, así que lo único que se puede afirmar es que el
/// paso ya pasó, por la posición del estado en el circuito. El día que haga
/// falta la fecha de cada paso, hay que registrar las transiciones en el
/// backend.
class PasoSeguimiento {
  const PasoSeguimiento({
    required this.etiqueta,
    required this.detalle,
    required this.situacion,
  });

  /// "Pago acreditado", "En preparación", "Listo para retirar"...
  final String etiqueta;

  /// La explicación de una línea que va debajo.
  final String detalle;

  final SituacionPaso situacion;

  factory PasoSeguimiento.fromJson(Map<String, dynamic> json) {
    return PasoSeguimiento(
      etiqueta: comoTexto(json['etiqueta']),
      detalle: comoTexto(json['detalle']),
      situacion: SituacionPaso.desdeTexto(comoTexto(json['situacion'])),
    );
  }

  static List<PasoSeguimiento> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(PasoSeguimiento.fromJson)
        .toList();
  }
}

enum SituacionPaso {
  /// Ya ocurrió.
  hecho,

  /// Es donde está el pedido ahora.
  actual,

  /// Todavía no.
  pendiente;

  /// Un valor desconocido cae en [pendiente]: es lo que menos afirma.
  static SituacionPaso desdeTexto(String valor) => switch (valor) {
        'hecho' => SituacionPaso.hecho,
        'actual' => SituacionPaso.actual,
        _ => SituacionPaso.pendiente,
      };
}

/// Qué pasó con un pedido cancelado o devuelto.
///
/// Reemplaza al seguimiento: un pedido así no tiene circuito que mostrar,
/// tiene un desenlace. **El texto lo escribe el backend**, porque es el mismo
/// que explica la web y porque depende de cuál de los cuatro estados de fin de
/// vida quedó.
class DesenlaceCompra {
  const DesenlaceCompra({required this.titulo, required this.detalle});

  /// "Cancelada", "Devuelta", "Devuelta parcialmente".
  final String titulo;

  final String detalle;

  factory DesenlaceCompra.fromJson(Map<String, dynamic> json) {
    return DesenlaceCompra(
      titulo: comoTexto(json['titulo']),
      detalle: comoTexto(json['detalle']),
    );
  }
}

// ====================================================================
// Importes
// ====================================================================

/// Los importes del documento, **congelados al emitir**.
///
/// Salen de las columnas de `ventas`. La app no los recalcula sumando líneas:
/// si una promoción se aplicó distinto de como se calcularía hoy, el documento
/// manda. Es lo que se le cobró.
class ImportesCompra {
  const ImportesCompra({
    required this.subtotal,
    required this.descuentoPromociones,
    required this.costoEnvio,
    required this.totalIva,
    required this.total,
  });

  final double subtotal;

  /// Lo que descontaron las promociones. Cero cuando no hubo.
  final double descuentoPromociones;

  /// Cero en un retiro.
  final double costoEnvio;

  /// El IVA incluido en el total, para la línea "IVA incluido".
  final double totalIva;

  final double total;

  bool get hayDescuento => descuentoPromociones > 0;

  bool get hayEnvio => costoEnvio > 0;

  factory ImportesCompra.fromJson(Map<String, dynamic> json) {
    return ImportesCompra(
      subtotal: comoDecimalOpcional(json['subtotal']) ?? 0,
      descuentoPromociones:
          comoDecimalOpcional(json['descuento_promociones']) ?? 0,
      costoEnvio: comoDecimalOpcional(json['costo_envio']) ?? 0,
      totalIva: comoDecimalOpcional(json['total_iva']) ?? 0,
      total: comoDecimalOpcional(json['total']) ?? 0,
    );
  }
}

// ====================================================================
// Entrega
// ====================================================================

/// Cómo recibe el pedido el cliente.
class EntregaCompra {
  const EntregaCompra({
    required this.modo,
    required this.instrucciones,
    this.envio,
  });

  /// `retiro` o `envio`, con su etiqueta.
  final Etiquetado modo;

  /// Qué tiene que hacer el cliente, en texto. **Lo escribe el backend**,
  /// porque depende del modo y del número de pedido; si mañana se habilitan
  /// los envíos con tracking, cambia en Laravel y no en Flutter.
  final String instrucciones;

  /// Null en un retiro: `modo_entrega = retiro` significa que no hay fila en
  /// `envios`, no que haya una vacía.
  final EnvioCompra? envio;

  bool get esRetiro => modo.es('retiro');

  factory EntregaCompra.fromJson(Map<String, dynamic> json) {
    final envio = comoMapa(json['envio']);

    return EntregaCompra(
      modo: Etiquetado.obligatorio(json['modo']),
      instrucciones: comoTexto(json['instrucciones']),
      envio: envio == null ? null : EnvioCompra.fromJson(envio),
    );
  }
}

/// Dirección y seguimiento del envío.
///
/// **La dirección es la que se copió al confirmar**, no la del perfil: un
/// envío ya despachado no cambia de destino porque el cliente editó su
/// domicilio después.
class EnvioCompra {
  const EnvioCompra({
    required this.direccionCompleta,
    required this.costo,
    this.calle,
    this.numero,
    this.pisoDepto,
    this.codigoPostal,
    this.localidad,
    this.provincia,
    this.estado,
    this.trackingUrl,
    this.fechaDespacho,
  });

  /// El domicilio en una línea, armado por el backend. Es lo que muestra la
  /// pantalla; los campos sueltos quedan para cuando haga falta editarlos.
  final String direccionCompleta;

  final String? calle;
  final String? numero;
  final String? pisoDepto;
  final String? codigoPostal;
  final String? localidad;
  final String? provincia;

  final double costo;

  /// Estado del envío según el transportista.
  final String? estado;

  /// Null hasta el despacho.
  final String? trackingUrl;

  final DateTime? fechaDespacho;

  bool get tieneSeguimiento => trackingUrl != null && trackingUrl!.isNotEmpty;

  factory EnvioCompra.fromJson(Map<String, dynamic> json) {
    return EnvioCompra(
      direccionCompleta: comoTexto(json['direccion_completa']),
      calle: comoTextoOpcional(json['calle']),
      numero: comoTextoOpcional(json['numero']),
      pisoDepto: comoTextoOpcional(json['piso_depto']),
      codigoPostal: comoTextoOpcional(json['codigo_postal']),
      localidad: comoTextoOpcional(json['localidad']),
      provincia: comoTextoOpcional(json['provincia']),
      costo: comoDecimalOpcional(json['costo']) ?? 0,
      estado: comoTextoOpcional(json['estado']),
      trackingUrl: comoTextoOpcional(json['tracking_url']),
      fechaDespacho: comoFechaOpcional(json['fecha_despacho']),
    );
  }
}

// ====================================================================
// Líneas
// ====================================================================

/// Una línea del pedido, **tal como se emitió**.
///
/// Descripción, precio unitario, descuento y total están congelados en
/// `venta_lineas`. Si el producto se renombró o cambió de precio después, acá
/// sigue diciendo lo que el cliente compró.
///
/// Del producto vivo llegan sólo dos cosas, y ninguna es un importe: la imagen
/// y si su ficha todavía se puede abrir.
class LineaCompra {
  const LineaCompra({
    required this.id,
    required this.descripcion,
    required this.cantidad,
    required this.cantidadDevuelta,
    required this.precioUnitario,
    required this.descuentoPromocion,
    required this.total,
    required this.productoEnlazable,
    this.productoId,
    this.imagenUrl,
  });

  final int id;

  /// Null si la línea quedó sin producto. No debería pasar —`ProtegeContraBorrado`
  /// lo impide— pero la línea es válida igual: el documento no depende de que
  /// el producto siga existiendo.
  final int? productoId;

  /// La descripción congelada. **No es `producto.nombre`.**
  final String descripcion;

  final int cantidad;

  /// Mayor a cero si hubo una devolución sobre esta línea. El [total] no
  /// cambia: la devolución se documenta con una nota de crédito aparte.
  final int cantidadDevuelta;

  final double precioUnitario;

  /// Lo que descontaron las promociones sobre esta línea, ya aplicado dentro
  /// de [total].
  final double descuentoPromocion;

  final double total;

  /// null cuando no hay imagen: la app pone su propio marcador. Es parte del
  /// contrato, igual que en el catálogo.
  final String? imagenUrl;

  /// Si se puede abrir la ficha del producto. **Lo decide el backend**: un
  /// producto despublicado o dado de baja sigue apareciendo en el pedido —se
  /// lo vendieron— pero su ficha responde 404. La app no conoce las reglas de
  /// publicación del catálogo.
  final bool productoEnlazable;

  bool get fueDevuelta => cantidadDevuelta > 0;

  bool get tieneDescuento => descuentoPromocion > 0;

  factory LineaCompra.fromJson(Map<String, dynamic> json) {
    return LineaCompra(
      id: comoEntero(json['id']),
      productoId: comoEnteroOpcional(json['producto_id']),
      descripcion: comoTexto(json['descripcion']),
      cantidad: comoEnteroOpcional(json['cantidad']) ?? 0,
      cantidadDevuelta: comoEnteroOpcional(json['cantidad_devuelta']) ?? 0,
      precioUnitario: comoDecimalOpcional(json['precio_unitario']) ?? 0,
      descuentoPromocion:
          comoDecimalOpcional(json['descuento_promocion']) ?? 0,
      total: comoDecimalOpcional(json['total']) ?? 0,
      imagenUrl: comoTextoOpcional(json['imagen_url']),
      productoEnlazable: comoBool(json['producto_enlazable']),
    );
  }

  static List<LineaCompra> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(LineaCompra.fromJson)
        .toList();
  }
}

// ====================================================================
// Pagos
// ====================================================================

/// Un pago del pedido.
///
/// Se llama `PagoCompra` porque `pago.dart` ya usa `EstadoPago` y `InicioPago`
/// para el intento de Mercado Pago durante el checkout. Esto es el pago ya
/// registrado contra una venta, que es otra cosa.
///
/// **No trae la comisión ni el neto acreditado**: eso es lo que la pasarela le
/// cobra a la empresa, no información del cliente. Tampoco los ids de Mercado
/// Pago, que son estado interno de la conciliación.
class PagoCompra {
  const PagoCompra({
    required this.id,
    required this.metodo,
    required this.estado,
    required this.monto,
    this.cuotas,
    this.fecha,
  });

  final int id;

  /// `efectivo`, `tarjeta` o `transferencia`, con su etiqueta.
  final Etiquetado metodo;

  /// `pendiente`, `acreditado`, `rechazado` o `devuelto`, con su etiqueta.
  final Etiquetado estado;

  final double monto;

  /// Null salvo en tarjeta.
  final int? cuotas;

  final DateTime? fecha;

  bool get estaAcreditado => estado.es('acreditado');

  bool get fueRechazado => estado.es('rechazado');

  factory PagoCompra.fromJson(Map<String, dynamic> json) {
    return PagoCompra(
      id: comoEntero(json['id']),
      metodo: Etiquetado.obligatorio(json['metodo']),
      estado: Etiquetado.obligatorio(json['estado']),
      monto: comoDecimalOpcional(json['monto']) ?? 0,
      cuotas: comoEnteroOpcional(json['cuotas']),
      fecha: comoFechaOpcional(json['fecha']),
    );
  }

  static List<PagoCompra> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(PagoCompra.fromJson)
        .toList();
  }
}

// ====================================================================
// Facturación
// ====================================================================

/// Los comprobantes fiscales del pedido.
class FacturacionCompra {
  const FacturacionCompra({required this.comprobantes, this.factura});

  /// La factura vigente: la de signo positivo y autorizada.
  ///
  /// **Null no es un error.** Puede que el pago todavía no se haya acreditado,
  /// o que ARCA la haya rechazado. En los dos casos el cliente no tiene nada
  /// que hacer, así que la pantalla muestra el mismo mensaje de espera y no
  /// distingue.
  final ComprobanteCompra? factura;

  /// Todos, incluidas las notas de crédito de una devolución.
  final List<ComprobanteCompra> comprobantes;

  bool get hayFactura => factura != null;

  /// Las notas de crédito, para listarlas aparte de la factura.
  List<ComprobanteCompra> get notasCredito =>
      comprobantes.where((c) => c.esNotaCredito).toList();

  factory FacturacionCompra.fromJson(Map<String, dynamic> json) {
    final factura = comoMapa(json['factura']);

    return FacturacionCompra(
      factura: factura == null ? null : ComprobanteCompra.fromJson(factura),
      comprobantes: ComprobanteCompra.listaDe(json['comprobantes']),
    );
  }
}

/// Una factura o una nota de crédito.
class ComprobanteCompra {
  const ComprobanteCompra({
    required this.id,
    required this.esNotaCredito,
    required this.tipo,
    required this.numeroFormateado,
    required this.total,
    required this.estado,
    required this.autorizado,
    this.letra,
    this.fechaEmision,
    this.cae,
    this.caeVencimiento,
  });

  final int id;

  final bool esNotaCredito;

  /// "Factura B", "Nota de crédito B". Lo arma el backend.
  final String tipo;

  final String? letra;

  /// `00003-00000518`: punto de venta en 5 dígitos y correlativo en 8. **El
  /// relleno lo hace el backend**, porque es una regla de ARCA y no se puede
  /// verificar desde Dart.
  final String numeroFormateado;

  final DateTime? fechaEmision;

  final double total;

  /// `pendiente`, `autorizado` o `rechazado`, con su etiqueta.
  final Etiquetado estado;

  /// Autorizado y con CAE. Es la pregunta que decide si el comprobante sirve.
  final bool autorizado;

  /// Null mientras no esté autorizado.
  final String? cae;

  final DateTime? caeVencimiento;

  factory ComprobanteCompra.fromJson(Map<String, dynamic> json) {
    return ComprobanteCompra(
      id: comoEntero(json['id']),
      esNotaCredito: comoBool(json['es_nota_credito']),
      tipo: comoTexto(json['tipo']),
      letra: comoTextoOpcional(json['letra']),
      numeroFormateado: comoTexto(json['numero_formateado']),
      fechaEmision: comoFechaOpcional(json['fecha_emision']),
      total: comoDecimalOpcional(json['total']) ?? 0,
      estado: Etiquetado.obligatorio(json['estado']),
      autorizado: comoBool(json['autorizado']),
      cae: comoTextoOpcional(json['cae']),
      caeVencimiento: comoFechaOpcional(json['cae_vencimiento']),
    );
  }

  static List<ComprobanteCompra> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(ComprobanteCompra.fromJson)
        .toList();
  }
}
