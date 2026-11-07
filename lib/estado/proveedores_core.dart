import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/almacenamiento.dart';
import '../core/api_client.dart';
import '../datos/repositorios/catalogo_repository.dart';

/// Almacenamiento cifrado del token. Uno solo para toda la app.
final almacenSeguroProvider = Provider<AlmacenSeguro>((ref) {
  return AlmacenSeguro();
});

/// Cliente HTTP unico. Se construye una vez con la URL base de Config.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(almacen: ref.watch(almacenSeguroProvider));
});

final catalogoRepositoryProvider = Provider<CatalogoRepository>((ref) {
  return CatalogoRepository(ref.watch(apiClientProvider));
});
