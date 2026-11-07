import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errores.dart';
import '../datos/modelos/filtros_catalogo.dart';
import '../datos/modelos/producto.dart';
import '../datos/modelos/promocion.dart';
import '../datos/modelos/resultado_catalogo.dart';
import 'proveedores_core.dart';
import 'sesion_providers.dart';

/// Estado del catálogo paginado.
///
/// **Los productos se acumulan, no se reemplazan.** Es lo que pide el botón
/// "Cargar más": la página 2 se agrega abajo de la 1. Una búsqueda nueva o un
/// cambio de filtros sí empieza de cero.
///
/// **El error de una página adicional se guarda aparte de el de la primera.**
/// Son dos situaciones distintas: si falla la primera, no hay nada que mostrar
/// y la pantalla es un error; si falla la cuarta, los 72 productos que ya
/// están tienen que seguir en pantalla y lo único que cambia es que aparece un
/// aviso con "Reintentar" al pie. Un solo campo de error obligaría a elegir
/// entre perder lo cargado o esconder el fallo.
class EstadoCatalogo {
  const EstadoCatalogo({
    this.productos = const [],
    this.filtros = const FiltrosCatalogo(),
    this.filtrosAplicados = const FiltrosCatalogo(),
    this.ordenes = const [],
    this.promocion,
    this.paginaActual = 0,
    this.ultimaPagina = 0,
    this.total = 0,
    this.cargandoPrimera = false,
    this.cargandoMas = false,
    this.errorInicial,
    this.errorAlCargarMas,
    this.huboPrimeraCarga = false,
  });

  /// Todo lo traído hasta ahora, en el orden en que llegó.
  final List<Producto> productos;

  /// Lo que la app pidió. Es lo que la pantalla de filtros edita.
  final FiltrosCatalogo filtros;

  /// Lo que el backend dijo que aplicó. Puede diferir de [filtros]: al
  /// invitado se le descartan el rango de precio y el orden por precio.
  /// **Los controles se dibujan desde este, no desde el de arriba**, para que
  /// la pantalla nunca muestre un filtro que el servidor ignoró.
  final FiltrosCatalogo filtrosAplicados;

  /// Opciones de orden que ofreció el backend para este visitante.
  final List<OpcionOrden> ordenes;

  /// La promoción del filtro, para titular la lista.
  final Promocion? promocion;

  final int paginaActual;
  final int ultimaPagina;
  final int total;

  final bool cargandoPrimera;
  final bool cargandoMas;

  /// Falló la primera página: no hay nada que mostrar.
  final ErrorApi? errorInicial;

  /// Falló una página adicional: lo ya cargado sigue en pantalla.
  final ErrorApi? errorAlCargarMas;

  /// Distingue "todavía no pedí nada" de "pedí y vino vacío". Sin esto, el
  /// arranque y el "sin resultados" se verían iguales.
  final bool huboPrimeraCarga;

  bool get hayMas => paginaActual > 0 && paginaActual < ultimaPagina;

  bool get sinResultados =>
      huboPrimeraCarga &&
      productos.isEmpty &&
      errorInicial == null &&
      !cargandoPrimera;

  /// Cuántos productos de los `total` ya se trajeron. Alimenta el "Mostrando
  /// 24 de 57".
  int get cantidadMostrada => productos.length;

