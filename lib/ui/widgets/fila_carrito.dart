import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../datos/modelos/linea_carrito.dart';
import 'imagen_remota.dart';
import 'selector_cantidad.dart';

/// Una línea del carrito.
///
/// **Los tres estados que tiene que distinguir en pantalla**, y que el
/// backend ya resolvió:
///
///  1. **Normal.** Imagen, nombre, marca, precio unitario y subtotal. Si hay
///     descuento, el de lista tachado y el porcentaje.
///  2. **En preventa.** Se compra igual. El aviso dice cuántas unidades no
///     están en el depósito, que es la pregunta de la línea
///     (`unidades_en_preventa`) y no la del producto (`en_preventa`).
///  3. **No disponible.** El producto dejó de venderse mientras estaba en el
///     carrito. Se muestra atenuado, con el motivo que mandó el backend, sin
///     importes —el backend los manda en 0— y sin selector de cantidad:
///     sobre una línea que no se puede comprar, lo único que tiene sentido es
///     quitarla.
///
/// Ningún importe ni ninguna de esas condiciones se calcula acá.
class FilaCarrito extends StatelessWidget {
  const FilaCarrito({
    super.key,
    required this.linea,
    required this.onCambiarCantidad,
    required this.onQuitar,
    this.onTocar,
    this.habilitado = true,
  });

  final LineaCarrito linea;

  /// Recibe la cantidad final de una ráfaga de toques. Ver [SelectorCantidad].
  final ValueChanged<int> onCambiarCantidad;

  final VoidCallback onQuitar;

  /// Abre la ficha del producto. Null para una línea no disponible: su ficha
  /// responde 404, porque `show()` corta con `abort_unless($producto->activo
  /// && $producto->publicado_app, 404)`.
  final VoidCallback? onTocar;

  /// false mientras hay una operación en curso, para no encolar llamadas.
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final disponible = linea.disponible;

    return Opacity(
      // Una línea muerta se nota antes por el gris que por el texto.
      opacity: disponible ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Miniatura(linea: linea, onTocar: disponible ? onTocar : null),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (linea.producto?.marca != null)
                        Text(
                          linea.producto!.marca!.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colores.outline,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),

                      InkWell(
                        onTap: disponible ? onTocar : null,
                        child: Text(
                          linea.nombre,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (disponible) _PrecioUnitario(linea: linea),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Quitar del carrito',
                  icon: const Icon(Icons.delete_outline),
                  color: colores.outline,
                  onPressed: habilitado ? onQuitar : null,
                ),
              ],
            ),

            if (!disponible) ...[
              const SizedBox(height: 10),
              _AvisoLinea(
                icono: Icons.remove_shopping_cart_outlined,
                // Lo escribe el backend. La app no inventa el motivo: hoy hay
                // uno solo, pero el día que haya más llegan listos.
                texto: linea.motivoNoDisponible ??
                    'Este producto ya no está disponible.',
                fondo: colores.errorContainer,
                frente: colores.onErrorContainer,
              ),
            ] else ...[
              if (linea.requierePreventa) ...[
                const SizedBox(height: 10),
                _AvisoLinea(
                  icono: Icons.schedule_outlined,
                  texto: _textoPreventa(linea),
                  fondo: colores.tertiaryContainer,
                  frente: colores.onTertiaryContainer,
                ),
              ],

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SelectorCantidad(
                    valor: linea.cantidad,
                    habilitado: habilitado,
                    onCambiar: onCambiarCantidad,
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formato.pesos(linea.subtotal),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (linea.ahorro != null)
                        Text(
                          'Ahorrás ${Formato.pesos(linea.ahorro!)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colores.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// El texto de preventa se arma con `unidades_en_preventa`, que es la
  /// pregunta de la línea. Distinguir "todas" de "algunas" cambia lo que el
  /// cliente entiende que va a pasar con su pedido.
  String _textoPreventa(LineaCarrito linea) {
    final faltan = linea.unidadesEnPreventa;

    if (faltan >= linea.cantidad) {
      return faltan == 1
          ? 'En preventa: te la reservamos y te avisamos cuando llegue.'
          : 'En preventa: te las reservamos y te avisamos cuando lleguen.';
    }

    return faltan == 1
        ? 'Una unidad va en preventa: te avisamos cuando llegue.'
        : '$faltan unidades van en preventa: te avisamos cuando lleguen.';
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.linea, this.onTocar});

  final LineaCarrito linea;
  final VoidCallback? onTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTocar,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ImagenRemota(
          url: linea.producto?.imagenUrl,
          relleno: const EdgeInsets.all(6),
        ),
      ),
    );
  }
}

/// El precio por unidad: el de lista tachado cuando hay promoción, y el final.
///
/// Se usa este widget y no `PrecioProducto` a propósito. Aquel resuelve los
/// tres estados del catálogo —incluido "invitado sin precio", que acá no
/// existe— leyendo del `Producto`. En el carrito el importe que vale es el de
/// la LÍNEA, que es el que entró en el subtotal: el del producto anidado es el
/// mismo, pero hacer que la fila lo tome de ahí sería mostrar un número que no
/// es el que se sumó.
class _PrecioUnitario extends StatelessWidget {
  const _PrecioUnitario({required this.linea});

  final LineaCarrito linea;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final hayDescuento =
        linea.tieneDescuento && linea.precioUnitarioFinal < linea.precioUnitario;

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (hayDescuento)
          Text(
            Formato.pesos(linea.precioUnitario),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: colores.outline,
                ),
          ),

        Text(
          '${Formato.pesos(linea.precioUnitarioFinal)} c/u',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: hayDescuento ? colores.primary : null,
              ),
        ),

        if (hayDescuento && linea.porcentajeDescuento > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: colores.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${linea.porcentajeDescuento}%',
              style: TextStyle(
                color: colores.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _AvisoLinea extends StatelessWidget {
  const _AvisoLinea({
    required this.icono,
    required this.texto,
    required this.fondo,
    required this.frente,
  });

  final IconData icono;
  final String texto;
  final Color fondo;
  final Color frente;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: frente),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: frente),
            ),
          ),
        ],
      ),
    );
  }
}
