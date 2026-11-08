import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/navegador.dart';
import '../../datos/modelos/bloqueo_checkout.dart';
import '../../datos/modelos/checkout.dart';
import '../../datos/modelos/linea_carrito.dart';
import '../../datos/modelos/usuario.dart';
import '../../estado/checkout_providers.dart';
import '../../estado/proveedores_core.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/imagen_remota.dart';
import '../widgets/lista_bloqueos.dart';
import '../widgets/resumen_carrito.dart';
import '../widgets/selector_entrega.dart';
import '../widgets/tarjeta_facturacion.dart';
import 'pantalla_esperando_pago.dart';
import 'pantalla_inicio.dart';

/// Revisión previa al pago: `GET /api/v1/checkout` y `PATCH` de preferencias.
///
/// **Acá no se paga.** El botón del pie queda listo para el paso 10, que es
/// el que crea la preferencia de Mercado Pago; por ahora avisa que falta. No
/// simula una compra ni crea nada: la venta online nace del pago acreditado,
/// y sin pasarela no hay pago.
///
/// **La lista de productos es de sólo lectura.** El carrito se edita en la
/// pantalla del carrito, que es donde están el selector de cantidad y el
/// botón de quitar. Duplicar esos controles acá daría dos lugares para hacer
/// lo mismo y una pantalla de revisión que se puede modificar a sí misma
/// mientras se la revisa.
///
/// **El resumen se repide solo cuando cambia el carrito**, porque
/// `checkoutProvider` observa a `carritoProvider`. Es lo que hace que
/// resolver un bloqueo desde el carrito y volver acá muestre el cartel ya
/// resuelto, sin tirar del refresco.
void abrirCheckout(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaCheckout()),
  );
}

class PantallaCheckout extends ConsumerStatefulWidget {
  const PantallaCheckout({super.key});

  @override
  ConsumerState<PantallaCheckout> createState() => _PantallaCheckoutState();
}

class _PantallaCheckoutState extends ConsumerState<PantallaCheckout> {
  /// Hay un guardado en vuelo. Bloquea los controles: cada PATCH devuelve el
  /// resumen entero recalculado, así que dos en paralelo pueden llegar
  /// desordenados y dejar en pantalla el resultado del primero.
  bool _ocupado = false;

  /// Hay una orden de cobro en curso. Separado de [_ocupado] porque bloquea
  /// cosas distintas: aquel apaga los controles de entrega, éste el botón de
  /// pagar, y el pago tarda más.
  bool _pagando = false;

  Future<void> _guardar(Future<void> Function() accion) async {
    if (_ocupado) return;

    final visible = mounted;

    if (visible) setState(() => _ocupado = true);

    try {
      await accion();
    } on ErrorEmailNoVerificado {
      // El estado local decía que estaba verificado y el backend dice que no.
      // Se refresca el usuario: el provider se reconstruye y la pantalla pasa
      // sola al estado correcto.
      if (mounted) _avisar('Necesitás confirmar tu correo para comprar.');
      await ref.read(sesionProvider.notifier).refrescarUsuario();
    } on ErrorValidacion catch (e) {
      // 422. El caso real: observaciones más largas que la columna, o un
      // modo de entrega que el backend dejó de aceptar.
      if (mounted) {
        _avisar(
          e.primeroDe('observaciones') ??
              e.primeroDe('modo_entrega') ??
              e.mensaje,
        );
      }
    } on ErrorApi catch (e) {
      if (mounted) _avisar(e is ErrorRed ? _sinConexion : e.mensaje);
    } finally {
      if (visible && mounted) setState(() => _ocupado = false);
    }
  }

  static const String _sinConexion =
      'No pudimos conectarnos con el servidor. Revisá tu conexión y probá de '
      'nuevo.';

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Lleva al cliente a donde puede resolver el bloqueo.
  ///
  /// El destino sale del `codigo`, no del texto. Carrito y catálogo están
  /// debajo en la pila —al checkout se llega desde el carrito, y al carrito
  /// desde la vitrina— así que se vuelve con `pop` en lugar de apilar otra
  /// copia de la misma pantalla.
  void _resolver(BloqueoCheckout bloqueo) {
    // Expresión y no sentencia: así el analizador verifica que estén
    // contemplados todos los valores del enum. El día que el backend agregue
    // un destino, esto deja de compilar en vez de no hacer nada en silencio.
    final accion = switch (bloqueo.destino) {
      DestinoBloqueo.carrito => () => Navigator.of(context).pop(),
      DestinoBloqueo.catalogo =>
        () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
      DestinoBloqueo.perfil => _verPerfil,
      DestinoBloqueo.desconocido => null,
    };

    accion?.call();
  }

