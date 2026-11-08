import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../datos/modelos/producto.dart';
import '../../datos/modelos/producto_detalle.dart';
import '../../estado/catalogo_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/agregar_al_carrito.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_carrito.dart';
import '../widgets/grilla_productos.dart';
import '../widgets/imagen_remota.dart';
import '../widgets/lista_promociones.dart';
import '../widgets/precio_producto.dart';
import 'pantalla_login.dart';

/// Ficha de producto: `GET /api/v1/productos/{id}`.
///
/// Se abre tocando una tarjeta en la vitrina, en el catálogo o entre los
/// relacionados de otra ficha. Ese último caso es por qué el provider es un
/// `family` por id: la pantalla se apila sobre sí misma y cada instancia
/// necesita su propia respuesta.
///
/// **Qué muestra y qué no**, según lo que el backend realmente da:
///
///  - **Una** imagen. `productos.imagen` es una columna única: no hay galería.
///  - La descripción **como texto**, con sus saltos de línea. Ahí viven las
///    características técnicas y no se modelan aparte; partirlas en pares
///    "clave: valor" sería inventar una estructura que el dato no tiene.
///  - El stock **exacto**, también para el invitado (requerimiento 3.5).
///  - `en_preventa` **tal como llega**. Lo resuelve el backend con
///    `stock_disponible <= 0`, el mismo criterio que la vitrina web.
///  - Precio y promociones aplicadas **solo si el backend los mandó**.
///
/// **Desde el paso 7 hay botón de carrito.** La etapa 4 de la API
/// —`POST /carrito`— ya existe, así que el bloque de [AgregarAlCarrito] va
/// debajo de la disponibilidad, que es donde el cliente ya leyó si hay stock
/// o si va en preventa. El botón cambia según el estado de sesión y no
/// intenta llamadas que el backend va a rechazar; el detalle está en ese
/// widget.
/// Abre la ficha de un producto.
///
/// Vive acá, junto a la pantalla que abre, porque la usan la vitrina, el
/// catálogo y la propia ficha —desde sus relacionados—. Ponerla en cualquiera
/// de las otras dos pantallas haría que se importaran entre sí.
///
/// El `nombre` viaja para que la barra superior tenga título mientras carga,
/// en lugar de aparecer vacía y después saltar.
void abrirFicha(BuildContext context, Producto producto) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PantallaProducto(
        productoId: producto.id,
        nombre: producto.nombre,
      ),
    ),
  );
}

class PantallaProducto extends ConsumerWidget {
  const PantallaProducto({super.key, required this.productoId, this.nombre});

  final int productoId;

