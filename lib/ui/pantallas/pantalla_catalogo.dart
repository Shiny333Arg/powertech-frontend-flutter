import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../datos/modelos/filtros_catalogo.dart';
import '../../estado/catalogo_notifier.dart';
import '../../estado/catalogo_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/grilla_productos.dart';
import 'pantalla_filtros.dart';
import 'pantalla_login.dart';
import 'pantalla_producto.dart';

/// Catálogo paginado: `GET /api/v1/productos`.
///
/// Se abre de tres maneras y las tres pasan por [filtrosIniciales]:
///
///  - desde la vitrina, sin filtros;
///  - desde un banner de promoción, con `promocionId`;
///  - desde la búsqueda, con `q`.
///
/// **Los controles se dibujan desde `filtrosAplicados`**, o sea desde lo que
/// el backend dijo que aplicó, no desde lo que el usuario pidió. Para el
/// invitado que pidió un rango de precio, esos chips no aparecen: el servidor
/// lo descartó y la pantalla no sostiene filtros fantasma.
class PantallaCatalogo extends ConsumerStatefulWidget {
  const PantallaCatalogo({super.key, this.filtrosIniciales});

  final FiltrosCatalogo? filtrosIniciales;

  @override
  ConsumerState<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends ConsumerState<PantallaCatalogo> {
  final _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();

    final iniciales = widget.filtrosIniciales ?? const FiltrosCatalogo();

    _busqueda.text = iniciales.q ?? '';

    // El provider todavía no existe durante initState: se difiere a la
    // microtarea siguiente, igual que la restauración de sesión del paso 2.
    Future.microtask(() {
      if (mounted) {
        ref.read(catalogoProvider.notifier).iniciar(iniciales);
      }
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _buscarTexto() {
    FocusScope.of(context).unfocus();

    final estado = ref.read(catalogoProvider);
    final texto = _busqueda.text.trim();

    ref.read(catalogoProvider.notifier).buscar(
          estado.filtrosAplicados.copiarCon(
            q: texto.isEmpty ? null : texto,
            limpiarQ: texto.isEmpty,
          ),
        );
  }

  Future<void> _abrirFiltros() async {
    final estado = ref.read(catalogoProvider);

    final nuevos = await Navigator.of(context).push<FiltrosCatalogo>(
      MaterialPageRoute(
        builder: (_) => PantallaFiltros(
          filtrosActuales: estado.filtrosAplicados,
          ordenes: estado.ordenes,
        ),
      ),
    );

    // null = salió sin aplicar.
    if (nuevos != null && mounted) {
      ref.read(catalogoProvider.notifier).buscar(nuevos);
    }
  }

  void _irAlLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(catalogoProvider);
    final esInvitado = ref.watch(usuarioProvider) == null;

    final titulo = estado.promocion?.nombre ?? 'Catálogo';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _abrirFiltros,
            icon: Badge(
              isLabelVisible:
                  estado.filtrosAplicados.hayFiltrosDeRefinamiento,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            _BarraBusqueda(
              controlador: _busqueda,
              onBuscar: _buscarTexto,
              habilitado: !estado.cargandoPrimera,
            ),

            if (estado.filtrosAplicados.cantidadActivos > 0)
              _ChipsDeFiltros(estado: estado),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(catalogoProvider.notifier).recargar(),
                child: _Cuerpo(
                  estado: estado,
                  esInvitado: esInvitado,
                  onIngresar: _irAlLogin,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraBusqueda extends StatelessWidget {
  const _BarraBusqueda({
    required this.controlador,
    required this.onBuscar,
    required this.habilitado,
  });

  final TextEditingController controlador;
  final VoidCallback onBuscar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controlador,
        enabled: habilitado,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onBuscar(),
        decoration: InputDecoration(
          hintText: 'Buscar productos, marcas o códigos',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.arrow_forward),
            onPressed: habilitado ? onBuscar : null,
          ),
        ),
      ),
    );
  }
}

/// Los filtros activos, cada uno con su "quitar".
///
/// Se arman desde `filtrosAplicados`: si el backend descartó un filtro, su
/// chip no aparece, y eso le dice al usuario qué está pasando sin ningún
/// cartel extra.
class _ChipsDeFiltros extends ConsumerWidget {
  const _ChipsDeFiltros({required this.estado});

  final EstadoCatalogo estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = estado.filtrosAplicados;
    final notifier = ref.read(catalogoProvider.notifier);
    final categorias = ref.watch(categoriasProvider).value;