  void _verPerfil() {
    final usuario = ref.read(usuarioProvider);

    if (usuario == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaInicio(usuario: usuario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider);
    final estado = ref.watch(checkoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Revisá tu pedido')),
      body: SafeArea(child: _cuerpo(usuario, estado)),
    );
  }

  Widget _cuerpo(Usuario? usuario, AsyncValue<ResumenCheckout?> estado) {
    // A esta pantalla se llega desde el carrito, que ya filtra los dos casos.
    // Se contemplan igual por si la sesión cambia con la pantalla abierta.
    if (usuario == null || !usuario.emailVerificado) {
      return const _SinAcceso();
    }

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (e, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 40),
          AvisoError(
            error: e is ErrorApi ? e : ErrorFormato('$e'),
            onReintentar: () => ref.read(checkoutProvider.notifier).recargar(),
          ),
        ],
      ),

      data: (resumen) => resumen == null
          ? const _SinAcceso()
          : _Resumen(
              resumen: resumen,
              ocupado: _ocupado || _pagando,
              onRecargar: () => ref.read(checkoutProvider.notifier).recargar(),
              onResolver: _resolver,
              onVerPerfil: _verPerfil,
              onElegirModo: (modo) => _guardar(
                () => ref.read(checkoutProvider.notifier).elegirModoEntrega(modo),
              ),
              onGuardarObservaciones: (texto) => _guardar(
                () => ref
                    .read(checkoutProvider.notifier)
                    .guardarObservaciones(texto),
              ),
              onPagar: _pagar,
            ),
    );
  }

  /// Arranca el pago: pide la orden de cobro y abre Mercado Pago.
  ///
  /// **El backend revalida todo en este momento**, no en el resumen: entre
  /// que el cliente miró la pantalla y tocó el botón pudo despublicarse un
  /// producto. Por eso un 409 acá no es un error raro, es el caso previsto, y
  /// se resuelve refrescando el resumen para que los bloqueos aparezcan
  /// donde ya se muestran.
  ///
  /// **No se crea ningún pedido de este lado.** Lo que vuelve es una URL.
  Future<void> _pagar() async {
    // Dos toques seguidos crearían dos órdenes de cobro en Mercado Pago.
    if (_pagando) return;

    setState(() => _pagando = true);

    try {
      final inicio = await ref.read(checkoutRepositoryProvider).iniciarPago();

      final abierto = await abrirEnNavegador(inicio.urlPago);

      if (!mounted) return;

      if (!abierto) {
        _avisar(
          'No pudimos abrir Mercado Pago. Revisá que tengas un navegador '
          'disponible y probá de nuevo.',
        );
        return;
      }

      // Se apila la pantalla de espera ANTES de que el cliente vuelva: es la
      // que escucha el regreso al frente y le pregunta al backend qué pasó.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PantallaEsperandoPago(urlPago: inicio.urlPago),
        ),
      );

      // Al volver de ahí el carrito pudo convertirse en pedido.
      if (mounted) ref.invalidate(checkoutProvider);
    } on ErrorValidacion catch (e) {
      if (mounted) _avisar(e.mensaje);
    } on ErrorServidor catch (e) {
      if (!mounted) return;

      if (e.codigo == 409) {
        // El carrito dejó de ser pagable. Se vuelve a pedir el resumen: los
        // bloqueos nuevos se dibujan en el mismo lugar de siempre.
        _avisar(e.mensaje);
        await ref.read(checkoutProvider.notifier).recargar();
      } else {
        // 502 incluido: Mercado Pago no respondió y se puede reintentar.
        _avisar(e.mensaje);
      }
    } on ErrorEmailNoVerificado {
      if (mounted) _avisar('Necesitás confirmar tu correo para comprar.');
      await ref.read(sesionProvider.notifier).refrescarUsuario();
    } on ErrorApi catch (e) {
      if (mounted) _avisar(e is ErrorRed ? _sinConexion : e.mensaje);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }
}

