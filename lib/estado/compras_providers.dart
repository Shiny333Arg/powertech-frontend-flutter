import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errores.dart';
import '../datos/modelos/compra.dart';
import '../datos/modelos/compra_detalle.dart';
import 'proveedores_core.dart';
import 'sesion_providers.dart';

// ====================================================================
// Historial
// ====================================================================

/// Estado del historial paginado.
///
/// **Las compras se acumulan, no se reemplazan.** Es lo que pide el "Cargar
/// más": la página 2 se agrega abajo de la 1.
///
/// **El error de una página adicional se guarda aparte del de la primera.**
/// Son dos situaciones distintas: si falla la primera no hay nada que mostrar
/// y la pantalla es un error; si falla la tercera, las veinte compras que ya
/// están tienen que seguir en pantalla y lo único que cambia es un aviso con
/// "Reintentar" al pie. Es el mismo criterio que `EstadoCatalogo`.
class EstadoHistorial {
  const EstadoHistorial({
    this.compras = const [],
    this.paginaActual = 0,
    this.ultimaPagina = 0,
    this.total = 0,
    this.cargandoPrimera = false,
    this.cargandoMas = false,
    this.errorInicial,
    this.errorAlCargarMas,
    this.huboPrimeraCarga = false,
  });

  /// Todo lo traído hasta ahora, de la más reciente a la más antigua.
  final List<Compra> compras;

  final int paginaActual;
  final int ultimaPagina;

  /// Cuántas compras tiene el cliente en total, según el backend. Alimenta el
  /// "Mostrando 10 de 23".
  final int total;

  final bool cargandoPrimera;
  final bool cargandoMas;

  /// Falló la primera página: no hay nada que mostrar.
  final ErrorApi? errorInicial;

  /// Falló una página adicional: lo ya cargado sigue en pantalla.
  final ErrorApi? errorAlCargarMas;

  /// Distingue "todavía no pedí nada" de "pedí y no tiene compras". Sin esto,
  /// el arranque y el estado vacío se verían iguales, y el cliente que todavía
  /// no compró nunca vería un spinner en lugar de su mensaje.
  final bool huboPrimeraCarga;

  bool get hayMas => paginaActual > 0 && paginaActual < ultimaPagina;

  /// El cliente no tiene compras. **No es lo mismo que un error ni que estar
  /// cargando**: es un estado legítimo y con su propia pantalla.
  bool get sinCompras =>
      huboPrimeraCarga &&
      compras.isEmpty &&
      errorInicial == null &&
      !cargandoPrimera;

  int get cantidadMostrada => compras.length;

