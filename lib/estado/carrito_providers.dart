import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/carrito.dart';
import 'proveedores_core.dart';
import 'sesion_providers.dart';

/// El carrito del cliente.
///
/// **`null` significa "no corresponde pedirlo", no "está vacío".** Pasa en
/// dos casos: no hay sesión, o el correo todavía no está verificado. En los
/// dos, el backend respondería 401 o 403, así que ni siquiera se hace la
/// llamada: el estado local ya alcanza para saberlo, y `Usuario` trae
/// `emailVerificado` exactamente para esto. Un carrito vacío de verdad llega
/// como un [Carrito] con `vacio: true`.
///
/// **Se reconstruye solo al cambiar la sesión**, porque `build()` hace
/// `ref.watch(usuarioProvider)`. Eso importa más de lo que parece: sin esa
/// dependencia, el carrito del cliente anterior se quedaría en memoria y se
/// le mostraría al siguiente que inicie sesión en el mismo teléfono.
///
/// Se resuelve con `watch` y no agregándolo a `SesionNotifier.
/// _invalidarCatalogo()`, que es como se refrescan vitrina y fichas. Aquella
/// lista hay que acordarse de mantenerla; esto no se puede olvidar, porque la
/// dependencia está declarada en el único lugar donde se usa. Para datos del
/// cliente —y no del catálogo— esa garantía vale más que la simetría.
///
/// **Nada se guarda en disco.** El carrito no congela precios: los resuelve
/// `MotorPromociones` al momento de mirar. Un total cacheado en el teléfono
/// puede estar vencido.
final carritoProvider = AsyncNotifierProvider<CarritoNotifier, Carrito?>(
  CarritoNotifier.new,
);

class CarritoNotifier extends AsyncNotifier<Carrito?> {
  @override
  Future<Carrito?> build() async {
    final usuario = ref.watch(usuarioProvider);

    if (usuario == null || !usuario.emailVerificado) return null;

    return ref.read(carritoRepositoryProvider).ver();
  }

  /// Vuelve a pedir el carrito. Lo usa el botón de reintentar y el
  /// `RefreshIndicator`.
  Future<void> recargar() async {
    state = const AsyncValue<Carrito?>.loading();

    state = await AsyncValue.guard(() async {
      final usuario = ref.read(usuarioProvider);

      if (usuario == null || !usuario.emailVerificado) return null;

      return ref.read(carritoRepositoryProvider).ver();
    });
  }

  /// Agrega unidades desde la ficha de producto.
  ///
  /// **Los errores suben.** La ficha es la que sabe dónde mostrarlos: un
  /// producto que se despublicó entre que se dibujó la pantalla y que se tocó
  /// el botón llega como [ErrorValidacion] y merece un mensaje distinto que
  /// una caída de red.
  Future<void> agregar({required int productoId, required int cantidad}) {
    return _aplicar(
      () => ref.read(carritoRepositoryProvider).agregar(
            productoId: productoId,
            cantidad: cantidad,
          ),
    );
  }

  /// Fija la cantidad de una línea.
  ///
  /// El agrupado de los toques del `+` y el `−` **no vive acá sino en la
  /// fila**, que es la que conoce el ritmo de los toques. Este método es la
  /// llamada de verdad y se ejecuta una sola vez por ráfaga, con el valor
  /// final.
  Future<void> cambiarCantidad({required int lineaId, required int cantidad}) {
    return _aplicar(
      () => ref.read(carritoRepositoryProvider).cambiarCantidad(
            lineaId: lineaId,
            cantidad: cantidad,
          ),
    );
  }

  Future<void> quitar(int lineaId) {
    return _aplicar(() => ref.read(carritoRepositoryProvider).quitar(lineaId));
  }

  Future<void> vaciar() {
    return _aplicar(() => ref.read(carritoRepositoryProvider).vaciar());
  }

  /// Ejecuta una mutación y publica el carrito que devolvió el backend.
  ///
  /// **Si falla, el estado no se toca.** Es deliberado: pasar a
  /// `AsyncError` borraría la lista de la pantalla por un `+` que no llegó,
  /// y el carrito que se está viendo sigue siendo el último válido. El error
  /// se propaga para que la pantalla lo muestre en un `SnackBar` sin
  /// desarmar nada.
  ///
  /// No hay actualización optimista de importes: el backend es el único que
  /// calcula, así que el total cambia cuando contesta y no antes.
  Future<void> _aplicar(Future<Carrito> Function() operacion) async {
    final carrito = await operacion();

    state = AsyncValue<Carrito?>.data(carrito);
  }
}

/// Unidades en el carrito, para el globito de la barra superior.
///
/// Devuelve 0 mientras carga, sin sesión y ante un error: el contador es
/// decoración y no tiene por qué tener estados. La pantalla del carrito sí
/// los distingue.
final itemsEnCarritoProvider = Provider<int>((ref) {
  return ref.watch(carritoProvider).value?.cantidadItems ?? 0;
});
