import 'package:flutter/material.dart';

import '../../datos/modelos/compra_detalle.dart';
import 'chip_estado_compra.dart';

/// Los pasos del pedido, en vertical, con la línea que los une.
///
/// Equivale al `<ol>` de seguimiento de `compras/show.blade.php`.
///
/// **No muestra fechas porque no hay.** `ventas` no guarda cuándo ocurrió cada
/// transición, así que lo único que se puede afirmar es que el paso ya pasó.
/// Inventar "hace 2 días" a partir de la fecha de la venta sería mentir sobre
/// el único dato que el cliente viene a mirar.
///
/// **Los pasos los arma el backend, incluso cuáles son.** Un pedido con retiro
/// termina en "Retirado" y uno con envío en "Entregado"; uno que esperó
/// reposición trae un paso que los demás no tienen. La app no conoce el
/// circuito: pinta la lista que recibe.
class SeguimientoCompra extends StatelessWidget {
  const SeguimientoCompra({super.key, required this.pasos});

  final List<PasoSeguimiento> pasos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++)
          _Paso(
            paso: pasos[i],
            esUltimo: i == pasos.length - 1,
          ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.paso, required this.esUltimo});

  final PasoSeguimiento paso;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final color = switch (paso.situacion) {
      SituacionPaso.hecho => ColoresTono.verde,
      SituacionPaso.actual => Theme.of(context).colorScheme.primary,
      SituacionPaso.pendiente => const Color(0xFFCBD5E1),
    };

    final esPendiente = paso.situacion == SituacionPaso.pendiente;

    // `IntrinsicHeight` + `stretch` es lo que hace que la línea de unión
    // llegue siempre hasta el círculo siguiente: el alto de cada paso lo
    // decide su texto, que puede envolver en dos o tres renglones según el
    // ancho del teléfono. Con un alto fijo, el detalle largo de "Esperando
    // reposición" dejaría la línea cortada en el aire.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: esPendiente ? const Color(0xFFF1F5F9) : color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: paso.situacion == SituacionPaso.hecho
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: esPendiente
                                ? const Color(0xFFCBD5E1)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                if (!esUltimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: paso.situacion == SituacionPaso.hecho
                          ? ColoresTono.verde.withValues(alpha: 0.35)
                          : const Color(0xFFE8EDF3),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 18),
              child: Opacity(
                opacity: esPendiente ? 0.55 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paso.etiqueta,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: paso.situacion == SituacionPaso.actual
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF202B3C),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      paso.detalle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se muestra en lugar del seguimiento cuando el pedido ya no está en
/// curso: cancelado, devuelto o devuelto parcialmente.
///
/// **El texto lo escribe el backend.** Depende de cuál de los estados de fin
/// de vida quedó, y es el mismo que explica la web. La app no decide qué
/// decirle al cliente sobre una devolución.
class AvisoDesenlace extends StatelessWidget {
  const AvisoDesenlace({super.key, required this.desenlace});

  final DesenlaceCompra desenlace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desenlace.titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desenlace.detalle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