  EstadoHistorial copiarCon({
    List<Compra>? compras,
    int? paginaActual,
    int? ultimaPagina,
    int? total,
    bool? cargandoPrimera,
    bool? cargandoMas,
    ErrorApi? errorInicial,
    ErrorApi? errorAlCargarMas,
    bool? huboPrimeraCarga,
    bool limpiarErrorInicial = false,
    bool limpiarErrorAlCargarMas = false,
  }) {
    return EstadoHistorial(
      compras: compras ?? this.compras,
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

/// El historial de compras del cliente.
///
/// **`build()` hace `ref.watch(usuarioProvider)` y eso es lo que importa
/// acá.** Al cambiar la sesión el notifier se reconstruye y el estado vuelve a
/// cero. Sin esa dependencia, el historial del cliente anterior quedaría en
/// memoria y se le mostraría al siguiente que inicie sesión en el mismo
/// teléfono: no serían precios viejos, serían las compras de otra persona.
///
/// Se resuelve con `watch` y no agregándolo a
/// `SesionNotifier._invalidarCatalogo()`, por la misma razón que el carrito:
/// aquella lista hay que acordarse de mantenerla, y esto no se puede olvidar
/// porque la dependencia está declarada donde se usa. Es el criterio que el
/// proyecto ya tomó para los datos del CLIENTE, a diferencia de los del
/// catálogo.
///
/// **No se guarda nada en disco.** El estado de un pedido cambia del lado del
/// depósito —se prepara, se despacha, se entrega— así que un historial
/// cacheado en el teléfono muestra un seguimiento viejo, que es justo lo que
/// el cliente viene a mirar.
final historialComprasProvider =
    NotifierProvider<HistorialComprasNotifier, EstadoHistorial>(
  HistorialComprasNotifier.new,
);

class HistorialComprasNotifier extends Notifier<EstadoHistorial> {
  @override
  EstadoHistorial build() {
    ref.watch(usuarioProvider);

    return const EstadoHistorial();
  }

  /// Carga inicial, desde el `initState` de la pantalla.
  ///
  /// **Pide siempre, incluso si ya hay un estado cargado**, igual que
  /// `CatalogoNotifier.iniciar()`. Acá además tiene un efecto que conviene:
  /// después de pagar, el cliente entra al historial y la compra nueva aparece
  /// sin que nadie tenga que invalidar nada. Y al volver del detalle, el
  /// estado del pedido está fresco.
  Future<void> iniciar() => cargarPrimera();

  /// Trae la página 1 y descarta lo acumulado. Es el `RefreshIndicator` y el
  /// "Reintentar" del error inicial.
  Future<void> cargarPrimera() async {
    if (ref.read(usuarioProvider) == null) {
      // Sin sesión no se pide: el backend contestaría 401 y la pantalla ya
      // muestra su propio estado para este caso. Se marca la primera carga
      // para que no quede girando un indicador que no espera nada.
      state = state.copiarCon(
        compras: const [],
        cargandoPrimera: false,
        huboPrimeraCarga: true,
        limpiarErrorInicial: true,
        limpiarErrorAlCargarMas: true,
      );
      return;
    }

    state = state.copiarCon(
      cargandoPrimera: true,
      cargandoMas: false,
      limpiarErrorInicial: true,
      limpiarErrorAlCargarMas: true,
    );

    try {
      final pagina = await ref.read(comprasRepositoryProvider).historial();

      state = state.copiarCon(
        compras: pagina.items,
        paginaActual: pagina.paginaActual,
        ultimaPagina: pagina.ultimaPagina,
        total: pagina.total,
        cargandoPrimera: false,
        huboPrimeraCarga: true,
        limpiarErrorInicial: true,
        limpiarErrorAlCargarMas: true,
      );
    } on ErrorApi catch (e) {
      state = state.copiarCon(
        // La lista se vacía: mostrar el historial de hace un rato bajo un
        // cartel de error sería dejar en pantalla datos que no se pudieron
        // confirmar, y el estado de un pedido es justo lo que cambia.
        compras: const [],
        paginaActual: 0,
        ultimaPagina: 0,
        total: 0,
        cargandoPrimera: false,
        errorInicial: e,
        huboPrimeraCarga: true,
      );
    }
  }

  /// Trae la página siguiente y la agrega al final.
  ///
  /// Si falla, **lo cargado no se toca**: sólo se anota el error para que la
  /// pantalla ofrezca reintentar al pie.
  Future<void> cargarMas() async {
    if (state.cargandoMas || state.cargandoPrimera || !state.hayMas) return;

    state = state.copiarCon(cargandoMas: true, limpiarErrorAlCargarMas: true);

    try {
      final pagina = await ref.read(comprasRepositoryProvider).historial(
            pagina: state.paginaActual + 1,
          );

      state = state.copiarCon(
        compras: [...state.compras, ...pagina.items],
        paginaActual: pagina.paginaActual,
        ultimaPagina: pagina.ultimaPagina,
        total: pagina.total,
        cargandoMas: false,
        limpiarErrorAlCargarMas: true,
      );
    } on ErrorApi catch (e) {
      state = state.copiarCon(cargandoMas: false, errorAlCargarMas: e);
    }
  }

  Future<void> recargar() => cargarPrimera();
}

// ====================================================================
// Detalle
// ====================================================================

/// El detalle de una compra, indexado por su id.
///
/// `family` por la misma razón que `fichaProvider`: cada pedido necesita su
/// propia respuesta, y un provider único haría que abrir un segundo detalle
/// sobreescribiera al primero.
///
/// **Se invalida al cambiar la sesión**, por `ref.watch(usuarioProvider)`. Un
/// detalle que quedó en memoria es el pedido de un cliente concreto: si en el
/// mismo teléfono entra otro, ese `FutureProvider` tiene que volver a pedir
/// —y recibir el 404 que corresponde— en lugar de servir lo cacheado.
///
/// `ref.invalidate(detalleCompraProvider)` sin argumento alcanza todas las
/// instancias; con argumento, sólo ese pedido. Es lo que usa el "Reintentar"
/// y el `RefreshIndicator` de la pantalla.
final detalleCompraProvider =
    FutureProvider.family<CompraDetalle, int>((ref, compraId) async {
  ref.watch(usuarioProvider);

  return ref.watch(comprasRepositoryProvider).detalle(compraId);
});
