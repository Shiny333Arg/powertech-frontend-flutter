import 'package:flutter/material.dart';

import '../../datos/modelos/bloqueo_checkout.dart';

/// Todo lo que falta para poder pagar, con el botón que lleva a resolverlo.
///
/// **Se muestran todos, no el primero.** El backend los manda juntos
/// justamente para que el cliente arregle todo en una pasada en vez de
/// descubrir el siguiente después de resolver el anterior. Mostrar sólo uno
/// desperdiciaría eso.
///
/// **El texto sale del backend y no se reescribe.** Es el mismo criterio que
/// `motivo_no_disponible` en el carrito: el mensaje que nombra el producto
/// que hay que quitar, o que explica por qué un responsable inscripto
/// necesita CUIT, lo escribe el servidor. Dos redacciones de la misma regla
/// se desincronizan.
///
/// Lo que sí decide la app es **a dónde** manda cada botón, y lo decide por
/// el `codigo` del bloqueo. Un código que esta versión no conoce se muestra
/// igual, con su mensaje y sin botón: inventar un destino sería adivinar.
class ListaBloqueos extends StatelessWidget {
  const ListaBloqueos({
    super.key,
    required this.bloqueos,
    required this.onResolver,
  });

  final List<BloqueoCheckout> bloqueos;

  /// Se llama con el bloqueo tocado. La pantalla decide la navegación.
  final void Function(BloqueoCheckout bloqueo) onResolver;

  @override
  Widget build(BuildContext context) {
    if (bloqueos.isEmpty) return const SizedBox.shrink();

    final colores = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: colores.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bloqueos.length == 1
                      ? 'Falta algo para poder pagar'
                      : 'Faltan ${bloqueos.length} cosas para poder pagar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colores.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          for (final bloqueo in bloqueos)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _Bloqueo(
                bloqueo: bloqueo,
                onResolver: () => onResolver(bloqueo),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bloqueo extends StatelessWidget {
  const _Bloqueo({required this.bloqueo, required this.onResolver});

  final BloqueoCheckout bloqueo;
  final VoidCallback onResolver;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textoAccion = bloqueo.textoAccion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Icon(
                Icons.circle,
                size: 6,
                color: colores.onErrorContainer,
              ),
            ),
            Expanded(
              child: Text(
                bloqueo.mensaje,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colores.onErrorContainer),
              ),
            ),
          ],
        ),

        if (textoAccion != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onResolver,
              style: TextButton.styleFrom(
                foregroundColor: colores.onErrorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(textoAccion),
            ),
          ),
      ],
    );
  }
}
