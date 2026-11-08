import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/navegador.dart';
import '../../datos/modelos/pago.dart';
import '../../estado/pago_providers.dart';
import '../widgets/aviso.dart';

/// Lo que pasa después de abrir Mercado Pago.
///
/// **Por qué existe esta pantalla y no un deep link.** El cliente paga en el
/// navegador del sistema, fuera de la app. Para que la app recupere el
/// control sola hace falta registrar un esquema propio en
/// `AndroidManifest.xml` y en `Info.plist`, más un plugin que escuche los
/// enlaces entrantes. Esto hace lo mismo sin nada de eso: detecta que la app
/// volvió al frente —`AppLifecycleState.resumed`, que es API de Flutter, sin
/// dependencias— y le pregunta al backend qué pasó.
///
/// Además es más robusto que el deep link, no sólo más barato: funciona
/// aunque el cliente vuelva con el gesto de aplicaciones recientes en lugar
/// de tocar el botón de la página de rebote, y aunque cierre el navegador sin
/// volver a ninguna parte.
///
/// **No se le cree nada al navegador.** Ni la URL de retorno ni su query
/// string entran en esta pantalla. La única fuente es
/// `GET /api/v1/checkout/estado`, que lo decide el backend.
///
/// **Y el pedido no lo crea nadie de este lado.** La venta nace del webhook
/// que Mercado Pago manda a Laravel, firmado y con reintentos. Si el cliente
/// nunca vuelve a abrir la app, la compra se registra igual.
class PantallaEsperandoPago extends ConsumerStatefulWidget {
  const PantallaEsperandoPago({super.key, required this.urlPago});

  /// La URL del checkout de Mercado Pago. Ya se abrió una vez; se guarda por
  /// si el cliente vuelve sin haber pagado y quiere reintentar sin rehacer
  /// la orden de cobro.
  final String urlPago;

  @override
  ConsumerState<PantallaEsperandoPago> createState() =>
      _PantallaEsperandoPagoState();
}

class _PantallaEsperandoPagoState extends ConsumerState<PantallaEsperandoPago>
    with WidgetsBindingObserver {
  Timer? _sondeo;

  /// Cuántas veces se preguntó sola. Se frena para no quedar consultando
  /// para siempre: después el cliente decide con el botón.
  int _intentos = 0;

  static const int _intentosMaximos = 6;
  static const Duration _entreIntentos = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Una primera consulta al entrar cubre el caso en que el pago se acreditó
    // y el webhook llegó mientras el cliente todavía estaba en el navegador.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consultar());
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // **Este es el momento importante de toda la pantalla.** La app volvió al
    // frente: el cliente cerró el navegador, pagó, o se arrepintió. Cuál de
    // las tres lo dice el backend.
    if (estado == AppLifecycleState.resumed) {
      _intentos = 0;
      _consultar();
    }
  }

  Future<void> _consultar() async {
    _sondeo?.cancel();

    await ref.read(estadoPagoProvider.notifier).consultar();

    if (!mounted) return;

    final resultado = ref.read(estadoPagoProvider)?.value?.resultado;

    // Sólo se vuelve a preguntar solo mientras haya algo que esperar. Un
    // rechazo o una compra cerrada no cambian por insistir.
    if (resultado != null &&
        resultado.conviveneReintentar &&
        _intentos < _intentosMaximos) {
      _intentos++;
      _sondeo = Timer(_entreIntentos, _consultar);
    }
  }

  /// Vuelve a abrir el checkout, sin crear otra orden de cobro.
  Future<void> _reabrirMercadoPago() async {
    final abierto = await abrirEnNavegador(widget.urlPago);

    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir Mercado Pago en el navegador.'),
        ),
      );
    }
  }

  /// Sale de la pantalla y vuelve a la vitrina.
  void _volverAlInicio() {
    ref.read(estadoPagoProvider.notifier).limpiar();
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoPagoProvider);

    return PopScope(
      // Salir con el botón atrás está bien, pero conviene limpiar primero:
      // el próximo pago no tiene que arrancar mostrando el resultado viejo.
      onPopInvokedWithResult: (_, __) =>
          ref.read(estadoPagoProvider.notifier).limpiar(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Tu pago')),
        body: SafeArea(
          child: switch (estado) {
            null => const _Esperando(),
            AsyncLoading() => const _Esperando(),
            AsyncError(:final error) => _Falla(
                error: error,
                onReintentar: _consultar,
              ),
            AsyncData(:final value) => _Resultado(
                estado: value,
                consultando: _sondeo?.isActive ?? false,
                onConsultar: _consultar,
                onReabrir: _reabrirMercadoPago,
                onVolver: _volverAlInicio,
                onVolverAlCarrito: () {
                  ref.read(estadoPagoProvider.notifier).limpiar();
                  Navigator.of(context).pop();
                },
              ),
          },
        ),
      ),
    );
  }
}

// ====================================================================
// Estados de la pantalla
// ====================================================================