  EstadoCatalogo copiarCon({
    List<Producto>? productos,
    FiltrosCatalogo? filtros,
    FiltrosCatalogo? filtrosAplicados,
    List<OpcionOrden>? ordenes,
    Promocion? promocion,
    int? paginaActual,
    int? ultimaPagina,
    int? total,
    bool? cargandoPrimera,
    bool? cargandoMas,
    ErrorApi? errorInicial,
    ErrorApi? errorAlCargarMas,
    bool? huboPrimeraCarga,
    bool limpiarPromocion = false,
    bool limpiarErrorInicial = false,
    bool limpiarErrorAlCargarMas = false,
  }) {
    return EstadoCatalogo(
      productos: productos ?? this.productos,
      filtros: filtros ?? this.filtros,
      filtrosAplicados: filtrosAplicados ?? this.filtrosAplicados,
      ordenes: ordenes ?? this.ordenes,
      promocion: limpiarPromocion ? null : (promocion ?? this.promocion),
      paginaActual: paginaActual ?? this.paginaActual,
      ultimaPagina: ultimaPagina ?? this.ultimaPagina,
      total: total ?? this.total,
      cargandoPrimera: cargandoPrimera ?? this.cargandoPrimera,
      cargandoMas: cargandoMas ?? this.cargandoMas,
      errorInicial:
          limpiarErrorInicial ? null : (errorInicial ?? this.errorInicial),
      errorAlCargarMas: limpiarErrorAlCargarMas
          ? null
          : (errorAlCargarMas ?? this.errorAlCargarMas),
      huboPrimeraCarga: huboPrimeraCarga ?? this.huboPrimeraCarga,
    );
  }
}

/// El catálogo.
///
/// **Sin el modificador `.autoDispose`, y la pantalla no depende de que lo
/// tenga.** Riverpod 3 unificó los tipos `AutoDisposeNotifier` y `Notifier`, y
/// la guía de migración no aclara si el modificador del provider sigue
/// existiendo con la misma forma. Antes que apoyarse en eso, la pantalla
/// vuelve a buscar en cada apertura (ver [iniciar]): así el comportamiento es
/// el mismo se descarte el estado o no, y la declaración es idéntica a la de
/// `sesionProvider`, que ya está validada.
///
/// Esto importa en un caso concreto: entrar por un banner de promoción, salir,
/// y abrir el catálogo general. Si el estado sobrevive y la pantalla no
/// volviera a buscar, el catálogo general mostraría la lista filtrada de
/// antes.
final catalogoProvider = NotifierProvider<CatalogoNotifier, EstadoCatalogo>(
  CatalogoNotifier.new,
);

class CatalogoNotifier extends Notifier<EstadoCatalogo> {
  @override
  EstadoCatalogo build() {
    // **Recarga automática al iniciar o cerrar sesión.** Los mismos productos
    // traen precio o no lo traen, y además cambian las opciones de orden y los
    // filtros que el backend acepta. Se vuelve a buscar con los mismos
    // filtros en lugar de invalidar el provider: invalidarlo descartaría la
    // búsqueda y los filtros que el usuario tiene puestos, y lo devolvería a
    // un catálogo vacío.
    //
    // Por eso este provider NO está en `SesionNotifier._invalidarCatalogo()`.
    ref.listen(sesionProvider, (anterior, actual) {
      final cambio = _esAutenticado(anterior) != _esAutenticado(actual);

      if (cambio && state.huboPrimeraCarga) {
        buscar(state.filtros);
      }
    });

    return const EstadoCatalogo();
  }

  static bool _esAutenticado(EstadoSesion? estado) =>
      estado is SesionAutenticada;

  /// Carga inicial de la pantalla, desde su `initState`.
  ///
  /// **Busca siempre, incluso si ya hay un estado cargado**, y eso es
  /// deliberado: si el provider sobrevivió a la pantalla anterior, su estado
  /// corresponde a otros filtros. Un guard por `huboPrimeraCarga` dejaría al
  /// catálogo general mostrando la promoción que el usuario miró antes.
  Future<void> iniciar(FiltrosCatalogo filtros) => buscar(filtros);

