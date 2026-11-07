import 'package:flutter/material.dart';

import '../../datos/modelos/promocion.dart';

/// Las promociones vigentes que alcanzan a un producto, en la ficha.
///
/// **Si la lista está vacía este widget no se dibuja, y eso cubre dos casos a
/// la vez:** el invitado —al que el backend le manda `[]` a propósito— y el
/// producto sin promociones. No hace falta distinguirlos: en los dos no hay
/// nada que mostrar.
///
/// `etiquetaDelBeneficio` solo tiene valor cuando el visitante puede ver
/// precios, así que acá siempre lo va a tener: si llegó una promoción, llegó
/// con su bloque de precio.
class ListaPromociones extends StatelessWidget {
  const ListaPromociones({super.key, required this.promociones});

  final List<Promocion> promociones;

  @override
  Widget build(BuildContext context) {
    if (promociones.isEmpty) return const SizedBox.shrink();

    final colores = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colores.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 18,
                color: colores.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                promociones.length == 1
                    ? 'Promoción aplicada'
                    : 'Promociones aplicadas',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colores.onPrimaryContainer,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          for (final promocion in promociones)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Fila(promocion: promocion),
            ),

          if (promociones.length > 1)
            Text(
              'El precio final ya tiene todas las promociones aplicadas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colores.onPrimaryContainer,
                  ),
            ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.promocion});

  final Promocion promocion;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final beneficio = promocion.etiquetaDelBeneficio;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (beneficio != null)
          Container(
            margin: const EdgeInsets.only(right: 8, top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colores.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              beneficio,
              style: TextStyle(
                color: colores.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                promocion.nombre,
                style: TextStyle(
                  color: colores.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // `tipoEtiqueta` lo redacta el enum del backend, así que dice
              // "Precio especial" donde corresponde en lugar de "descuento".
              if (promocion.tipoEtiqueta != null)
                Text(
                  promocion.tipoEtiqueta!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colores.onPrimaryContainer.withValues(
                          alpha: 0.75,
                        ),
                      ),
                ),

              if (promocion.descripcion != null)
                Text(
                  promocion.descripcion!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colores.onPrimaryContainer.withValues(
                          alpha: 0.75,
                        ),
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
