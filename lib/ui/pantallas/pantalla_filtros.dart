
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../datos/modelos/categoria.dart';
import '../../datos/modelos/filtros_catalogo.dart';
import '../../estado/catalogo_notifier.dart';
import '../../estado/catalogo_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';

class PantallaFiltros extends ConsumerStatefulWidget {
  const PantallaFiltros({
    super.key,
    required this.filtrosActuales,
    required this.ordenes,
  });

  final FiltrosCatalogo filtrosActuales;
  final List<OpcionOrden> ordenes;

  @override
  ConsumerState<PantallaFiltros> createState() => _PantallaFiltrosState();
}

class _PantallaFiltrosState extends ConsumerState<PantallaFiltros> {
  late int? _categoriaId;
  late String? _marca;
  late String? _orden;

  final _precioMin = TextEditingController();
  final _precioMax = TextEditingController();

  static const _azul = Color(0xFF2563EB);
  static const _fondo = Color(0xFFF5F7FA);
  static const _texto = Color(0xFF202B3C);
  static const _secundario = Color(0xFF64748B);
  static const _borde = Color(0xFFE8EDF3);

  @override
  void initState() {
    super.initState();

    final f = widget.filtrosActuales;

    _categoriaId = f.categoriaId;
    _marca = f.marca;
    _orden = f.orden;

    _precioMin.text = _comoTexto(f.precioMin);
    _precioMax.text = _comoTexto(f.precioMax);
  }

  @override
  void dispose() {
    _precioMin.dispose();
    _precioMax.dispose();
    super.dispose();
  }

  static String _comoTexto(double? valor) {
    if (valor == null) return '';
    return valor == valor.roundToDouble()
        ? valor.toStringAsFixed(0)
        : valor.toString();
  }

  double? _aDecimal(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return null;

    final normalizado = limpio.replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(normalizado);

    return (valor != null && valor >= 0) ? valor : null;
  }

  void _aplicar() {
    final nuevos = widget.filtrosActuales.copiarCon(
      categoriaId: _categoriaId,
      marca: _marca,
      orden: _orden,
      precioMin: _aDecimal(_precioMin.text),
      precioMax: _aDecimal(_precioMax.text),
      limpiarCategoria: _categoriaId == null,
      limpiarMarca: _marca == null,
      limpiarOrden: _orden == null,
      limpiarPrecioMin: _aDecimal(_precioMin.text) == null,
      limpiarPrecioMax: _aDecimal(_precioMax.text) == null,
    );

    Navigator.of(context).pop(nuevos);
  }

