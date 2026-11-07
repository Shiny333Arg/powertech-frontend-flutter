import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../datos/modelos/categoria.dart';
import '../../datos/modelos/filtros_catalogo.dart';
import '../../estado/catalogo_notifier.dart';
import '../../estado/catalogo_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';

/// Pantalla de filtros del catálogo.
///
/// Devuelve un [FiltrosCatalogo] con `Navigator.pop` cuando se aplica, o null
/// si el usuario sale sin aplicar. Quien decide qué hacer con eso es el
/// catálogo.
///
/// **Nada está hardcodeado:** las categorías vienen de `/categorias`, las
/// marcas de `/marcas` y las opciones de orden del bloque `ordenes` de la
/// última respuesta de `/productos`. Esa última parte importa: el backend
/// manda cuatro opciones al invitado y seis al cliente, así que la lista no se
/// arma acá ni se filtra acá.
///
/// **Para el invitado no se muestran el rango de precio ni los órdenes por
/// precio.** Los segundos ni siquiera llegan en `ordenes`. El rango se oculta
/// porque `aplicarFiltrosDePrecio()` lo ignora en silencio: dejar los campos
/// visibles sería ofrecer un control que no hace nada. El motivo de fondo está
/// en el docblock de ese método y es bueno: con una veintena de consultas de
/// rango, un invitado deduce el precio exacto de cualquier producto sin que se
/// le haya mostrado un solo importe.
class PantallaFiltros extends ConsumerStatefulWidget {
  const PantallaFiltros({
    super.key,
    required this.filtrosActuales,
    required this.ordenes,
  });

  final FiltrosCatalogo filtrosActuales;

  /// Las opciones que ofreció el backend en la última respuesta.
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

  @override
  void initState() {
    super.initState();

    final f = widget.filtrosActuales;

    _categoriaId = f.categoriaId;
    _marca = f.marca;
    _orden = f.orden;

    // Se muestran como enteros cuando no tienen decimales: "15000" se lee
    // mejor que "15000.0" en un campo que el usuario va a editar.
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

  /// El texto se manda tal cual lo escribió el usuario, sin parsear.
  ///
  /// `BusquedaProductoRequest::aDecimal()` ya acepta "15.000,50", "15000.50" y
  /// "$ 15000", y además da vuelta un mínimo mayor que el máximo. Parsearlo
  /// acá sería un segundo lugar decidiendo lo mismo, con otro criterio y en
  /// otro idioma de separadores.
  double? _aDecimal(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return null;

    // Solo lo necesario para poder mandarlo como número en el querystring:
    // se quitan los puntos de miles y la coma pasa a punto.
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
      appBar: AppBar(
        title: const Text('Filtros'),
        actions: [
          TextButton(
            onPressed: _limpiar,
            child: const Text('Limpiar'),
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!puedeVerPrecios)
              const AvisoInformativo(
                titulo: 'Filtros de precio',
                detalle: 'Para filtrar y ordenar por precio tenés que '
                    'ingresar con tu cuenta.',
                icono: Icons.lock_outline,
              ),

            const _Titulo('Ordenar por'),

            _SelectorOrden(
              ordenes: widget.ordenes,
              seleccionado: _orden,
              onCambio: (valor) => setState(() => _orden = valor),
            ),

            const SizedBox(height: 8),
            const _Titulo('Categoría'),

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

            const SizedBox(height: 8),
            const _Titulo('Marca'),

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

            // Solo para quien puede ver precios. Ver el docblock de la clase.
            if (puedeVerPrecios) ...[
              const SizedBox(height: 8),
              const _Titulo('Precio'),

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

              Text(
                'El rango se compara contra el precio de lista, no contra el '
                'precio con promoción.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 28),

            FilledButton(
              onPressed: _aplicar,
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desplegable de orden.
///
/// **La lista llega del backend y no se completa ni se recorta acá.** Si el
/// visitante es invitado, `ordenesDisponibles()` ya quitó "Menor precio" y
/// "Mayor precio" antes de mandarla.
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
    // Vacía solo si la primera carga falló: no se inventan opciones.
    if (ordenes.isEmpty) {
      return const _OpcionesNoDisponibles(
        texto: 'Las opciones de orden se cargan junto con los resultados.',
      );
    }

    // Un orden que ya no está entre las opciones se descarta. Pasa cuando el
    // cliente ordenó por precio y después cerró sesión: el backend deja de
    // ofrecer esa opción, y un Dropdown con un valor que no está entre sus
    // items lanza una excepción.
    final valor =
        ordenes.any((o) => o.valor == seleccionado) ? seleccionado : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String?>(
        initialValue: valor,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Orden',
          border: OutlineInputBorder(),
        ),
        onChanged: onCambio,
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
      ),
    );
  }
}

/// Desplegable de categorías con la opción "todas" arriba.
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int?>(
        initialValue: seleccionada,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Categoría',
          border: OutlineInputBorder(),
        ),
        onChanged: onCambio,
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Todas las categorías'),
          ),
          for (final categoria in categorias)
            DropdownMenuItem<int?>(
              value: categoria.id,
              child: Text(categoria.nombre, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
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

    // Si la marca del filtro ya no está en la lista —se despublicó el último
    // producto de esa marca— el valor se descarta en lugar de romper el
    // Dropdown, que exige que el valor exista entre los items.
    final valor = marcas.contains(seleccionada) ? seleccionada : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String?>(
        initialValue: valor,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Marca',
          border: OutlineInputBorder(),
        ),
        onChanged: onCambio,
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
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _CargandoOpciones extends StatelessWidget {
  const _CargandoOpciones();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Una lista de opciones que no se pudo traer no bloquea el resto de la
/// pantalla: los otros filtros siguen usables.
class _OpcionesNoDisponibles extends StatelessWidget {
  const _OpcionesNoDisponibles({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}
