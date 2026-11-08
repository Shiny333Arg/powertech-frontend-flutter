import 'package:flutter/material.dart';

import '../../datos/modelos/checkout.dart';

/// Los datos con los que se va a emitir la factura.
///
/// **De sólo lectura, y hoy no puede ser otra cosa.** Editar el perfil desde
/// la app necesita `PATCH /api/v1/perfil`, que es la etapa 6 del plan de la
/// API y todavía no existe. Por eso el botón lleva a "Mi cuenta", que muestra
/// el problema y explica cómo resolverlo, en vez de abrir un formulario que
/// no tendría a dónde mandar los cambios.
///
/// Se muestra igual cuando falta algo: el cliente tiene que poder ver qué
/// hay cargado para entender el bloqueo. Un hueco se dibuja como "—", no se
/// oculta.
class TarjetaFacturacion extends StatelessWidget {
  const TarjetaFacturacion({
    super.key,
    required this.datos,
    required this.onVerPerfil,
  });

  /// Null cuando el usuario no tiene un cliente asociado.
  final DatosFacturacion? datos;

  final VoidCallback onVerPerfil;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final datos = this.datos;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 18, color: colores.outline),
                const SizedBox(width: 8),
                Text(
                  'Facturación',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onVerPerfil,
                  child: const Text('Ver mis datos'),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(left: 26, right: 8, bottom: 6),
              child: datos == null
                  ? Text(
                      'Tu cuenta todavía no tiene datos de facturación '
                      'cargados.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colores.outline),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Dato('A nombre de', datos.razonSocial),
                        _Dato('Documento', datos.documento),
                        _Dato('Condición IVA', datos.condicionIva),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              etiqueta,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colores.outline),
            ),
          ),
          Expanded(
            child: Text(
              // Un dato que falta se ve, no se esconde: es parte de lo que
              // el cliente necesita para entender por qué no puede pagar.
              (valor == null || valor!.isEmpty) ? '—' : valor!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
