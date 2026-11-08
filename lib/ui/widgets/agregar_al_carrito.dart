import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../datos/modelos/producto.dart';
import '../../estado/carrito_providers.dart';
import '../../estado/sesion_providers.dart';
import '../pantallas/pantalla_carrito.dart';
import '../pantallas/pantalla_inicio.dart';
import '../pantallas/pantalla_login.dart';
import 'selector_cantidad.dart';

/// El bloque de "agregar al carrito" de la ficha de producto: un selector de
/// cantidad y el botón.
///
/// **Cambia según quién mira**, con los mismos tres estados de sesión que el
/// resto de la app:
///
///  - **Invitado:** el botón dice "Ingresar para comprar" y lleva al login.
///    No se intenta la llamada, que daría 401.
///  - **Sin verificar:** lleva a "Mi cuenta", donde está el botón de reenvío.
///    Tampoco se llama: daría 403.
///  - **Verificado:** agrega de verdad.
///
/// **Preventa no deshabilita nada.** Un producto sin stock se agrega igual:
/// lo que cambia es el texto del botón, que lo dice. El backend lo acepta
/// —`CarritoLineaMovilRequest` no valida contra stock a propósito— y
/// bloquearlo acá sería inventar una regla que el negocio no tiene.
///
/// El selector usa el mismo [SelectorCantidad] del carrito, pero sin el
/// agrupado de toques: acá la cantidad no viaja hasta que se toca el botón,
/// así que el `onCambiar` solo guarda el número.
class AgregarAlCarrito extends ConsumerStatefulWidget {
  const AgregarAlCarrito({super.key, required this.producto});

  final Producto producto;

  @override
  ConsumerState<AgregarAlCarrito> createState() => _AgregarAlCarritoState();
}

class _AgregarAlCarritoState extends ConsumerState<AgregarAlCarrito> {
  int _cantidad = 1;
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider);

    if (usuario == null) {
      return _BotonSimple(
        icono: Icons.login,
        texto: 'Ingresar para comprar',
        onTocar: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
        ),
      );
    }

    if (!usuario.emailVerificado) {
      return _BotonSimple(
        icono: Icons.mark_email_unread_outlined,
        texto: 'Confirmá tu correo para comprar',
        onTocar: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PantallaInicio(usuario: usuario),
          ),
        ),
      );
    }

    final enPreventa = widget.producto.enPreventa;

    return Row(
      children: [
        SelectorCantidad(
          valor: _cantidad,
          habilitado: !_enviando,
          // Sin espera: el valor no sale a la red hasta que se toca el botón.
          espera: Duration.zero,
          onCambiar: (valor) => setState(() => _cantidad = valor),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: FilledButton.icon(
            onPressed: _enviando ? null : _agregar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(enPreventa
                    ? Icons.schedule_outlined
                    : Icons.add_shopping_cart),
            label: Text(
              _enviando
                  ? 'Agregando...'
                  : (enPreventa ? 'Reservar en preventa' : 'Agregar al carrito'),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _agregar() async {
    setState(() => _enviando = true);

    try {
      await ref.read(carritoProvider.notifier).agregar(
            productoId: widget.producto.id,
            cantidad: _cantidad,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _cantidad == 1
                  ? 'Agregamos ${widget.producto.nombre} a tu carrito.'
                  : 'Agregamos $_cantidad unidades a tu carrito.',
            ),
            action: SnackBarAction(
              label: 'Ver carrito',
              onPressed: () => abrirCarrito(context),
            ),
          ),
        );

      // Vuelve a 1: la cantidad elegida ya se sumó a la línea, y dejar el
      // número puesto invita a agregar otras tantas sin querer.
      setState(() => _cantidad = 1);
    } on ErrorEmailNoVerificado {
      // El estado local estaba viejo. Se refresca el usuario y el widget se
      // redibuja solo en el estado "sin verificar".
      if (mounted) _avisar('Necesitás confirmar tu correo para comprar.');
      await ref.read(sesionProvider.notifier).refrescarUsuario();
    } on ErrorValidacion catch (e) {
      // 422. El caso real: el producto se despublicó entre que se cargó la
      // ficha y que se tocó el botón. El mensaje del campo es más preciso
      // que el general.
      if (mounted) _avisar(e.primeroDe('producto_id') ?? e.mensaje);
    } on ErrorApi catch (e) {
      if (mounted) {
        _avisar(
          e is ErrorRed
              ? 'No pudimos conectarnos con el servidor. Revisá tu conexión.'
              : e.mensaje,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class _BotonSimple extends StatelessWidget {
  const _BotonSimple({
    required this.icono,
    required this.texto,
    required this.onTocar,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTocar,
        icon: Icon(icono),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
