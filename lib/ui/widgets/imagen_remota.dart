import 'package:flutter/material.dart';

/// Imagen de la API con sus tres estados: cargando, cargada y fallida.
///
/// **Usa `Image.network` y no `cached_network_image`.** El paso 0 dejó esa
/// dependencia afuera a propósito y la decisión sigue: para una vitrina de
/// ocho tarjetas por sección, el caché en memoria que ya trae Flutter alcanza.
/// Cuando exista el catálogo paginado con scroll infinito, ahí se vuelve a
/// mirar.
///
/// `imagen_url` puede ser null —producto o promoción sin imagen cargada— y eso
/// es parte del contrato, no un error: el backend devuelve null y la app pone
/// su propio marcador.
class ImagenRemota extends StatelessWidget {
  const ImagenRemota({
    super.key,
    required this.url,
    this.ajuste = BoxFit.contain,
    this.relleno = const EdgeInsets.all(8),
  });

  final String? url;
  final BoxFit ajuste;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) {
    final direccion = url;

    if (direccion == null || direccion.isEmpty) {
      return const _SinImagen();
    }

    return Padding(
      padding: relleno,
      child: Image.network(
        direccion,
        fit: ajuste,
        // Sin esto, una imagen que no carga tira la excepción al árbol de
        // widgets y rompe la tarjeta entera.
        errorBuilder: (_, __, ___) => const _SinImagen(fallo: true),
        loadingBuilder: (context, hijo, progreso) {
          if (progreso == null) return hijo;

          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}

class _SinImagen extends StatelessWidget {
  const _SinImagen({this.fallo = false});

  /// Distingue "no hay imagen cargada" de "había y no se pudo traer". El
  /// segundo caso suele ser `APP_URL` apuntando a un host que el teléfono no
  /// alcanza, y conviene que se note.
  final bool fallo;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colores.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fallo ? Icons.broken_image_outlined : Icons.image_not_supported_outlined,
              size: 28,
              color: colores.outline,
            ),
            const SizedBox(height: 4),
            Text(
              fallo ? 'No se pudo cargar' : 'Sin imagen',
              style: TextStyle(fontSize: 10, color: colores.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