    String nombreCategoria(int id) {
      final encontrada = categorias?.where((c) => c.id == id);
      return (encontrada == null || encontrada.isEmpty)
          ? 'Categoría'
          : encontrada.first.nombre;
    }

    final chips = <Widget>[
      if (f.q != null)
        _Chip(
          texto: '"${f.q}"',
          onQuitar: () => notifier.quitarFiltro(q: true),
        ),

      if (f.promocionId != null)
        _Chip(
          texto: estado.promocion?.nombre ?? 'Promoción',
          icono: Icons.local_offer_outlined,
          onQuitar: () => notifier.quitarFiltro(promocion: true),
        ),

      if (f.categoriaId != null)
        _Chip(
          texto: nombreCategoria(f.categoriaId!),
          onQuitar: () => notifier.quitarFiltro(categoria: true),
        ),

      if (f.marca != null)
        _Chip(
          texto: f.marca!,
          onQuitar: () => notifier.quitarFiltro(marca: true),
        ),

      if (f.precioMin != null || f.precioMax != null)
        _Chip(
          texto: _rangoDePrecio(f),
          onQuitar: () => notifier.quitarFiltro(precio: true),
        ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  static String _rangoDePrecio(FiltrosCatalogo f) {
    final min = f.precioMin;
    final max = f.precioMax;

    if (min != null && max != null) {
      return '${Formato.pesos(min)} - ${Formato.pesos(max)}';
    }

    return min != null
        ? 'Desde ${Formato.pesos(min)}'
        : 'Hasta ${Formato.pesos(max!)}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.onQuitar, this.icono});

  final String texto;
  final VoidCallback onQuitar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: icono == null ? null : Icon(icono, size: 16),
      label: Text(texto, overflow: TextOverflow.ellipsis),
      onDeleted: onQuitar,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.estado,
    required this.esInvitado,
    required this.onIngresar,
  });

  final EstadoCatalogo estado;
  final bool esInvitado;
  final VoidCallback onIngresar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (estado.cargandoPrimera) {
      return const Center(child: CircularProgressIndicator());
    }

    // Falló la primera página: no hay nada que mostrar.
    if (estado.errorInicial != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          AvisoError(
            error: estado.errorInicial!,
            onReintentar: () =>
                ref.read(catalogoProvider.notifier).recargar(),
          ),
        ],
      );
    }

    if (estado.sinResultados) return const _SinResultados();

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _Contador(estado: estado),

        GrillaProductos(
          productos: estado.productos,
          onIngresar: esInvitado ? onIngresar : null,
          onTocarProducto: (producto) => abrirFicha(context, producto),
        ),

        const SizedBox(height: 16),

        // El error de una página adicional va al pie, debajo de los productos
        // que ya se cargaron. Esos no se tocan.
        if (estado.errorAlCargarMas != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AvisoError(
              error: estado.errorAlCargarMas!,
              onReintentar: () =>
                  ref.read(catalogoProvider.notifier).reintentarCargarMas(),
            ),
          )
        else if (estado.hayMas)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: estado.cargandoMas
                  ? null
                  : () => ref.read(catalogoProvider.notifier).cargarMas(),
              child: estado.cargandoMas
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cargar más'),
            ),
          ),
      ],
    );
  }
}

/// "Mostrando 24 de 57". Es lo que hace visible que la paginación funciona.
class _Contador extends StatelessWidget {
  const _Contador({required this.estado});

  final EstadoCatalogo estado;

  @override
  Widget build(BuildContext context) {
    final mostrados = estado.cantidadMostrada;
    final total = estado.total;

    final texto = mostrados == total
        ? '$total ${total == 1 ? "producto" : "productos"}'
        : 'Mostrando $mostrados de $total';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

class _SinResultados extends ConsumerWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(catalogoProvider);
    final hayRefinamientos =
        estado.filtrosAplicados.hayFiltrosDeRefinamiento;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      children: [
        Icon(
          Icons.search_off,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'No encontramos productos',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          hayRefinamientos
              ? 'Probá quitando algún filtro o buscando con otras palabras.'
              : 'Probá con otras palabras.',
          textAlign: TextAlign.center,
        ),
        if (hayRefinamientos) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: () => ref.read(catalogoProvider.notifier).buscar(
                    estado.filtrosAplicados.limpiarRefinamientos(),
                  ),
              child: const Text('Quitar filtros'),
            ),
          ),
        ],
      ],
    );
  }
}
