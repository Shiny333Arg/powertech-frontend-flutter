import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/carrito_providers.dart';
import '../pantallas/pantalla_carrito.dart';

/// El ícono del carrito de la barra superior, con el globito de unidades.
///
/// **El número sale de `cantidad_items`, que lo cuenta el backend.** Son
/// unidades y no líneas, e incluye las de los productos que dejaron de estar
/// disponibles: el cliente los metió y los sigue viendo, así que esconderlos
/// del contador haría que el globito no coincida con la pantalla.
///
/// Se muestra siempre, también al invitado: tocarlo lleva al carrito, que es
/// el que explica que hay que ingresar. Esconderlo dejaría al invitado sin
/// pista de que la tienda tiene carrito.
class BotonCarrito extends ConsumerWidget {
  const BotonCarrito({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsEnCarritoProvider);

    return IconButton(
      tooltip: items == 0 ? 'Mi carrito' : 'Mi carrito ($items)',
      onPressed: () => abrirCarrito(context),
      icon: Badge(
        // El globito desaparece en cero en vez de mostrar un "0".
        isLabelVisible: items > 0,
        // Más de 99 unidades es posible —99 por línea, varias líneas— y un
        // número de tres cifras rompe el círculo.
        label: Text(items > 99 ? '+99' : '$items'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