// ====================================================================
// El resumen
// ====================================================================

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.resumen,
    required this.ocupado,
    required this.onRecargar,
    required this.onResolver,
    required this.onVerPerfil,
    required this.onElegirModo,
    required this.onGuardarObservaciones,
    required this.onPagar,
  });

  final ResumenCheckout resumen;
  final bool ocupado;
  final Future<void> Function() onRecargar;
  final void Function(BloqueoCheckout) onResolver;
  final VoidCallback onVerPerfil;
  final ValueChanged<String> onElegirModo;
  final ValueChanged<String?> onGuardarObservaciones;
  final VoidCallback onPagar;

  @override
  Widget build(BuildContext context) {
    final carrito = resumen.carrito;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRecargar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (resumen.bloqueos.isNotEmpty) ...[
                  ListaBloqueos(
                    bloqueos: resumen.bloqueos,
                    onResolver: onResolver,
                  ),
                  const SizedBox(height: 16),
                ],

                _Productos(lineas: carrito.lineas),

                const SizedBox(height: 16),

                SelectorEntrega(
                  entrega: resumen.entrega,
                  habilitado: !ocupado,
                  onElegirModo: onElegirModo,
                  onGuardarObservaciones: onGuardarObservaciones,
                ),

                const SizedBox(height: 16),

                TarjetaFacturacion(
                  datos: resumen.facturacion,
                  onVerPerfil: onVerPerfil,
                ),
              ],
            ),
          ),
        ),

        // El mismo pie del carrito, con la bandera del checkout. `puedePagar`
        // es más estricto que `puedeComprar`: mira también si el cliente
        // puede recibir factura.
        ResumenCarrito(
          carrito: carrito,
          ocupado: ocupado,
          habilitado: resumen.puedePagar,
          textoBoton: 'Pagar',
          icono: Icons.credit_card,
          motivoDeshabilitado: resumen.bloqueos.isEmpty
              ? null
              : 'Resolvé lo que falta para poder pagar.',
          onContinuar: onPagar,
        ),
      ],
    );
  }
}

/// Lo que se lleva, de sólo lectura.
///
/// Los importes son los mismos que mostró el carrito —salen del mismo
/// `CarritoService::resumen()` del backend— y no se recalcula ninguno.
class _Productos extends StatelessWidget {
  const _Productos({required this.lineas});

  final List<LineaCarrito> lineas;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 18, color: colores.outline),
                const SizedBox(width: 8),
                Text(
                  'Tu pedido',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 4),

            if (lineas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Tu carrito está vacío.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colores.outline),
                ),
              )
            else
              for (final linea in lineas) _Linea(linea: linea),
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.linea});

  final LineaCarrito linea;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Opacity(
      opacity: linea.disponible ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: ImagenRemota(
                url: linea.producto?.imagenUrl,
                relleno: const EdgeInsets.all(4),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${linea.cantidad} × ${linea.nombre}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (!linea.disponible)
                    Text(
                      linea.motivoNoDisponible ??
                          'Ya no está disponible.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colores.error),
                    )
                  else if (linea.requierePreventa)
                    Text(
                      linea.unidadesEnPreventa >= linea.cantidad
                          ? 'En preventa'
                          : '${linea.unidadesEnPreventa} en preventa',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colores.tertiary),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              // Una línea no disponible viene en cero desde el backend: no se
              // dibuja un importe que no se va a cobrar.
              linea.disponible ? Formato.pesos(linea.subtotal) : '—',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// No hay sesión, o falta verificar el correo.
///
/// Al checkout se llega desde el carrito, que ya filtra los dos casos, así
/// que esto sólo aparece si la sesión cambia con la pantalla abierta. Por eso
/// es un mensaje corto que invita a volver, y no una copia de las pantallas
/// que el carrito ya tiene.
class _SinAcceso extends StatelessWidget {
  const _SinAcceso();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: colores.outline),
            const SizedBox(height: 16),
            Text(
              'Tu sesión cambió mientras revisabas el pedido. Volvé al '
              'carrito para seguir.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colores.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al carrito'),
            ),
          ],
        ),
      ),
    );
  }
}
