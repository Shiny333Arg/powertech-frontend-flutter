import 'conversiones.dart';

/// A dónde tiene que ir el cliente para resolver un bloqueo.
///
/// La app no decide esto mirando el texto del mensaje: lo deduce del
/// `codigo`, que es el campo que el backend agregó para eso. Comparar
/// cadenas se rompe con cualquier retoque de redacción.
enum DestinoBloqueo {
  /// Sacar o cambiar algo del carrito.
  carrito,

  /// El carrito está vacío: hay que elegir productos.
  catalogo,

  /// Faltan datos de facturación.
  ///
  /// **Hoy es un destino sin salida y conviene saberlo.** «Mi cuenta» es de
  /// sólo lectura: muestra el problema y dice que hay que acercarse al local.
  /// Editar el perfil desde la app necesita `PATCH /api/v1/perfil`, que es la
  /// etapa 6 del plan de la API y todavía no existe.
  perfil,

  /// Un código que esta versión de la app no conoce. Se muestra el mensaje
  /// del backend y no se ofrece acción: inventar una sería adivinar.
  desconocido,
}

/// Un motivo por el que esta compra no se puede pagar.
///
/// Espejo de un elemento de `bloqueos` en `CheckoutResource`.
///
/// **El mensaje lo escribe el backend y se muestra tal cual.** Es la misma
/// regla que ya rige en el carrito con `motivo_no_disponible`: el texto que
/// nombra el producto que hay que quitar, o que explica por qué un
/// responsable inscripto necesita CUIT, sale del servidor. Reescribirlo acá
/// crearía dos redacciones de la misma regla que se desincronizan.
///
/// Lo único que la app deriva es [destino], y lo deriva del código.
class BloqueoCheckout {
  const BloqueoCheckout({required this.codigo, required this.mensaje});

  final String codigo;
  final String mensaje;

  /// Los códigos que el backend emite hoy. Están acá y no sueltos en los
  /// `case` para que se vean todos juntos y se note cuando aparezca uno
  /// nuevo.
  static const String carritoVacio = 'carrito_vacio';
  static const String productoNoDisponible = 'producto_no_disponible';
  static const String sinDatosFiscales = 'sin_datos_fiscales';
  static const String facturacionIncompleta = 'facturacion_incompleta';
  static const String carritoConvertido = 'carrito_convertido';
  static const String carritoNoDisponible = 'carrito_no_disponible';

  DestinoBloqueo get destino => switch (codigo) {
        carritoVacio => DestinoBloqueo.catalogo,
        productoNoDisponible => DestinoBloqueo.carrito,
        carritoConvertido => DestinoBloqueo.carrito,
        carritoNoDisponible => DestinoBloqueo.carrito,
        sinDatosFiscales => DestinoBloqueo.perfil,
        facturacionIncompleta => DestinoBloqueo.perfil,

        // Un código nuevo del backend no rompe la pantalla: el bloqueo se
        // muestra igual, con su mensaje, y sin botón.
        _ => DestinoBloqueo.desconocido,
      };

  /// Texto del botón que lleva a resolverlo. Null cuando no hay a dónde ir.
  String? get textoAccion => switch (destino) {
        DestinoBloqueo.catalogo => 'Ver el catálogo',
        DestinoBloqueo.carrito => 'Ir al carrito',
        DestinoBloqueo.perfil => 'Ver mis datos',
        DestinoBloqueo.desconocido => null,
      };

  factory BloqueoCheckout.fromJson(Map<String, dynamic> json) {
    return BloqueoCheckout(
      codigo: comoTexto(json['codigo']),
      mensaje: comoTexto(json['mensaje']),
    );
  }

  static List<BloqueoCheckout> listaDe(dynamic crudo) {
    if (crudo is! List) return const [];

    return crudo
        .map(comoMapa)
        .whereType<Map<String, dynamic>>()
        .map(BloqueoCheckout.fromJson)
        .toList();
  }
}
