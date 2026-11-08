import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/pago.dart';
import 'carrito_providers.dart';
import 'checkout_providers.dart';
import 'proveedores_core.dart';

/// Consulta del estado del último intento de pago.
///
/// **No se construye solo y no hay nada que observar.** A diferencia del
/// carrito y del checkout, esto no es un dato que esté ahí: es una pregunta
/// que se hace en momentos concretos —cuando la app vuelve al frente después
/// del navegador, y cuando el cliente toca «volver a consultar»—. Por eso el
/// estado arranca en null y lo llena [consultar].
///
/// **El backend es el único que sabe.** La app no mira la URL por la que
/// volvió el navegador: puede venir editada a mano y puede no llegar nunca.
final estadoPagoProvider =
    NotifierProvider<EstadoPagoNotifier, AsyncValue<EstadoPago>?>(
  EstadoPagoNotifier.new,
);

class EstadoPagoNotifier extends Notifier<AsyncValue<EstadoPago>?> {
  @override
  AsyncValue<EstadoPago>? build() => null;

  /// Le pregunta al backend en qué quedó el pago.
  ///
  /// Mantiene el valor anterior mientras consulta, para que la pantalla no
  /// parpadee en cada reintento.
  Future<void> consultar() async {
    final anterior = state?.value;

    state = anterior == null
        ? const AsyncValue<EstadoPago>.loading()
        : AsyncValue<EstadoPago>.data(anterior);

    final nuevo = await AsyncValue.guard(
      () => ref.read(checkoutRepositoryProvider).estadoDelPago(),
    );

    state = nuevo;

    // Una compra cerrada deja el carrito convertido y el cliente arranca uno
    // nuevo y vacío. Sin invalidar, el globito de la barra seguiría mostrando
    // las unidades de un carrito que ya es un pedido.
    if (nuevo.value?.resultado == ResultadoPago.aprobado) {
      ref.invalidate(carritoProvider);
      ref.invalidate(checkoutProvider);
    }
  }

  /// Borra lo consultado. Se llama al salir de la pantalla de espera, para
  /// que el próximo pago no arranque mostrando el resultado del anterior.
  void limpiar() => state = null;
}
