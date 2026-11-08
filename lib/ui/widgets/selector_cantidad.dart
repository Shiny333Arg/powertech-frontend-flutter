import 'dart:async';

import 'package:flutter/material.dart';

/// Los botones `−` y `+` con el número en el medio.
///
/// **Agrupa las ráfagas de toques.** Tocar cinco veces el `+` no manda cinco
/// `PATCH`: el número sube al instante y, medio segundo después del último
/// toque, se manda una sola llamada con el valor final. Sin esto, mantener
/// apretado el botón genera una cola de peticiones que llegan desordenadas y
/// dejan el carrito mostrando una cantidad que ya no es la que se pidió.
///
/// **Lo único que se adelanta es el número.** Los importes no: el subtotal y
/// el total siguen siendo los que mandó el backend hasta que contesta la
/// llamada. Adelantarlos obligaría a multiplicar precio por cantidad en el
/// teléfono, que es exactamente la regla que el proyecto no permite romper
/// —el descuento vigente lo resuelve `MotorPromociones` al momento de mirar,
/// y una promoción por cantidad haría que la cuenta local diera distinto—.
///
/// El valor local se descarta en cuanto [valor] cambia desde afuera: si el
/// backend devolvió otra cantidad, la que manda es la suya.
class SelectorCantidad extends StatefulWidget {
  const SelectorCantidad({
    super.key,
    required this.valor,
    required this.onCambiar,
    this.minimo = 1,
    this.maximo = 99,
    this.habilitado = true,
    this.espera = const Duration(milliseconds: 500),
  });

  /// La cantidad que dice el backend.
  final int valor;

  /// Se llama una vez por ráfaga, con el valor final.
  final ValueChanged<int> onCambiar;

  /// 1, no 0. Bajar de 1 es quitar la línea, y eso es `DELETE`: el backend
  /// responde 422 a `cantidad: 0`.
  final int minimo;

  /// 99. Es el tope del backend (`CarritoLineaMovilRequest`), que no es
  /// stock: es un freno contra el tipeo.
  final int maximo;

  final bool habilitado;

  /// Cuánto se espera después del último toque antes de mandar.
  final Duration espera;

  @override
  State<SelectorCantidad> createState() => _SelectorCantidadState();
}

class _SelectorCantidadState extends State<SelectorCantidad> {
  /// La cantidad que se está mostrando. Puede ir por delante del backend
  /// mientras hay una ráfaga en curso.
  late int _mostrado = widget.valor;

  Timer? _temporizador;

  @override
  void didUpdateWidget(SelectorCantidad anterior) {
    super.didUpdateWidget(anterior);

    // El backend cambió la cantidad. Si no hay una ráfaga en curso, su valor
    // es el bueno y se adopta. Si la hay, no se pisa: el usuario sigue
    // tocando y su intención es más nueva que esta respuesta.
    if (widget.valor != anterior.valor && _temporizador == null) {
      _mostrado = widget.valor;
    }
  }

  @override
  void dispose() {
    // Si el usuario sale de la pantalla con una ráfaga sin mandar, se manda
    // ahora. Sin esto, el último toque se pierde en silencio y el carrito
    // queda con una cantidad distinta de la que se vio.
    if (_temporizador?.isActive ?? false) {
      _temporizador!.cancel();
      widget.onCambiar(_mostrado);
    }

    _temporizador?.cancel();
    super.dispose();
  }

  void _ajustar(int delta) {
    final nuevo = (_mostrado + delta).clamp(widget.minimo, widget.maximo);

    if (nuevo == _mostrado) return;

    setState(() => _mostrado = nuevo);

    _temporizador?.cancel();
    _temporizador = Timer(widget.espera, () {
      _temporizador = null;

      // Pudo haber vuelto al valor original tocando + y después −.
      if (_mostrado != widget.valor) widget.onCambiar(_mostrado);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final activo = widget.habilitado;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colores.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Boton(
            icono: Icons.remove,
            tooltip: 'Quitar una unidad',
            onTap: activo && _mostrado > widget.minimo
                ? () => _ajustar(-1)
                : null,
          ),

          Container(
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              '$_mostrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: activo ? null : colores.outline,
                  ),
            ),
          ),

          _Boton(
            icono: Icons.add,
            tooltip: 'Agregar una unidad',
            onTap: activo && _mostrado < widget.maximo
                ? () => _ajustar(1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({required this.icono, required this.tooltip, this.onTap});

  final IconData icono;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icono, size: 18),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}
