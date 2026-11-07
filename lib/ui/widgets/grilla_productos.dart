import 'package:flutter/material.dart';

import '../../datos/modelos/producto.dart';
import 'tarjeta_producto.dart';

/// Grilla de tarjetas de producto, compartida por la vitrina y el catálogo.
///
/// Nació como un widget privado dentro de la vitrina en el paso 3; se extrajo
/// acá cuando el catálogo necesitó la misma cosa, en lugar de copiarla. Las
/// dos pantallas tienen que verse igual: es el mismo producto en los dos
/// lados.
///
/// `shrinkWrap` + `NeverScrollableScrollPhysics` porque siempre va dentro de
/// otro scroll (el `ListView` de la vitrina, el del catálogo). Una grilla con
/// su propio scroll adentro de otro scroll no deja llegar al final.
class GrillaProductos extends StatelessWidget {
  const GrillaProductos({
    super.key,
    required this.productos,
    this.onIngresar,
    this.onTocarProducto,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Producto> productos;

  /// Para el "Ver precio" del invitado.
  final VoidCallback? onIngresar;

  /// La ficha de producto es el paso 5. Hasta entonces viene en null y las
  /// tarjetas no son tocables.
  final void Function(Producto)? onTocarProducto;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) return const SizedBox.shrink();

    // La tarjeta con precio tachado + porcentaje es más alta que la del
    // invitado, así que la relación de aspecto se calcula con la más alta: si
    // no, la que tiene descuento desborda.
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho >= 900 ? 4 : (ancho >= 600 ? 3 : 2);

    return GridView.builder(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: productos.length,
      itemBuilder: (context, i) {
        final producto = productos[i];

        return TarjetaProducto(
          producto: producto,
          onIngresar: onIngresar,
          onTocar: onTocarProducto == null
              ? null
              : () => onTocarProducto!(producto),
        );
      },
    );
  }
}
