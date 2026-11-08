import 'conversiones.dart';

/// Lo que devuelve `POST /api/v1/checkout/pagar`: a dónde mandar al cliente.
///
/// **No hay ninguna credencial acá y no puede haberla.** El `access_token` de
/// Mercado Pago vive en Laravel y no sale nunca. Lo único que viaja es la URL
/// pública del checkout, que es la misma que vería cualquiera que reciba el
/// link.
///
/// **Y no hay pedido todavía.** Esta respuesta significa "la orden de cobro
/// existe", no "compraste". La venta nace cuando el pago se acredita, por el
/// webhook.
class InicioPago {
  const InicioPago({
    required this.preferenciaId,
    required this.urlPago,
    required this.total,
  });

  /// Id de la preferencia en Mercado Pago. Se guarda para poder mostrarlo si
  /// algo sale mal y hay que reclamar.
  final String preferenciaId;

  /// La URL del checkout de Mercado Pago, para abrir en el navegador.
  final String urlPago;

  /// El total que se va a cobrar, calculado por el backend.
  final double total;

  factory InicioPago.fromJson(Map<String, dynamic> json) {
    return InicioPago(
      preferenciaId: comoTexto(json['preferencia_id']),
      urlPago: comoTexto(json['url_pago']),
      total: comoDecimalOpcional(json['total']) ?? 0,
    );
  }
}

/// En qué quedó el último intento de pago.
///
/// Los cuatro valores los decide el backend consultando la base y la pasarela;
/// la app no los deduce de la URL por la que volvió el navegador, que es
/// editable y puede no llegar nunca.
enum ResultadoPago {
  /// Hay venta. Es lo único que significa "compraste".
  aprobado,

  /// La pasarela registró el intento y no prosperó. El carrito quedó intacto.
  rechazado,

  /// Hay un pago en curso sin venta todavía, o no se pudo averiguar. Hay que
  /// volver a preguntar.
  pendiente,

  /// No hay ningún intento registrado: el cliente cerró el navegador sin
  /// pagar, o nunca empezó.
  sinPago,

  /// Un valor que esta versión de la app no conoce. Se trata como pendiente
  /// —seguir preguntando es lo seguro— pero se distingue para poder notarlo.
  desconocido;

  static ResultadoPago desdeTexto(String valor) => switch (valor) {
        'aprobado' => ResultadoPago.aprobado,
        'rechazado' => ResultadoPago.rechazado,
        'pendiente' => ResultadoPago.pendiente,
        'sin_pago' => ResultadoPago.sinPago,
        _ => ResultadoPago.desconocido,
      };

  /// Si conviene volver a consultar dentro de un rato.
  ///
  /// **`aprobado` no se sigue consultando** aunque sea un final feliz: ya hay
  /// venta y no va a cambiar. `rechazado` y `sinPago` tampoco: para que
  /// cambien hace falta que el cliente vuelva a pagar, que es una acción
  /// suya y no una espera.
  bool get conviveneReintentar =>
      this == ResultadoPago.pendiente || this == ResultadoPago.desconocido;
}

/// El estado del pago, y la venta si ya existe.
class EstadoPago {
  const EstadoPago({required this.resultado, this.venta});

  final ResultadoPago resultado;

  /// Sólo viene con [ResultadoPago.aprobado].
  final VentaResumen? venta;

  factory EstadoPago.fromJson(Map<String, dynamic> json) {
    final venta = comoMapa(json['venta']);

    return EstadoPago(
      resultado: ResultadoPago.desdeTexto(comoTexto(json['estado'])),
      venta: venta == null ? null : VentaResumen.fromJson(venta),
    );
  }
}

/// Lo mínimo del pedido para poder mostrarlo al volver del pago.
///
/// No es el detalle de la compra: para eso está "Mis compras", que es otra
/// etapa. Acá alcanza con el número, para que el cliente pueda anotarlo o
/// mencionarlo, y el mensaje de cierre.
class VentaResumen {
  const VentaResumen({
    required this.id,
    required this.numero,
    required this.estado,
    required this.total,
    required this.mensaje,
  });

  final int id;

  /// Ya formateado por el backend, con su prefijo y su relleno.
  final String numero;

  /// `pagada`, `en_preparacion`, `pendiente_stock`... Lo decide el backend
  /// según haya stock físico o no.
  final String estado;

  final double total;

  /// Qué decirle al cliente. **Lo escribe el backend**, porque depende de en
  /// qué estado quedó la venta: no es lo mismo "pasá a retirarlo" que
  /// "estamos esperando la reposición". La app no arma ese texto.
  final String mensaje;

  factory VentaResumen.fromJson(Map<String, dynamic> json) {
    return VentaResumen(
      id: comoEntero(json['id']),
      numero: comoTexto(json['numero']),
      estado: comoTexto(json['estado']),
      total: comoDecimalOpcional(json['total']) ?? 0,
      mensaje: comoTexto(json['mensaje']),
    );
  }
}
