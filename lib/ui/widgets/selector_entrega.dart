import 'package:flutter/material.dart';

import '../../datos/modelos/checkout.dart';

/// Cómo retira el cliente y qué quiere aclarar.
///
/// **Las opciones las dicta el backend.** `modosDisponibles` viene en la
/// respuesta en vez de estar escrito acá: hoy hay una sola —retiro en el
/// local— y el día que se habiliten los envíos esta pantalla no se toca.
/// Por eso el radio se dibuja igual aunque haya una sola opción: el cliente
/// tiene que elegirla, no encontrarla elegida.
///
/// **Y tiene que elegirla de verdad.** `carritos.modo_entrega` la lee el
/// webhook de Mercado Pago para armar la venta; asumir el valor en la
/// pantalla guardaría una decisión que el cliente nunca tomó.
///
/// **Las observaciones no se guardan en cada tecla.** Un PATCH por pulsación
/// sería una ráfaga de peticiones y un carrito escribiéndose a medio texto.
/// Se guardan al salir del campo, o con el botón que aparece cuando hay algo
/// sin guardar.
class SelectorEntrega extends StatefulWidget {
  const SelectorEntrega({
    super.key,
    required this.entrega,
    required this.onElegirModo,
    required this.onGuardarObservaciones,
    this.habilitado = true,
  });

  final EntregaCheckout entrega;
  final ValueChanged<String> onElegirModo;
  final ValueChanged<String?> onGuardarObservaciones;
  final bool habilitado;

  @override
  State<SelectorEntrega> createState() => _SelectorEntregaState();
}

class _SelectorEntregaState extends State<SelectorEntrega> {
  late final TextEditingController _observaciones =
      TextEditingController(text: widget.entrega.observaciones ?? '');

  final FocusNode _foco = FocusNode();

  /// Lo último que confirmó el backend. Contra esto se compara para saber si
  /// hay cambios sin guardar; usar el valor inicial no alcanza, porque
  /// después de guardar el campo deja de estar sucio.
  late String _guardado = widget.entrega.observaciones ?? '';

  @override
  void initState() {
    super.initState();

    _observaciones.addListener(_alEscribir);
    _foco.addListener(_alPerderFoco);
  }

  @override
  void didUpdateWidget(SelectorEntrega anterior) {
    super.didUpdateWidget(anterior);

    final llegaron = widget.entrega.observaciones ?? '';

    if (llegaron == _guardado) return;

    _guardado = llegaron;

    // El texto del campo sólo se pisa si el usuario no está escribiendo. Si
    // tiene el foco, lo suyo es más nuevo que esta respuesta.
    if (!_foco.hasFocus && _observaciones.text != llegaron) {
      _observaciones.text = llegaron;
    }
  }

  @override
  void dispose() {
    _observaciones.removeListener(_alEscribir);
    _foco.removeListener(_alPerderFoco);
    _observaciones.dispose();
    _foco.dispose();
    super.dispose();
  }

  bool get _hayCambios => _observaciones.text.trim() != _guardado.trim();

  void _alEscribir() => setState(() {});

  void _alPerderFoco() {
    if (_foco.hasFocus || !_hayCambios || !widget.habilitado) return;

    _guardar();
  }

  void _guardar() {
    final texto = _observaciones.text.trim();

    // El backend normaliza el vacío a null: así no queda una fila con un
    // texto vacío que después hay que distinguir de "no escribió nada".
    widget.onGuardarObservaciones(texto.isEmpty ? null : texto);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 18, color: colores.outline),
                const SizedBox(width: 8),
                Text(
                  'Entrega',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Se dibuja el radio a mano en vez de usar RadioListTile: su
            // par groupValue/onChanged quedo deprecado a favor de RadioGroup
            // en las versiones nuevas de Flutter, y un ListTile con el icono
            // hace exactamente lo mismo sin atarse a cual de las dos APIs
            // este vigente.
            for (final opcion in widget.entrega.modosDisponibles)
              ListTile(
                onTap: widget.habilitado
                    ? () => widget.onElegirModo(opcion.valor)
                    : null,
                leading: Icon(
                  opcion.valor == widget.entrega.modo
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: opcion.valor == widget.entrega.modo
                      ? colores.primary
                      : colores.outline,
                ),
                title: Text(opcion.etiqueta),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),

            if (!widget.entrega.estaElegido)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Elegí cómo querés recibir tu pedido.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colores.outline),
                ),
              ),

            const SizedBox(height: 8),

            TextField(
              controller: _observaciones,
              focusNode: _foco,
              enabled: widget.habilitado,
              maxLines: 3,
              // Es el largo de la columna en la base. El contador le avisa
              // al cliente antes de que el backend lo rechace con un 422.
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                hintText: 'Por ejemplo: paso a retirar el viernes a la tarde.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            if (_hayCambios)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: widget.habilitado ? _guardar : null,
                  child: const Text('Guardar observaciones'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
