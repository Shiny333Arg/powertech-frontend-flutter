import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/perfil.dart';
import 'proveedores_core.dart';
import 'sesion_providers.dart';

/// El perfil del cliente, para el formulario que lo edita.
///
/// **Es la fuente del formulario, no `usuarioProvider`.** El usuario de la
/// sesión sirve para saludar en "Mi cuenta"; para EDITAR hace falta el estado
/// más fresco del servidor, más `documento_bloqueado`, que la sesión no trae.
/// Prellenar desde la sesión mostraría datos que pueden haber cambiado desde
/// otro dispositivo.
///
/// **`ref.watch(usuarioProvider)` es lo que lo hace seguro.** Al cambiar la
/// sesión el provider se reconstruye y vuelve a pedir: sin esa dependencia, el
/// perfil del cliente anterior quedaría en memoria y se le mostraría —y se le
/// dejaría editar— al siguiente que inicie sesión en el mismo teléfono. Es la
/// misma decisión que ya está documentada para `carritoProvider` y la que el
/// proyecto toma para todos los datos del CLIENTE, en lugar de sumarlos a
/// `SesionNotifier._invalidarCatalogo()`.
///
/// Esa misma dependencia es la que refresca el formulario después de guardar:
/// la pantalla llama a `refrescarUsuario()`, el usuario de la sesión cambia y
/// esto vuelve a pedir solo. Así el formulario termina mostrando exactamente
/// lo que quedó en la base, incluida la `razon_social` que el backend completa
/// cuando se manda vacía.
///
/// **Nada se guarda en disco.** Son los datos con los que se factura y pueden
/// cambiarse desde la web o desde el mostrador.
final perfilProvider = FutureProvider<Perfil>((ref) async {
  ref.watch(usuarioProvider);

  return ref.watch(perfilRepositoryProvider).ver();
});
