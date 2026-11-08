
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
/// - Desde la vitrina, sin filtros.
/// - Desde un banner de promoción, con `promocionId`.
/// - Desde la búsqueda, con `q`.
///
/// Los controles se dibujan desde `filtrosAplicados`, es decir, desde lo que
/// el backend confirmó que aplicó.
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          titulo,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF202B3C),
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Filtros',
              onPressed: _abrirFiltros,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF334155),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Badge(
                isLabelVisible:
                estado.filtrosAplicados.hayFiltrosDeRefinamiento,
                backgroundColor: const Color(0xFF2563EB),
                child: const Icon(Icons.tune_rounded, size: 21),
              ),
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
                color: const Color(0xFF2563EB),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: controlador,
        enabled: habilitado,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onBuscar(),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF202B3C),
        ),
        decoration: InputDecoration(
          hintText: 'Buscar productos, marcas o códigos',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF64748B),
            size: 21,
          ),
          suffixIcon: IconButton(
            tooltip: 'Buscar',
            onPressed: habilitado ? onBuscar : null,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF2563EB),
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
          ),
        ),
      ),
    );
  }
}

/// Los filtros activos se construyen desde `filtrosAplicados`.
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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => chips[i],
        ),
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
  const _Chip({
    required this.texto,
    required this.onQuitar,
    this.icono,
  });

  final String texto;
  final VoidCallback onQuitar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: icono == null
          ? null
          : Icon(
        icono,
        size: 15,
        color: const Color(0xFF2563EB),
      ),
      label: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
      onDeleted: onQuitar,
      deleteIcon: const Icon(Icons.close_rounded, size: 15),
      deleteIconColor: const Color(0xFF64748B),
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFDBEAFE)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2563EB),
        ),
      );
    }

    // Falló la primera página: no hay nada que mostrar.
    if (estado.errorInicial != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _Contador(estado: estado),

        GrillaProductos(
          productos: estado.productos,
          onIngresar: esInvitado ? onIngresar : null,
          onTocarProducto: (producto) => abrirFicha(context, producto),
        ),

        const SizedBox(height: 20),

        // El error de una página adicional se muestra debajo de los
        // productos ya cargados, sin afectar su contenido.
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
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: estado.cargandoMas
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2563EB),
                ),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Cargar más productos'),
                  SizedBox(width: 8),
                  Icon(Icons.expand_more_rounded, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Muestra cuántos productos están cargados y el total disponible.
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 7),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.search_off_rounded,
            size: 42,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'No encontramos productos',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Color(0xFF202B3C),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          hayRefinamientos
              ? 'Probá quitando algún filtro o buscando con otras palabras.'
              : 'Probá con otras palabras.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        if (hayRefinamientos) ...[
          const SizedBox(height: 24),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => ref.read(catalogoProvider.notifier).buscar(
                estado.filtrosAplicados.limpiarRefinamientos(),
              ),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Quitar filtros'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
