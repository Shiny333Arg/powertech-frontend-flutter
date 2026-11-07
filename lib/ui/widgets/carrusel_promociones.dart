import 'package:flutter/material.dart';

import '../../datos/modelos/promocion.dart';
import 'imagen_remota.dart';

/// Carrusel horizontal de banners de promoción.
///
/// `promocionesVigentes()` solo devuelve promociones con banner cargado y
/// visibles en la tienda, así que lo que llega acá ya está filtrado: la app no
/// vuelve a chequear vigencia. Volver a filtrar por fecha en el cliente sería
/// un segundo lugar decidiendo lo mismo, y con el reloj del teléfono, que
/// puede estar mal.
///
/// **La etiqueta del beneficio solo aparece con sesión.** `tipo`, `unidad` y
/// `valor` son datos de precio y el invitado no los recibe: con
/// `precio_especial`, `valor` es el precio final del producto, no un
/// descuento. El invitado ve el banner y el nombre, que es lo que hace falta
/// para que el carrusel tenga sentido.
///
/// Tocar un banner va a llevar al catálogo filtrado por `?promocion={id}`,
/// que es el paso 4. Hasta entonces [onTocar] viene en null.
class CarruselPromociones extends StatelessWidget {
  const CarruselPromociones({
    super.key,
    required this.promociones,
    this.onTocar,
  });

  final List<Promocion> promociones;
  final void Function(Promocion)? onTocar;

  @override
  Widget build(BuildContext context) {
    if (promociones.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: promociones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _Banner(
          promocion: promociones[i],
          onTocar: onTocar == null ? null : () => onTocar!(promociones[i]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.promocion, this.onTocar});

  final Promocion promocion;
  final VoidCallback? onTocar;

  @override
  Widget build(BuildContext context) {
    final etiqueta = promocion.etiquetaDelBeneficio;

    return SizedBox(
      width: 290,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTocar,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImagenRemota(
                url: promocion.bannerUrl,
                ajuste: BoxFit.cover,
                relleno: EdgeInsets.zero,
              ),

              // Degradado para que el texto se lea sobre cualquier banner.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: SizedBox.expand(),
              ),

              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (etiqueta != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          // tipoEtiqueta lo escribe el enum del backend
                          // (TipoPromocion::etiqueta), así que dice "Precio
                          // especial" donde corresponde y no "descuento".
                          promocion.tipoEtiqueta == null
                              ? etiqueta
                              : '$etiqueta · ${promocion.tipoEtiqueta}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),

                    Text(
                      promocion.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (promocion.descripcion != null)
                      Text(
                        promocion.descripcion!,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