  /// El nombre que ya mostraba la tarjeta. Se usa como título mientras carga,
  /// para que la barra no aparezca vacía y después salte.
  final String? nombre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(fichaProvider(productoId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ficha.value?.producto.nombre ?? nombre ?? 'Producto',
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [BotonCarrito()],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(fichaProvider(productoId).future),
          child: ficha.when(
            loading: () => const Center(child: CircularProgressIndicator()),

            error: (e, _) => _Falla(
              error: e,
              onReintentar: () => ref.invalidate(fichaProvider(productoId)),
            ),

            data: (detalle) => _Contenido(detalle: detalle),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.detalle});

  final ProductoDetalle detalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final producto = detalle.producto;
    final esInvitado = ref.watch(usuarioProvider) == null;

    void irAlLogin() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Una sola imagen, en grande. No hay galería porque no hay más de una.
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: AspectRatio(
            aspectRatio: 1,
            child: ImagenRemota(
              url: producto.imagenUrl,
              relleno: const EdgeInsets.all(20),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (producto.marca != null)
                Text(
                  producto.marca!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                ),

              const SizedBox(height: 4),

              Text(
                producto.nombre,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (producto.categoria != null)
                    _Etiqueta(
                      texto: producto.categoria!.nombre,
                      icono: Icons.category_outlined,
                    ),
                  _Etiqueta(
                    texto: 'Código ${producto.codigo}',
                    icono: Icons.qr_code_2,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // El precio grande, con los mismos tres estados que la tarjeta:
              // sin precio para el invitado, con precio, o con precio y
              // descuento. El widget es el mismo del paso 3.
              PrecioProducto(
                producto: producto,
                compacto: false,
                onIngresar: esInvitado ? irAlLogin : null,
              ),

              if (producto.ahorro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Ahorrás ${Formato.pesos(producto.ahorro!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),

              const SizedBox(height: 18),

              _Disponibilidad(producto: producto),

              const SizedBox(height: 16),

              // Va después de la disponibilidad a propósito: el cliente ya
              // leyó si hay stock o si va en preventa, y el botón se lo
              // vuelve a decir en su propio texto.
              AgregarAlCarrito(producto: producto),

              if (detalle.tienePromociones) ...[
                const SizedBox(height: 18),
                ListaPromociones(promociones: detalle.promociones),
              ],

              if (esInvitado) ...[
                const SizedBox(height: 18),
                AvisoInformativo(
                  titulo: 'Los precios se ven con tu cuenta',
                  detalle: 'Podés ver toda la información del producto sin '
                      'ingresar. Para ver el precio y las promociones que le '
                      'aplican, ingresá o creá tu cuenta.',
                  icono: Icons.lock_outline,
                  accion: irAlLogin,
                  textoAccion: 'Ingresar',
                ),
              ],

              if (detalle.tieneDescripcion) ...[
                const SizedBox(height: 24),
                Text(
                  'Descripción',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                // `SelectableText` para que se pueda copiar un número de parte
                // o una especificación. Los saltos de línea del texto cargado
                // se respetan tal cual.
                SelectableText(
                  detalle.descripcion!.trim(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        ),

        if (detalle.relacionados.isNotEmpty) ...[
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'También te puede interesar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          GrillaProductos(
            productos: detalle.relacionados,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onIngresar: esInvitado ? irAlLogin : null,
            // Desde un relacionado se entra a su propia ficha. La pantalla se
            // apila, y por eso el provider es family por id: si fuera uno
            // solo, al volver atrás esta ficha mostraría el otro producto.
            onTocarProducto: (relacionado) => abrirFicha(context, relacionado),
          ),
        ],
      ],
    );
  }

}

/// El stock, con el mismo criterio que la ficha web: **cantidad exacta**, y
/// también para el invitado. Es requerimiento explícito (3.5); lo único
/// reservado es el precio.
///
/// `en_preventa` llega resuelto del backend y no se recalcula: preventa no
/// quiere decir que no se pueda comprar, quiere decir que las unidades
/// todavía no están en el depósito.
class _Disponibilidad extends StatelessWidget {
  const _Disponibilidad({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final enPreventa = producto.enPreventa;
    final unidades = producto.stockDisponible;

    final fondo =
        enPreventa ? colores.tertiaryContainer : colores.secondaryContainer;
    final texto = enPreventa
        ? colores.onTertiaryContainer
        : colores.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enPreventa ? Icons.schedule : Icons.inventory_2_outlined,
            size: 20,
            color: texto,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enPreventa ? 'Preventa' : 'Disponible',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: texto),
                ),
                const SizedBox(height: 2),
                Text(
                  enPreventa
                      ? 'Sin unidades en depósito por ahora. Se puede '
                          'encargar y te avisamos cuando llegue.'
                      : '$unidades ${unidades == 1 ? "unidad" : "unidades"} '
                          'disponibles.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: texto),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: colores.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: colores.outline),
          const SizedBox(width: 5),
          Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colores.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _Falla extends StatelessWidget {
  const _Falla({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    // Un 404 acá es un caso real y no un error de programación: `show()`
    // responde 404 cuando el producto se dio de baja o se despublicó, y la
    // tarjeta que el usuario tocó pudo haberse dibujado minutos antes.
    final esNoEncontrado = error is ErrorNoEncontrado;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),

        if (esNoEncontrado)
          Column(
            children: [
              Icon(
                Icons.remove_shopping_cart_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Este producto ya no está disponible',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Puede que se haya dado de baja o que ya no se publique en '
                'la tienda.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ),
            ],
          )
        else if (error is ErrorApi)
          AvisoError(error: error as ErrorApi, onReintentar: onReintentar)
        else
          Text('$error'),
      ],
    );
  }
}
