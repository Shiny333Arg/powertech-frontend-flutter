import 'bloqueo_checkout.dart';
import 'carrito.dart';
import 'conversiones.dart';

/// El resumen previo al pago. Espejo de `CheckoutResource`.
///
/// **El carrito viene entero y se parsea con el mismo [Carrito] del paso 7.**
/// El backend anida el `CarritoResource` tal cual adentro del checkout, así
/// que no hay un segundo modelo ni un segundo parseo. Eso no es sólo
/// comodidad: garantiza que la pantalla de checkout y la del carrito muestren
/// exactamente los mismos importes, que es lo que el cliente compara dos
/// veces antes de pagar.
///
/// **[puedePagar] no se deriva: se lee.** Es más estricto que el
/// `puedeComprar` del carrito, y a propósito. Aquel mira el carrito —hay algo
/// que cobrar y nada despublicado—; éste mira además si el cliente puede
/// recibir factura, que es una condición del CLIENTE. Un responsable
/// inscripto sin CUIT tiene `puedeComprar` en true y `puedePagar` en false.
class ResumenCheckout {
  const ResumenCheckout({
    required this.carrito,
    required this.entrega,
    required this.puedePagar,
    required this.bloqueos,
    this.facturacion,
  });

  final Carrito carrito;
  final EntregaCheckout entrega;

  /// Null cuando el usuario no tiene un cliente asociado. En ese caso hay un
  /// bloqueo `sin_datos_fiscales` que lo explica.
  final DatosFacturacion? facturacion;

  /// **Es lo único que habilita el botón de pagar.** No se cruza con
  /// `bloqueos.isEmpty` ni con `carrito.puedeComprar`: el backend ya combinó
  /// todo eso. Dos condiciones en la app serían dos lugares donde la regla
  /// puede quedar distinta de la del servidor.
  final bool puedePagar;

  /// Todo lo que falta, junto. El backend los manda todos de una para que el
  /// cliente arregle todo en una pasada en vez de descubrir el siguiente
  /// problema después de resolver el anterior.
  final List<BloqueoCheckout> bloqueos;

  factory ResumenCheckout.fromJson(Map<String, dynamic> json) {
    final facturacion = comoMapa(json['facturacion']);

    return ResumenCheckout(
      carrito: Carrito.fromJson(comoMapa(json['carrito']) ?? const {}),
      entrega: EntregaCheckout.fromJson(comoMapa(json['entrega']) ?? const {}),
      facturacion:
          facturacion == null ? null : DatosFacturacion.fromJson(facturacion),
      puedePagar: comoBool(json['puede_pagar']),
      bloqueos: BloqueoCheckout.listaDe(json['bloqueos']),
    );
  }
}

/// Cómo retira el cliente, y qué opciones hay.
class EntregaCheckout {
  const EntregaCheckout({
    this.modo,
    this.observaciones,
    this.modosDisponibles = const [],
  });

  /// Null hasta que el cliente elija.
  ///
  /// La app **no lo da por elegido** aunque haya una sola opción: esta
  /// columna la lee el webhook de Mercado Pago para armar la venta, y tiene
  /// que ser una decisión real guardada con un PATCH, no un valor que la
  /// pantalla asumió.
  final String? modo;

  final String? observaciones;

  /// Las opciones las dicta el backend, no la app. Hoy hay una sola; cuando
  /// se habiliten los envíos, la pantalla se actualiza sin tocar Flutter.
  final List<OpcionEntrega> modosDisponibles;

  /// Si ya hay un modo elegido y guardado.
  bool get estaElegido => modo != null && modo!.isNotEmpty;

  factory EntregaCheckout.fromJson(Map<String, dynamic> json) {
    return EntregaCheckout(
      modo: comoTextoOpcional(json['modo']),
      observaciones: comoTextoOpcional(json['observaciones']),
      modosDisponibles: OpcionEntrega.listaDe(json['modos_disponibles']),
    );
  }
}

class OpcionEntrega {
  const OpcionEntrega({required this.valor, required this.etiqueta});

  /// Lo que viaja en el PATCH.
  final String valor;

  /// Lo que se muestra. Lo escribe el backend, desde `ModoEntrega::etiqueta()`.
  final String etiqueta;

  factory OpcionEntrega.fromJson(Map<String, dynamic> json) {
    return OpcionEntrega(
      valor: comoTexto(json['valor']),
      etiqueta: comoTexto(json['etiqueta']),
    );
  }

  static List<OpcionEntrega> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(OpcionEntrega.fromJson)
        .toList();
  }
}

/// Lo que va a salir impreso en la factura.
///
/// **Es un subconjunto a propósito.** No trae ids internos ni teléfono: el
/// backend manda sólo lo que esta pantalla muestra, que es lo que el cliente
/// tiene que poder revisar antes de pagar. El perfil completo sigue estando
/// en `/auth/yo`.
class DatosFacturacion {
  const DatosFacturacion({
    this.razonSocial,
    this.tipoDocumento,
    this.nroDoc,
    this.condicionIva,
  });

  final String? razonSocial;
  final String? tipoDocumento;
  final String? nroDoc;
  final String? condicionIva;

  /// El documento listo para mostrar: "DNI 30111222".
  String? get documento {
    if (nroDoc == null || nroDoc!.isEmpty) return null;

    return tipoDocumento == null ? nroDoc : '$tipoDocumento $nroDoc';
  }

  factory DatosFacturacion.fromJson(Map<String, dynamic> json) {
    return DatosFacturacion(
      razonSocial: comoTextoOpcional(json['razon_social']),
      tipoDocumento: comoTextoOpcional(json['tipo_documento']),
      nroDoc: comoTextoOpcional(json['nro_doc']),
      condicionIva: comoTextoOpcional(json['condicion_iva']),
    );
  }
}
