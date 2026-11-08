import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../datos/modelos/carrito.dart';
import '../../datos/modelos/linea_carrito.dart';
import '../../datos/modelos/usuario.dart';
import '../../estado/carrito_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/fila_carrito.dart';
import '../widgets/resumen_carrito.dart';
import 'pantalla_checkout.dart';
import 'pantalla_inicio.dart';
import 'pantalla_login.dart';
import 'pantalla_producto.dart';

const _fondo = Color(0xFFF5F7FA);
const _blanco = Colors.white;
const _texto = Color(0xFF202B3C);
const _secundario = Color(0xFF64748B);
const _azul = Color(0xFF2563EB);
const _borde = Color(0xFFE8EDF3);

/// El carrito: `GET /api/v1/carrito` y sus cuatro operaciones.
///
/// Cinco estados de pantalla:
/// 1. Invitado.
/// 2. Correo sin verificar.
/// 3. Cargando.
/// 4. Error.
/// 5. Carrito vacío o con líneas.
///
/// Nada se calcula acá. Totales, descuentos, preventa, disponibilidad y
/// `puede_comprar` llegan resueltos del backend.
void abrirCarrito(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaCarrito()),
  );
}

class PantallaCarrito extends ConsumerStatefulWidget {
  const PantallaCarrito({super.key});

  @override
  ConsumerState<PantallaCarrito> createState() => _PantallaCarritoState();
}

class _PantallaCarritoState extends ConsumerState<PantallaCarrito> {
  /// Bloquea los controles mientras se procesa una operación.
  bool _ocupado = false;

  /// Ejecuta una operación del carrito y muestra el resultado.
  Future<void> _operar(
      Future<void> Function() accion, {
        String? exito,
      }) async {
    if (_ocupado) return;

    final visible = mounted;

    if (visible) setState(() => _ocupado = true);

    try {
      await accion();

      if (mounted && exito != null) _avisar(exito);
    } on ErrorEmailNoVerificado {
      if (mounted) {
        _avisar('Necesitás confirmar tu correo para usar el carrito.');
      }
      await ref.read(sesionProvider.notifier).refrescarUsuario();
    } on ErrorValidacion catch (e) {
      if (mounted) _avisar(e.mensaje);
    } on ErrorNoEncontrado {
      if (mounted) _avisar('Esa línea ya no está en tu carrito.');
      await ref.read(carritoProvider.notifier).recargar();
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

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider);
    final estado = ref.watch(carritoProvider);

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _blanco,
        foregroundColor: _texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Mi carrito',
          style: TextStyle(
            color: _texto,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _borde),
        ),
        actions: [
          if ((estado.value?.vacio ?? true) == false)
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.delete_sweep_outlined),
              color: _secundario,
              onPressed: _ocupado ? null : _confirmarVaciado,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _cuerpo(usuario, estado),
      ),
    );
  }

  Widget _cuerpo(Usuario? usuario, AsyncValue<Carrito?> estado) {
    // Estado 1: invitado.
    if (usuario == null) return const _Invitado();

    // Estado 2: correo sin verificar.
    if (!usuario.emailVerificado) return const _SinVerificar();

    return estado.when(
      // Estado 3: cargando.
      loading: () => const Center(
        child: CircularProgressIndicator(color: _azul),
      ),

      // Estado 4: error.
      error: (e, _) => _Falla(
        error: e,
        onReintentar: () => ref.read(carritoProvider.notifier).recargar(),
      ),

      // Estado 5: carrito.
      data: (carrito) => _Carrito(
        carrito: carrito ?? Carrito.ninguno,
        ocupado: _ocupado,
        onRecargar: () => ref.read(carritoProvider.notifier).recargar(),
        onCambiarCantidad: (linea, cantidad) => _operar(
              () => ref.read(carritoProvider.notifier).cambiarCantidad(
            lineaId: linea.id,
            cantidad: cantidad,
          ),
        ),
        onQuitar: (linea) => _operar(
              () => ref.read(carritoProvider.notifier).quitar(linea.id),
          exito: 'Quitamos ${linea.nombre} de tu carrito.',
        ),
        onContinuar: _irAlCheckout,
      ),
    );
  }

  /// Lleva a la revisión previa al pago.
  void _irAlCheckout() {
    abrirCheckout(context);
  }

  Future<void> _confirmarVaciado() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: _blanco,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '¿Vaciar el carrito?',
          style: TextStyle(
            color: _texto,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Se van a quitar todos los productos. Esto no se puede deshacer.',
          style: TextStyle(
            color: _secundario,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: _secundario),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: _blanco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    await _operar(
          () => ref.read(carritoProvider.notifier).vaciar(),
      exito: 'Vaciamos tu carrito.',
    );
  }
}

