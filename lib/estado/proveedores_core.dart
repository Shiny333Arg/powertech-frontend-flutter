import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/almacenamiento.dart';
import '../core/api_client.dart';
import '../datos/repositorios/auth_repository.dart';
import '../datos/repositorios/carrito_repository.dart';
import '../datos/repositorios/catalogo_repository.dart';
import '../datos/repositorios/checkout_repository.dart';
import '../datos/repositorios/compras_repository.dart';
import '../datos/repositorios/datos_fiscales_repository.dart';

/// Almacenamiento cifrado del token. Uno solo para toda la app.
final almacenSeguroProvider = Provider<AlmacenSeguro>((ref) {
  return AlmacenSeguro();
});

/// Cliente HTTP unico. Se construye una vez con la URL base de Config.
///
/// El interceptor lee el token de [almacenSeguroProvider] en cada request,
/// asi que no hay que reconstruirlo al iniciar o cerrar sesion: la proxima
/// llamada ya sale con la cabecera correcta.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(almacen: ref.watch(almacenSeguroProvider));
});

final catalogoRepositoryProvider = Provider<CatalogoRepository>((ref) {
  return CatalogoRepository(ref.watch(apiClientProvider));
});

final carritoRepositoryProvider = Provider<CarritoRepository>((ref) {
  return CarritoRepository(ref.watch(apiClientProvider));
});

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});

final comprasRepositoryProvider = Provider<ComprasRepository>((ref) {
  return ComprasRepository(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(almacenSeguroProvider),
  );
});

final datosFiscalesRepositoryProvider = Provider<DatosFiscalesRepository>((ref) {
  return DatosFiscalesRepository(ref.watch(apiClientProvider));
});