  void _limpiar() {
    setState(() {
      _categoriaId = null;
      _marca = null;
      _orden = null;
      _precioMin.clear();
      _precioMax.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final puedeVerPrecios = ref.watch(usuarioProvider) != null;
    final categorias = ref.watch(categoriasProvider);
    final marcas = ref.watch(marcasProvider);

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Filtros',
          style: TextStyle(
            color: _texto,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _limpiar,
            style: TextButton.styleFrom(
              foregroundColor: _azul,
            ),
            child: const Text('Limpiar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (!puedeVerPrecios) ...[
              const AvisoInformativo(
                titulo: 'Filtros de precio',
                detalle: 'Para filtrar y ordenar por precio tenés que '
                    'ingresar con tu cuenta.',
                icono: Icons.lock_outline,
              ),
              const SizedBox(height: 22),
            ],

            const _TituloFiltro('Ordenar por'),
            const SizedBox(height: 8),
            _SelectorOrden(
              ordenes: widget.ordenes,
              seleccionado: _orden,
              onCambio: (valor) => setState(() => _orden = valor),
            ),

            const SizedBox(height: 22),

            const _TituloFiltro('Categoría'),
            const SizedBox(height: 8),
            categorias.when(
              loading: () => const _CargandoOpciones(),
              error: (_, __) => const _OpcionesNoDisponibles(
                texto: 'No pudimos cargar las categorías.',
              ),
              data: (lista) => _SelectorCategoria(
                categorias: lista,
                seleccionada: _categoriaId,
                onCambio: (valor) => setState(() => _categoriaId = valor),
              ),
            ),

            const SizedBox(height: 22),

            const _TituloFiltro('Marca'),
            const SizedBox(height: 8),
            marcas.when(
              loading: () => const _CargandoOpciones(),
              error: (_, __) => const _OpcionesNoDisponibles(
                texto: 'No pudimos cargar las marcas.',
              ),
              data: (lista) => _SelectorMarca(
                marcas: lista,
                seleccionada: _marca,
                onCambio: (valor) => setState(() => _marca = valor),
              ),
            ),

            if (puedeVerPrecios) ...[
              const SizedBox(height: 22),

              const _TituloFiltro('Precio'),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: CampoFormulario(
                      controlador: _precioMin,
                      etiqueta: 'Desde',
                      tipoTeclado: TextInputType.number,
                      accionTeclado: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoFormulario(
                      controlador: _precioMax,
                      etiqueta: 'Hasta',
                      tipoTeclado: TextInputType.number,
                      accionTeclado: TextInputAction.done,
                      onEnviar: _aplicar,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Text(
                'El rango se compara contra el precio de lista, no contra '
                    'el precio con promoción.',
                style: TextStyle(
                  color: _secundario,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _aplicar,
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Aplicar filtros',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TituloFiltro extends StatelessWidget {
  const _TituloFiltro(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: Color(0xFF202B3C),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SelectorOrden extends StatelessWidget {
  const _SelectorOrden({
    required this.ordenes,
    required this.seleccionado,
    required this.onCambio,
  });

  final List<OpcionOrden> ordenes;
  final String? seleccionado;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    if (ordenes.isEmpty) {
      return const _OpcionesNoDisponibles(
        texto: 'Las opciones de orden se cargan junto con los resultados.',
      );
    }

    final valor =
    ordenes.any((o) => o.valor == seleccionado) ? seleccionado : null;

    return _DropdownEstilizado<String?>(
      valor: valor,
      etiqueta: 'Orden',
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Predeterminado'),
        ),
        for (final opcion in ordenes)
          DropdownMenuItem<String?>(
            value: opcion.valor,
            child: Text(opcion.etiqueta, overflow: TextOverflow.ellipsis),
          ),
      ],
      onCambio: onCambio,
    );
  }
}

class _SelectorCategoria extends StatelessWidget {
  const _SelectorCategoria({
    required this.categorias,
    required this.seleccionada,
    required this.onCambio,
  });

  final List<Categoria> categorias;
  final int? seleccionada;
  final ValueChanged<int?> onCambio;

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) {
      return const _OpcionesNoDisponibles(
        texto: 'No hay categorías con productos publicados.',
      );
    }

    return _DropdownEstilizado<int?>(
      valor: seleccionada,
      etiqueta: 'Categoría',
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todas las categorías'),
        ),
        for (final categoria in categorias)
          DropdownMenuItem<int?>(
            value: categoria.id,
            child: Text(
              categoria.nombre,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onCambio: onCambio,
    );
  }
}

class _SelectorMarca extends StatelessWidget {
  const _SelectorMarca({
    required this.marcas,
    required this.seleccionada,
    required this.onCambio,
  });

  final List<String> marcas;
  final String? seleccionada;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    if (marcas.isEmpty) {
      return const _OpcionesNoDisponibles(
        texto: 'No hay marcas cargadas en los productos publicados.',
      );
    }

    final valor = marcas.contains(seleccionada) ? seleccionada : null;

    return _DropdownEstilizado<String?>(
      valor: valor,
      etiqueta: 'Marca',
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todas las marcas'),
        ),
        for (final marca in marcas)
          DropdownMenuItem<String?>(
            value: marca,
            child: Text(marca, overflow: TextOverflow.ellipsis),
          ),
      ],
      onCambio: onCambio,
    );
  }
}

class _DropdownEstilizado<T> extends StatelessWidget {
  const _DropdownEstilizado({
    required this.valor,
    required this.etiqueta,
    required this.items,
    required this.onCambio,
  });

  final T valor;
  final String etiqueta;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onCambio;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: valor,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF64748B),
      ),
      decoration: InputDecoration(
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.4,
          ),
        ),
      ),
      onChanged: onCambio,
      items: items,
    );
  }
}

class _CargandoOpciones extends StatelessWidget {
  const _CargandoOpciones();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }
}

class _OpcionesNoDisponibles extends StatelessWidget {
  const _OpcionesNoDisponibles({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
        ),
      ),
    );
  }
}
