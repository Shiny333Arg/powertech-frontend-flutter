import 'package:flutter/material.dart';

import '../../datos/modelos/compra.dart';

/// El chip de estado de un pedido.
///
/// Equivale a `compras/partials/estado.blade.php`, y **el texto es el mismo
/// porque lo manda el backend**: `EstadoCompraCliente::etiqueta()` lo escribe
/// una vez y lo leen la web y la app. Si el chip de la web dice "Listo para
/// retirar" y el de la app dijera "Lista para retirar", serían dos productos
/// mirando la misma fila.
///
/// **El color lo elige la app, el tono lo decide el backend.** Laravel manda
/// `exito | info | atencion | error | neutro` —la gravedad— y acá se resuelve
/// contra esta paleta. Mandar un color desde PHP ataría el backend al tema de
/// la app; mapear los doce estados de `EstadoVenta` en Dart sería la tercera
/// copia de una regla de negocio.
class ChipEstadoCompra extends StatelessWidget {
  const ChipEstadoCompra({
    super.key,
    required this.estado,
    this.compacto = false,
  });

  final EstadoCompra estado;

  /// En la tarjeta del historial el chip comparte fila con la fecha y el
  /// total, así que va más chico que en el encabezado del detalle.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final color = ColoresTono.de(context, estado.tono);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 9 : 12,
        vertical: compacto ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ColoresTono.icono(estado.tono),
            size: compacto ? 13 : 15,
            color: color,
          ),
          SizedBox(width: compacto ? 5 : 6),
          Text(
            estado.etiqueta,
            style: TextStyle(
              fontSize: compacto ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// La paleta de los cinco tonos, en un solo lugar.
///
/// La usan el chip, el bloque de seguimiento y el resumen de pago, así que
/// vive afuera del widget: tres copias de la misma decisión terminan siendo
/// tres verdes distintos.
///
/// Los valores son los que ya usa el resto de la app (ver `pantalla_inicio`),
/// no una paleta nueva.
class ColoresTono {
  const ColoresTono._();

  static const Color verde = Color(0xFF16845B);
  static const Color ambar = Color(0xFFB7791F);
  static const Color rojo = Color(0xFFDC4545);
  static const Color gris = Color(0xFF64748B);

  /// `info` sale del tema y no de una constante: es el estado "esto avanza",
  /// y el azul de la marca ya significa eso en toda la app.
  static Color de(BuildContext context, TonoEstado tono) => switch (tono) {
        TonoEstado.exito => verde,
        TonoEstado.info => Theme.of(context).colorScheme.primary,
        TonoEstado.atencion => ambar,
        TonoEstado.error => rojo,
        TonoEstado.neutro => gris,
      };

  static IconData icono(TonoEstado tono) => switch (tono) {
        TonoEstado.exito => Icons.check_circle_rounded,
        TonoEstado.info => Icons.local_shipping_rounded,
        TonoEstado.atencion => Icons.schedule_rounded,
        TonoEstado.error => Icons.cancel_rounded,
        TonoEstado.neutro => Icons.info_rounded,
      };
}