  /// Búsqueda nueva: descarta lo acumulado y arranca en la página 1.
  ///
  /// Es lo que llaman el campo de búsqueda, la pantalla de filtros y el
  /// "quitar" de cada chip.
  Future<void> buscar(FiltrosCatalogo filtros) async {
    // Los productos de la búsqueda anterior se descartan acá y no al llegar
    // la respuesta. Mientras carga, la pantalla muestra el indicador y no la
    // lista vieja: dejarla visible bajo los filtros nuevos sería mostrar
    // resultados que no corresponden a lo que dice la pantalla.
    state = state.copiarCon(
      filtros: filtros,
      productos: const [],
      paginaActual: 0,
      ultimaPagina: 0,
      total: 0,
      cargandoPrimera: true,
      cargandoMas: false,
      limpiarErrorInicial: true,
      limpiarErrorAlCargarMas: true,
    );

    try {
      final resultado =
          await ref.read(catalogoRepositoryProvider).buscar(filtros);

      state = _conResultado(resultado, acumular: false);
    } on ErrorApi catch (e) {
      state = state.copiarCon(
        cargandoPrimera: false,
        errorInicial: e,
        huboPrimeraCarga: true,
        // Una búsqueda que falla deja la lista vacía: mostrar los resultados
        // de la búsqueda anterior bajo los filtros nuevos sería mentir.
        productos: const [],
        paginaActual: 0,
        ultimaPagina: 0,
        total: 0,
      );
    }
  }

  /// Trae la página siguiente y la agrega al final.
  ///
  /// Si falla, **lo cargado no se toca**: solo se anota el error para que la
  /// pantalla ofrezca reintentar al pie de la lista.
  Future<void> cargarMas() async {
    if (state.cargandoMas || state.cargandoPrimera || !state.hayMas) return;

    state = state.copiarCon(
      cargandoMas: true,
      limpiarErrorAlCargarMas: true,
    );

    try {
      final resultado = await ref.read(catalogoRepositoryProvider).buscar(
            // Se reenvían los filtros que el backend confirmó, no los que la
            // app pidió: si descartó el rango de precio por ser invitado, no
            // tiene sentido volver a mandarlo en cada página.
            state.filtrosAplicados,
            pagina: state.paginaActual + 1,
          );

      state = _conResultado(resultado, acumular: true);
    } on ErrorApi catch (e) {
      state = state.copiarCon(cargandoMas: false, errorAlCargarMas: e);
    }
  }

  /// Reintenta la página que falló, sin perder lo que ya está.
  Future<void> reintentarCargarMas() => cargarMas();

  /// Vuelve a pedir desde la página 1 con los filtros actuales. Es el
  /// pull-to-refresh y el "Reintentar" del error inicial.
  Future<void> recargar() => buscar(state.filtros);

  /// Quita un filtro puntual desde su chip y vuelve a buscar.
  Future<void> quitarFiltro({
    bool q = false,
    bool categoria = false,
    bool marca = false,
    bool precio = false,
    bool promocion = false,
  }) {
    final nuevos = state.filtrosAplicados.copiarCon(
      limpiarQ: q,
      limpiarCategoria: categoria,
      limpiarMarca: marca,
      limpiarPrecioMin: precio,
      limpiarPrecioMax: precio,
      limpiarPromocion: promocion,
    );

    return buscar(nuevos);
  }

  EstadoCatalogo _conResultado(
    ResultadoCatalogo resultado, {
    required bool acumular,
  }) {
    final pagina = resultado.pagina;

    return state.copiarCon(
      productos: acumular
          ? [...state.productos, ...pagina.items]
          : pagina.items,
      filtrosAplicados: resultado.filtrosAplicados,
      ordenes: resultado.ordenes,
      promocion: resultado.promocion,
      limpiarPromocion: resultado.promocion == null,
      paginaActual: pagina.paginaActual,
      ultimaPagina: pagina.ultimaPagina,
      total: pagina.total,
      cargandoPrimera: false,
      cargandoMas: false,
      huboPrimeraCarga: true,
      limpiarErrorInicial: true,
      limpiarErrorAlCargarMas: true,
    );
  }
}

/// Marcas disponibles para el selector de la pantalla de filtros.
///
/// No depende de la sesión —son las marcas de los productos publicados— así
/// que se pide una vez y queda en memoria.
final marcasProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(catalogoRepositoryProvider).marcas();
});
