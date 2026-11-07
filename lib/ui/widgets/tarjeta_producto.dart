import 'package:flutter/material.dart';

import '../../datos/modelos/producto.dart';
import 'imagen_remota.dart';
import 'precio_producto.dart';

/// Tarjeta de producto de la vitrina. Equivale a
/// `home/partials/tarjeta-producto.blade.php`.
///
/// Muestra lo mismo que la web y en el mismo orden: imagen, marca, nombre,
/// estado de stock y precio. La diferencia es que acá el precio puede no
/// existir, y eso lo resuelve [PrecioProducto].
///
/// **El badge de stock se dibuja igual para invitado y para cliente.** El
/// stock no es dato reservado (requerimiento 3.5): lo único que se reserva es
/// el precio. Y `en_preventa` llega ya resuelto por el backend con
/// `stock_disponible <= 0`, el mismo criterio que la vitrina web, así que no
/// se recalcula acá.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({
    super.key,
    required this.producto,
    this.onIngresar,
    this.onTocar,
  });

  final Producto producto;

  /// Para el "Ver precio" del invitado.
  final VoidCallback? onIngresar;

  /// La ficha de producto es el paso 5. Hasta entonces esto viene en null y
  /// la tarjeta no es tocable: un botón que no hace nada es peor que no
  /// tenerlo.
  final VoidCallback? onTocar;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTocar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ImagenRemota(url: producto.imagenUrl),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (producto.marca != null)
                      Text(
                        producto.marca!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 2),

                    Text(
                      producto.nombre,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    _BadgeStock(producto: producto),

                    const Spacer(),

                    PrecioProducto(
                      producto: producto,
                      onIngresar: onIngresar,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Disponible" o "Preventa", con el mismo significado que en la web:
/// preventa no quiere decir que no se pueda comprar, quiere decir que las
/// unidades todavía no están en el depósito. Está admitida.
class _BadgeStock extends StatelessWidget {
  const _BadgeStock({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final enPreventa = producto.enPreventa;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: enPreventa ? colores.tertiaryContainer : colores.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        enPreventa ? 'Preventa' : 'Disponible',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: enPreventa
              ? colores.onTertiaryContainer
              : colores.onSecondaryContainer,
        ),
      ),
    );
  }
}
