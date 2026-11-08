
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
  const PantallaProducto({
    super.key,
    required this.productoId,
    this.nombre,
  });

  final int productoId;
  final String? nombre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(fichaProvider(productoId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          ficha.value?.producto.nombre ?? nombre ?? 'Producto',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF202B3C),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202B3C),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [BotonCarrito()],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(fichaProvider(productoId).future),
          child: ficha.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => _Falla(
              error: e,
              onReintentar: () =>
                  ref.invalidate(fichaProvider(productoId)),
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
        MaterialPageRoute<void>(
          builder: (_) => const PantallaLogin(),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Imagen principal.
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: ImagenRemota(
              url: producto.imagenUrl,
              relleno: const EdgeInsets.all(12),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información principal.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE8EDF3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (producto.marca != null) ...[
                      Text(
                        producto.marca!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Color(0xFF202B3C),
                      ),
                    ),

                    const SizedBox(height: 14),

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
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Precio.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE8EDF3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Precio',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 8),

                    PrecioProducto(
                      producto: producto,
                      compacto: false,
                      onIngresar: esInvitado ? irAlLogin : null,
                    ),

                    if (producto.ahorro != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: 17,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ahorrás ${Formato.pesos(producto.ahorro!)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Disponibilidad.
              _Disponibilidad(producto: producto),

              const SizedBox(height: 12),

              // Carrito.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE8EDF3),
                  ),
                ),
                child: AgregarAlCarrito(producto: producto),
              ),

              // Promociones.
              if (detalle.tienePromociones) ...[
                const SizedBox(height: 12),
                ListaPromociones(
                  promociones: detalle.promociones,
                ),
              ],

              // Aviso para invitados.
              if (esInvitado) ...[
                const SizedBox(height: 12),
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

              // Descripción.
              if (detalle.tieneDescripcion) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE8EDF3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: Color(0xFF2563EB),
                            size: 21,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Descripción',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF202B3C),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      const Divider(
                        color: Color(0xFFE8EDF3),
                        height: 1,
                      ),

                      const SizedBox(height: 14),

                      SelectableText(
                        detalle.descripcion!.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Productos relacionados.
        if (detalle.relacionados.isNotEmpty) ...[
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'También te puede interesar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202B3C),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          GrillaProductos(
            productos: detalle.relacionados,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onIngresar: esInvitado ? irAlLogin : null,
            onTocarProducto: (relacionado) =>
                abrirFicha(context, relacionado),
          ),
        ],
      ],
    );
  }
}

class _Disponibilidad extends StatelessWidget {
  const _Disponibilidad({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final enPreventa = producto.enPreventa;
    final unidades = producto.stockDisponible;

    final fondo = enPreventa
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF0FDF4);

    final color = enPreventa
        ? const Color(0xFFB45309)
        : const Color(0xFF15803D);

    final icono = enPreventa
        ? Icons.schedule_rounded
        : Icons.inventory_2_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icono,
              size: 21,
              color: color,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enPreventa ? 'Disponible en preventa' : 'En stock',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  enPreventa
                      ? 'Sin unidades en depósito por ahora. Se puede '
                      'encargar y te avisamos cuando llegue.'
                      : '$unidades ${unidades == 1 ? "unidad" : "unidades"} '
                      'disponibles.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: color,
                  ),
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
  const _Etiqueta({
    required this.texto,
    required this.icono,
  });

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono,
            size: 14,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _Falla extends StatelessWidget {
  const _Falla({
    required this.error,
    required this.onReintentar,
  });

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final esNoEncontrado = error is ErrorNoEncontrado;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),

        if (esNoEncontrado)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE8EDF3),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 32,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Este producto ya no está disponible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202B3C),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Puede que se haya dado de baja o que ya no se publique '
                      'en la tienda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(
                        color: Color(0xFF2563EB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Volver'),
                  ),
                ),
              ],
            ),
          )
        else if (error is ErrorApi)
          AvisoError(
            error: error as ErrorApi,
            onReintentar: onReintentar,
          )
        else
          Text('$error'),
      ],
    );
  }
}