class _Esperando extends StatelessWidget {
  const _Esperando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Estamos consultando tu pago...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.estado,
    required this.consultando,
    required this.onConsultar,
    required this.onReabrir,
    required this.onVolver,
    required this.onVolverAlCarrito,
  });

  final EstadoPago estado;
  final bool consultando;
  final VoidCallback onConsultar;
  final VoidCallback onReabrir;
  final VoidCallback onVolver;
  final VoidCallback onVolverAlCarrito;

  @override
  Widget build(BuildContext context) {
    return switch (estado.resultado) {
      ResultadoPago.aprobado => _Aprobado(
          venta: estado.venta,
          onVolver: onVolver,
        ),
      ResultadoPago.rechazado => _Rechazado(
          onReintentar: onReabrir,
          onVolverAlCarrito: onVolverAlCarrito,
        ),
      ResultadoPago.sinPago => _SinPago(
          onReintentar: onReabrir,
          onVolverAlCarrito: onVolverAlCarrito,
        ),
      // Desconocido se trata como pendiente: seguir preguntando es lo seguro.
      ResultadoPago.pendiente ||
      ResultadoPago.desconocido =>
        _Pendiente(
          consultando: consultando,
          onConsultar: onConsultar,
          onVolver: onVolver,
        ),
    };
  }
}

class _Aprobado extends StatelessWidget {
  const _Aprobado({required this.venta, required this.onVolver});

  final VentaResumen? venta;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.check_circle_outline, size: 64, color: colores.primary),
        const SizedBox(height: 20),

        Text(
          '¡Listo!',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // El texto lo escribe el backend: depende de si hay stock físico o si
        // el pedido queda esperando reposición, y eso no lo decide la app.
        Text(
          venta?.mensaje ?? 'Registramos tu pago.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),

        if (venta != null) ...[
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Dato('Pedido', venta!.numero),
                  _Dato('Total', Formato.pesos(venta!.total)),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 28),

        FilledButton(
          onPressed: onVolver,
          child: const Text('Volver a la tienda'),
        ),
      ],
    );
  }
}

class _Pendiente extends StatelessWidget {
  const _Pendiente({
    required this.consultando,
    required this.onConsultar,
    required this.onVolver,
  });

  final bool consultando;
  final VoidCallback onConsultar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.schedule, size: 64, color: colores.tertiary),
        const SizedBox(height: 20),

        Text(
          'Estamos confirmando tu pago',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          'Mercado Pago todavía no nos confirmó la operación. Puede tardar '
          'unos minutos.\n\n'
          'No hace falta que esperes acá: si el pago se acredita, el pedido '
          'se registra igual aunque cierres la aplicación.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: consultando ? null : onConsultar,
          icon: consultando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(consultando ? 'Consultando...' : 'Volver a consultar'),
        ),

        const SizedBox(height: 8),

        TextButton(
          onPressed: onVolver,
          child: const Text('Volver a la tienda'),
        ),
      ],
    );
  }
}

class _Rechazado extends StatelessWidget {
  const _Rechazado({
    required this.onReintentar,
    required this.onVolverAlCarrito,
  });

  final VoidCallback onReintentar;
  final VoidCallback onVolverAlCarrito;

  @override
  Widget build(BuildContext context) {
    return _Negativo(
      icono: Icons.error_outline,
      titulo: 'El pago no se aprobó',
      detalle: 'Mercado Pago rechazó la operación. Tu carrito quedó como '
          'estaba: podés intentar de nuevo con otro medio de pago.',
      onReintentar: onReintentar,
      onVolverAlCarrito: onVolverAlCarrito,
    );
  }
}

class _SinPago extends StatelessWidget {
  const _SinPago({
    required this.onReintentar,
    required this.onVolverAlCarrito,
  });

  final VoidCallback onReintentar;
  final VoidCallback onVolverAlCarrito;

  @override
  Widget build(BuildContext context) {
    return _Negativo(
      icono: Icons.shopping_cart_outlined,
      titulo: 'No se registró ningún pago',
      detalle: 'Cerraste el checkout antes de pagar. Tu carrito quedó '
          'completo y podés retomar cuando quieras.',
      onReintentar: onReintentar,
      onVolverAlCarrito: onVolverAlCarrito,
    );
  }
}

class _Negativo extends StatelessWidget {
  const _Negativo({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onReintentar,
    required this.onVolverAlCarrito,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onReintentar;
  final VoidCallback onVolverAlCarrito;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 24),
        Icon(icono, size: 64, color: colores.outline),
        const SizedBox(height: 20),

        Text(
          titulo,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          detalle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Volver a Mercado Pago'),
        ),

        const SizedBox(height: 8),

        TextButton(
          onPressed: onVolverAlCarrito,
          child: const Text('Volver al pedido'),
        ),
      ],
    );
  }
}

class _Falla extends StatelessWidget {
  const _Falla({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        AvisoError(
          error: error is ErrorApi ? error as ErrorApi : ErrorFormato('$error'),
          onReintentar: onReintentar,
        ),
        const SizedBox(height: 12),
        Text(
          'Si ya pagaste, no vuelvas a hacerlo: el pedido se registra solo '
          'cuando Mercado Pago nos confirma la operación.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            valor,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
