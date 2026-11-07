import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/opcion_fiscal.dart';
import 'proveedores_core.dart';

/// Las dos listas del formulario de registro.
///
/// Se piden una sola vez y quedan cacheadas en memoria mientras la app viva:
/// son datos de seeder que no cambian entre pantallas. No se guardan en
/// disco —no hace falta, y la regla del proyecto es no persistir mas de lo
/// necesario—.
final datosFiscalesProvider = FutureProvider<DatosFiscales>((ref) async {
  return ref.watch(datosFiscalesRepositoryProvider).obtener();
});
