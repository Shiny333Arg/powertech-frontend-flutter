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
import 'pantalla_diagnostico.dart';
import 'pantalla_inicio.dart';
import 'pantalla_login.dart';
import 'pantalla_producto.dart';

/// La vitrina: `GET /api/v1/home`.
///
/// **Es la pantalla de arranque para todos**, con sesión o sin ella. Eso da
/// vuelta lo que el paso 2 dejó provisorio: hasta ahora el invitado veía el
/// login porque no había otra cosa que mostrarle; ahora entra acá y el login
/// pasa a ser un destino al que se llega, no una pared. Es lo que dice el
/// contrato: iniciar sesión no es obligatorio al arrancar la app.
///
/// La diferencia entre los dos visitantes es una sola y la decide el backend:
/// las tarjetas traen precio o no lo traen. Todo lo demás —productos, orden,
/// stock, promociones— es idéntico.
class PantallaVitrina extends ConsumerWidget {
  const PantallaVitrina({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitrina = ref.watch(vitrinaProvider);
    final usuario = ref.watch(usuarioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerTech'),
        actions: [
          IconButton(
            tooltip: 'Buscar en el catálogo',
            icon: const Icon(Icons.search),
            onPressed: () => _irAlCatalogo(context),
          ),

          const BotonCarrito(),

          IconButton(
            tooltip: 'Diagnóstico de conexión',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PantallaDiagnostico(),
              ),
            ),
          ),

          if (usuario == null)
            TextButton(
              onPressed: () => _irAlLogin(context),
              child: const Text('Ingresar'),
            )
          else
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.person_outline),
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
            loading: () => const Center(child: CircularProgressIndicator()),

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
              onTocarProducto: (producto) => abrirFicha(context, producto),
            ),
          ),
        ),
      ),
    );
  }

  void _irAlLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
    );
  }

  /// Abre el catálogo, opcionalmente filtrado por una promoción.
  ///
  /// **Es lo que el paso 3 dejó preparado con `onTocar: null`.** El filtro
  /// viaja como `?promocion={id}` y el backend devuelve el objeto `promocion`
  /// en la respuesta, que es lo que el catálogo usa para titular la lista con
  /// el nombre del banner que el cliente tocó.
  ///
  /// Si la promoción venció entre que se dibujó el banner y que se tocó,
  /// `promocionDelFiltro()` devuelve null, el controlador descarta el filtro y
  /// la app muestra el catálogo completo en lugar de una lista vacía. No hay
  /// nada que manejar acá: ya está resuelto del lado del servidor.
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (esInvitado)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AvisoInformativo(
              titulo: 'Los precios se ven con tu cuenta',
              detalle: 'Podés recorrer todo el catálogo sin ingresar. '
                  'Para ver precios y comprar, ingresá o creá tu cuenta.',
              icono: Icons.lock_outline,
              accion: onIngresar,
              textoAccion: 'Ingresar',
            ),
          ),

        if (vitrina.promociones.isNotEmpty) ...[
          const _TituloSeccion('Promociones'),
          // Desde el paso 4 el banner lleva al catálogo filtrado por esa
          // promoción: `?promocion={id}`.
          CarruselPromociones(
            promociones: vitrina.promociones,
            onTocar: onTocarPromocion,
          ),
          const SizedBox(height: 8),
        ],

        for (final seccion in secciones) ...[
          _TituloSeccion(seccion.titulo),
          GrillaProductos(
            productos: seccion.productos,
            onIngresar: esInvitado ? onIngresar : null,
            onTocarProducto: onTocarProducto,
          ),
        ],

        const SizedBox(height: 28),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: onVerCatalogo,
            icon: const Icon(Icons.grid_view_outlined),
            label: const Text('Ver todo el catálogo'),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Conexión buena, respuesta válida, pero nada publicado. Pasa con una base
/// recién sembrada o con todo despublicado, y no es un error: merece un
/// cartel propio y no la pantalla de fallo.
class _VitrinaVacia extends StatelessWidget {
  const _VitrinaVacia();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Todavía no hay nada publicado',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'La conexión con el servidor funciona, pero no hay '
                'promociones vigentes ni productos publicados para mostrar.',
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
  const _FallaVitrina({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),

        if (error is ErrorApi)
          AvisoError(error: error as ErrorApi, onReintentar: onReintentar)
        else
          Text('$error'),

        const Text(
          'No pudimos cargar la vitrina. Si el problema sigue, mirá el '
          'diagnóstico de conexión desde el ícono de la barra superior.',
        ),
      ],
    );
  }
}
