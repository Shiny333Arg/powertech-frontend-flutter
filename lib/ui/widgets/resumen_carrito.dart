import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../datos/modelos/carrito.dart';

/// La barra de totales, fija al pie del carrito y del checkout.
///
/// **Los tres importes se muestran tal como vinieron.** No se resta, no se
/// suma y no se verifica que `subtotal − descuento` dé `total`: si alguna vez
/// no diera, el que está mal es el cliente, no el servidor, y recalcularlo
/// acá taparía el problema en vez de mostrarlo.
///
/// **El botón lo habilita una bandera del backend y nada más.** No se deriva
/// de `vacio`, ni de si hay líneas no disponibles, ni del total: el servidor
/// ya combinó todo eso. Un carrito donde todo se despublicó tiene líneas y
/// total cero —no es vacío, pero no se puede pagar—, y esa es justamente la
/// distinción que la app no tiene que rehacer.
///
/// **Cuál bandera depende de la pantalla**, y por eso [habilitado] se puede
/// pasar desde afuera. El carrito usa su `puedeComprar`, que mira el carrito.
/// El checkout usa `puedePagar`, que mira además si el cliente puede recibir
/// factura y por eso es más estricto. Sin el parámetro, el pie del checkout
/// habilitaría el pago a un responsable inscripto sin CUIT.
class ResumenCarrito extends StatelessWidget {
  const ResumenCarrito({
    super.key,
    required this.carrito,
    required this.onContinuar,
    this.ocupado = false,
    this.habilitado,
    this.textoBoton = 'Continuar la compra',
    this.icono = Icons.lock_outline,
    this.motivoDeshabilitado,
  });

  final Carrito carrito;

  /// Null deshabilita el botón aunque la bandera sea true. Lo usa la pantalla
  /// mientras hay una operación en curso.
  final VoidCallback? onContinuar;

  final bool ocupado;

  /// Qué bandera manda. Null usa `carrito.puedeComprar`, que es lo que
  /// corresponde en la pantalla del carrito.
  final bool? habilitado;

  final String textoBoton;
  final IconData icono;

  /// Qué decir debajo del botón apagado. Null usa los textos del carrito.
  final String? motivoDeshabilitado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final hayDescuento = carrito.descuentoTotal > 0;
    final puede = habilitado ?? carrito.puedeComprar;

    return Material(
      elevation: 8,
      color: colores.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Renglon(
                etiqueta: 'Subtotal',
                valor: Formato.pesos(carrito.subtotalLista),
              ),

              if (hayDescuento) ...[
                const SizedBox(height: 4),
                _Renglon(
                  etiqueta: 'Descuentos',
                  // El signo lo pone la app porque el backend manda el
                  // descuento en positivo: es cuánto se ahorra, no un importe
                  // negativo.
                  valor: '− ${Formato.pesos(carrito.descuentoTotal)}',
                  color: colores.primary,
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),

              _Renglon(
                etiqueta: 'Total',
                valor: Formato.pesos(carrito.total),
                destacado: true,
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: puede && !ocupado ? onContinuar : null,
                  icon: Icon(icono),
                  label: Text(textoBoton),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Por qué el botón está apagado. Sin esto es un botón gris sin
              // explicación, que es la queja más común de un carrito.
              if (!puede) ...[
                const SizedBox(height: 8),
                Text(
                  motivoDeshabilitado ??
                      (carrito.vacio
                          ? 'Agregá productos para continuar.'
                          : 'Quitá los productos que ya no están disponibles '
                              'para poder continuar.'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colores.outline,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
    this.color,
  });

  final String etiqueta;
  final String valor;
  final bool destacado;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado
        ? Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: estilo),
        Text(valor, style: estilo),
      ],
    );
  }
}
