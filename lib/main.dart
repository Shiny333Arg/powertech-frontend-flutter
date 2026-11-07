import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'estado/sesion_providers.dart';
import 'ui/pantallas/pantalla_vitrina.dart';

void main() {
  runApp(const ProviderScope(child: AppPowerTech()));
}

class AppPowerTech extends StatelessWidget {
  const AppPowerTech({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerTech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const _Raiz(),
    );
  }
}

/// Decide la pantalla de arranque.
///
/// **Cambió respecto del paso 2 y es el único cambio de comportamiento del
/// paso 3.** Antes el invitado veía el login, porque no había otra cosa que
/// mostrarle. Ahora los dos —invitado y cliente— arrancan en la vitrina, y
/// el login pasó a ser un destino que se apila encima. Es lo que dice el
/// contrato: iniciar sesión no es obligatorio al arrancar la app.
///
/// Por eso la vitrina es la primera ruta de la pila, y login, registro y "mi
/// cuenta" vuelven a ella con `popUntil(isFirst)`.
///
/// **go_router sigue afuera.** Con tres destinos ya se justifica más que en el
/// paso 2, pero ninguno tiene todavía una URL que resolver ni una ruta que
/// proteger: el `redirect` por sesión existe para el carrito, que es el paso
/// 4 de la API. Esta clase es el lugar que va a reemplazar.
class _Raiz extends ConsumerWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sesionProvider);

    // Durante la validación del token guardado se muestra el arranque y no la
    // vitrina. Es medio segundo, y evita el parpadeo de pintar las tarjetas
    // como invitado para corregirlas enseguida: el interceptor ya manda el
    // token en el GET /home, así que los precios llegan desde la primera
    // respuesta. Sin token, `restaurar()` resuelve sin red y esto no se ve.
    if (estado is SesionCargando) return const _Arrancando();

    return const PantallaVitrina();
  }
}

/// Lo que se ve mientras se valida el token guardado contra `/auth/yo`.
class _Arrancando extends StatelessWidget {
  const _Arrancando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recuperando tu sesión...'),
          ],
        ),
      ),
    );
  }
}