// ====================================================================
// Estado 5: el carrito
// ====================================================================

class _Carrito extends StatelessWidget {
  const _Carrito({
    required this.carrito,
    required this.ocupado,
    required this.onRecargar,
    required this.onCambiarCantidad,
    required this.onQuitar,
    required this.onContinuar,
  });

  final Carrito carrito;
  final bool ocupado;
  final Future<void> Function() onRecargar;
  final void Function(LineaCarrito linea, int cantidad) onCambiarCantidad;
  final void Function(LineaCarrito linea) onQuitar;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    if (carrito.vacio) {
      return RefreshIndicator(
        color: _azul,
        onRefresh: onRecargar,
        child: const _Vacio(),
      );
    }

    final noDisponibles = carrito.lineasNoDisponibles.length;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: _azul,
            onRefresh: onRecargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                if (noDisponibles > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: AvisoInformativo(
                      titulo: noDisponibles == 1
                          ? 'Un producto ya no está disponible'
                          : '$noDisponibles productos ya no están disponibles',
                      detalle: 'Quitalos del carrito para poder continuar con '
                          'la compra. No se suman al total.',
                      icono: Icons.remove_shopping_cart_outlined,
                    ),
                  ),

                for (final linea in carrito.lineas) ...[
                  FilaCarrito(
                    linea: linea,
                    habilitado: !ocupado,
                    onCambiarCantidad: (cantidad) =>
                        onCambiarCantidad(linea, cantidad),
                    onQuitar: () => onQuitar(linea),
                    onTocar: linea.producto == null
                        ? null
                        : () => abrirFicha(context, linea.producto!),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: _borde,
                  ),
                ],
              ],
            ),
          ),
        ),

        // El resumen permanece fijo debajo de la lista.
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _blanco,
            border: Border(
              top: BorderSide(color: _borde, width: 1),
            ),
          ),
          child: ResumenCarrito(
            carrito: carrito,
            ocupado: ocupado,
            onContinuar: onContinuar,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Estados vacíos y de acceso
// ====================================================================

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        const _Mensaje(
          icono: Icons.shopping_cart_outlined,
          titulo: 'Tu carrito está vacío',
          detalle: 'Buscá lo que necesitás en el catálogo y agregalo desde la '
              'ficha del producto.',
        ),
      ],
    );
  }
}

/// Estado 1: el carrito exige sesión.
class _Invitado extends StatelessWidget {
  const _Invitado();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        const _Mensaje(
          icono: Icons.lock_outline,
          titulo: 'Ingresá para usar el carrito',
          detalle: 'El carrito es de tu cuenta: ahí guardamos lo que elegiste '
              'aunque cierres la app.',
        ),
        const SizedBox(height: 28),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: _blanco,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PantallaLogin(),
              ),
            ),
            icon: const Icon(Icons.login_rounded, size: 19),
            label: const Text(
              'Ingresar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado 2: el token sirve, falta confirmar el correo.
class _SinVerificar extends ConsumerWidget {
  const _SinVerificar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.10),
        _Mensaje(
          icono: Icons.mark_email_unread_outlined,
          titulo: 'Confirmá tu correo',
          detalle: usuario == null
              ? 'Hasta que confirmes tu correo no podés usar el carrito.'
              : 'Te mandamos un correo a ${usuario.email}. Hasta que lo '
              'confirmes podés mirar el catálogo, pero no armar tu '
              'pedido.',
        ),
        const SizedBox(height: 28),
        Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _azul,
                  side: const BorderSide(color: _azul),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    ref.read(sesionProvider.notifier).refrescarUsuario(),
                child: const Text('Ya lo confirmé'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: _blanco,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: usuario == null
                    ? null
                    : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PantallaInicio(usuario: usuario),
                  ),
                ),
                child: const Text('Reenviar correo'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Estado 4: error al cargar el carrito.
class _Falla extends StatelessWidget {
  const _Falla({
    required this.error,
    required this.onReintentar,
  });

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        if (error is ErrorApi)
          AvisoError(
            error: error as ErrorApi,
            onReintentar: onReintentar,
          )
        else
          AvisoError(
            error: ErrorFormato('$error'),
            onReintentar: onReintentar,
          ),
      ],
    );
  }
}

// ====================================================================
// Mensaje reutilizable
// ====================================================================

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            icono,
            size: 48,
            color: _azul,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          titulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            detalle,
            style: const TextStyle(
              color: _secundario,
              fontSize: 14,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}