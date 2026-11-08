
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../datos/modelos/filtros_catalogo.dart';
import '../../datos/modelos/producto.dart';
import '../../datos/modelos/promocion.dart';
import '../../datos/modelos/vitrina.dart';
import '../../estado/catalogo_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_carrito.dart';
import '../widgets/carrusel_promociones.dart';
import '../widgets/grilla_productos.dart';
import 'pantalla_catalogo.dart';
import 'pantalla_inicio.dart';
import 'pantalla_login.dart';
import 'pantalla_producto.dart';

/// La vitrina: GET /api/v1/home.
class PantallaVitrina extends ConsumerWidget {
  const PantallaVitrina({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitrina = ref.watch(vitrinaProvider);
    final usuario = ref.watch(usuarioProvider);
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/Logo_Primary.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'PowerTech',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 21,
                letterSpacing: -0.5,
                color: Color(0xFF202B3C),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar en el catálogo',
            icon: const Icon(Icons.search_rounded),
            color: const Color(0xFF475569),
            onPressed: () => _irAlCatalogo(context),
          ),

          const BotonCarrito(),

          if (usuario == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => _irAlLogin(context),
                child: const Text(
                  'Ingresar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.person_outline_rounded),
              color: const Color(0xFF475569),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PantallaInicio(usuario: usuario),
                ),
              ),
            ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(vitrinaProvider.future),
          child: vitrina.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),

            error: (e, _) => _FallaVitrina(
              error: e,
              onReintentar: () => ref.invalidate(vitrinaProvider),
            ),

            data: (datos) => _Contenido(
              vitrina: datos,
              esInvitado: usuario == null,
              onIngresar: () => _irAlLogin(context),
              onVerCatalogo: () => _irAlCatalogo(context),
              onTocarPromocion: (promocion) =>
                  _irAlCatalogo(context, promocion: promocion),
              onTocarProducto: (producto) =>
                  abrirFicha(context, producto),
            ),
          ),
        ),
      ),
    );
  }

  void _irAlLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PantallaLogin(),
      ),
    );
  }

  /// Abre el catálogo, opcionalmente filtrado por una promoción.
  void _irAlCatalogo(BuildContext context, {Promocion? promocion}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaCatalogo(
          filtrosIniciales: promocion == null
              ? null
              : FiltrosCatalogo(promocionId: promocion.id),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.vitrina,
    required this.esInvitado,
    required this.onIngresar,
    required this.onVerCatalogo,
    required this.onTocarPromocion,
    required this.onTocarProducto,
  });

  final Vitrina vitrina;
  final bool esInvitado;
  final VoidCallback onIngresar;
  final VoidCallback onVerCatalogo;
  final void Function(Promocion) onTocarPromocion;
  final void Function(Producto) onTocarProducto;

  @override
  Widget build(BuildContext context) {
    if (vitrina.estaVacia) return const _VitrinaVacia();

    final secciones = vitrina.seccionesConProductos;
    final colores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        // Encabezado principal.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Encontrá lo que necesitás.',
                style: TextStyle(
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Explorá nuestros productos y descubrí las novedades.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // Aviso para visitantes sin iniciar sesión.
        if (esInvitado)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: AvisoInformativo(
              titulo: 'Los precios se ven con tu cuenta',
              detalle: 'Podés recorrer todo el catálogo sin ingresar. '
                  'Para ver precios y comprar, ingresá o creá tu cuenta.',
              icono: Icons.lock_outline_rounded,
              accion: onIngresar,
              textoAccion: 'Ingresar',
            ),
          ),

        // Promociones.
        if (vitrina.promociones.isNotEmpty) ...[
          const _TituloSeccion('Promociones'),
          CarruselPromociones(
            promociones: vitrina.promociones,
            onTocar: onTocarPromocion,
          ),
          const SizedBox(height: 12),
        ],

        // Secciones de productos.
        for (final seccion in secciones) ...[
          _TituloSeccion(seccion.titulo),
          GrillaProductos(
            productos: seccion.productos,
            onIngresar: esInvitado ? onIngresar : null,
            onTocarProducto: onTocarProducto,
          ),
        ],

        // Acceso al catálogo completo.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onVerCatalogo,
              icon: const Icon(Icons.grid_view_rounded, size: 19),
              label: const Text(
                'Ver todo el catálogo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colores.primary,
                side: BorderSide(
                  color: colores.primary.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 23,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Color(0xFF202B3C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conexión buena, respuesta válida, pero nada publicado.
class _VitrinaVacia extends StatelessWidget {
  const _VitrinaVacia();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 100, 28, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colores.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 52,
                  color: colores.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Todavía no hay nada publicado',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202B3C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'La conexión con el servidor funciona, pero no hay '
                    'promociones vigentes ni productos publicados para mostrar.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FallaVitrina extends StatelessWidget {
  const _FallaVitrina({
    required this.error,
    required this.onReintentar,
  });

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),

        if (error is ErrorApi)
          AvisoError(
            error: error as ErrorApi,
            onReintentar: onReintentar,
          )
        else
          Text('$error'),

        const SizedBox(height: 12),

        const Text(
          'No pudimos cargar la vitrina. Si el problema sigue, mirá el '
              'diagnóstico de conexión desde el ícono de la barra superior.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
