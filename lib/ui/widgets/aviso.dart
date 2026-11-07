import 'package:flutter/material.dart';

import '../../core/errores.dart';

/// Cartel para los errores que **no** son de un campo concreto: se cayo la
/// red, el servidor devolvio 500, el throttle corto la llamada.
///
/// Los de validacion no pasan por aca: esos van debajo del campo que los
/// causo, que es donde el usuario los busca.
class AvisoError extends StatelessWidget {
  const AvisoError({super.key, required this.error, this.onReintentar});

  final ErrorApi error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: colores.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _texto(error),
                  style: TextStyle(color: colores.onErrorContainer),
                ),
              ),
            ],
          ),
          if (onReintentar != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Para la red no se muestra el volcado tecnico de `ErrorRed.mensaje`, que
  /// trae la URL completa: en el login eso no le sirve a nadie. El detalle
  /// sigue estando en la pantalla de diagnostico, que es donde se busca.
  String _texto(ErrorApi error) {
    if (error is ErrorRed) {
      return 'No pudimos conectarnos con el servidor. Revisá tu conexión y '
          'probá de nuevo.';
    }

    return error.mensaje;
  }
}

/// Cartel informativo, no de error. Lo usa el aviso de correo sin verificar.
class AvisoInformativo extends StatelessWidget {
  const AvisoInformativo({
    super.key,
    required this.titulo,
    required this.detalle,
    this.icono = Icons.info_outline,
    this.accion,
    this.textoAccion,
    this.ocupado = false,
  });

  final String titulo;
  final String detalle;
  final IconData icono;
  final VoidCallback? accion;
  final String? textoAccion;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colores.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: colores.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colores.onSecondaryContainer,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            style: TextStyle(color: colores.onSecondaryContainer),
          ),
          if (accion != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: ocupado ? null : accion,
                child: Text(
                  ocupado ? 'Enviando...' : (textoAccion ?? 'Continuar'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
