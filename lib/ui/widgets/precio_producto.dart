import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../datos/modelos/producto.dart';

/// El precio de un producto, con los tres estados que tiene que distinguir.
///
/// **Los tres se parecen en pantalla y significan cosas distintas**, y
/// confundirlos es el bug que el contrato advierte:
///
///  1. **Sin precio porque es invitado.** El backend no mandó el bloque. No es
///     "$ 0,00" —eso sería "gratis"— ni un espacio en blanco —eso sería
///     "cargando"—. Es una invitación a ingresar, y lleva al login.
///  2. **Con precio, sin descuento.** Un solo importe.
///  3. **Con precio y descuento.** El de lista tachado, el final destacado, y
///     el porcentaje que calculó el backend.
///
/// El estado se decide por `producto.tienePrecio`, o sea por **lo que vino en
/// la respuesta**, no por el estado de sesión de la app. El backend ya
/// decidió; preguntarle también a la sesión abriría la puerta a que la app
/// muestre un precio que el servidor no mandó, o lo esconda cuando sí lo
/// mandó.
class PrecioProducto extends StatelessWidget {
  const PrecioProducto({
    super.key,
    required this.producto,
    this.onIngresar,
    this.compacto = true,
  });

  final Producto producto;

  /// Qué hacer cuando el invitado toca "Ingresá para ver el precio". Si es
  /// null, el aviso se muestra igual pero sin acción.
  final VoidCallback? onIngresar;

  /// La tarjeta de la vitrina usa la versión compacta; una ficha usaría la
  /// grande.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    if (!producto.tienePrecio) {
      return _SinPrecio(onIngresar: onIngresar, compacto: compacto);
    }

    final lista = producto.precio!;
    final aPagar = producto.precioAPagar ?? lista;
    final hayDescuento = producto.tieneDescuento && aPagar < lista;

    final estiloFinal = compacto
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.headlineSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hayDescuento)
          Row(
            children: [
              Text(
                Formato.pesos(lista),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(width: 6),
              if (producto.porcentajeDescuento > 0)
                _Etiqueta(texto: '-${producto.porcentajeDescuento}%'),
            ],
          ),
        Text(
          Formato.pesos(aPagar),
          style: estiloFinal?.copyWith(
            fontWeight: FontWeight.bold,
            color: hayDescuento
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      ],
    );
  }
}

/// El estado 1. Es el que más fácil se dibuja mal.
class _SinPrecio extends StatelessWidget {
  const _SinPrecio({required this.onIngresar, required this.compacto});

  final VoidCallback? onIngresar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 14, color: colores.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            compacto ? 'Ver precio' : 'Ingresá para ver el precio',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colores.primary,
                  fontWeight: FontWeight.w600,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );

    if (onIngresar == null) return contenido;

    return InkWell(
      onTap: onIngresar,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: contenido,
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colores.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: colores.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
