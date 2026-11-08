import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/checkout.dart';
import 'carrito_providers.dart';
import 'proveedores_core.dart';
import 'sesion_providers.dart';

/// El resumen del checkout.
///
/// **`null` significa "no corresponde pedirlo"**, igual que en el carrito: no
/// hay sesión, o el correo no está verificado. En los dos casos el backend
/// respondería 401 o 403 y el estado local ya alcanza para saberlo.
///
/// **Depende del carrito, y eso es lo que resuelve el "dato desactualizado".**
/// `build()` hace `ref.watch(carritoProvider)`, así que cualquier cambio en
/// el carrito —quitar la línea del producto despublicado que estaba
/// bloqueando el pago, por ejemplo— vuelve a pedir el checkout solo. Sin esa
/// dependencia, el cliente resolvería el bloqueo desde el carrito, volvería
/// al checkout y seguiría viendo el mismo cartel rojo hasta tirar del
/// refresco a mano.
///
/// Que además dependa de la sesión sale gratis: `carritoProvider` ya observa
/// a `usuarioProvider`, así que cerrar sesión limpia los dos.
///
/// **Nada se cachea en disco.** Los precios del resumen son los vigentes al
/// mirar, y son los que se van a congelar en la venta.
final checkoutProvider = AsyncNotifierProvider<CheckoutNotifier, ResumenCheckout?>(
  CheckoutNotifier.new,
);

class CheckoutNotifier extends AsyncNotifier<ResumenCheckout?> {
  @override
  Future<ResumenCheckout?> build() async {
    // El valor no se usa: lo que importa es quedar suscrito a los cambios del
    // carrito para volver a pedir el resumen cuando se modifique.
    ref.watch(carritoProvider);

    final usuario = ref.watch(usuarioProvider);

    if (usuario == null || !usuario.emailVerificado) return null;

    return ref.read(checkoutRepositoryProvider).ver();
  }

  /// Vuelve a pedir el resumen. Lo usan el reintento y el `RefreshIndicator`.
  Future<void> recargar() async {
    state = const AsyncValue<ResumenCheckout?>.loading();

    state = await AsyncValue.guard(() async {
      final usuario = ref.read(usuarioProvider);

      if (usuario == null || !usuario.emailVerificado) return null;

      return ref.read(checkoutRepositoryProvider).ver();
    });
  }

  /// Guarda el modo de entrega elegido.
  Future<void> elegirModoEntrega(String modo) {
    return _aplicar(
      () => ref.read(checkoutRepositoryProvider).guardarPreferencias(
            modoEntrega: modo,
          ),
    );
  }

  /// Guarda las observaciones. `null` o vacío las borra.
  ///
  /// La cadena vacía se manda como null: para el backend `observaciones` es
  /// una columna que admite null, y guardar `''` dejaría una fila con un
  /// texto vacío que después hay que distinguir de "no escribió nada".
  Future<void> guardarObservaciones(String? texto) {
    final limpio = texto?.trim();

    return _aplicar(
      () => ref.read(checkoutRepositoryProvider).guardarPreferencias(
            observaciones: (limpio == null || limpio.isEmpty) ? null : limpio,
          ),
    );
  }

  /// Ejecuta una operación y publica el resumen que devolvió el backend.
  ///
  /// **Si falla, el estado no se toca** —mismo criterio que el carrito—: un
  /// guardado que no llegó no es motivo para vaciar la pantalla. El error se
  /// propaga para que la pantalla lo muestre sin desarmar nada.
  Future<void> _aplicar(Future<ResumenCheckout> Function() operacion) async {
    final resumen = await operacion();

    state = AsyncValue<ResumenCheckout?>.data(resumen);
  }
}
