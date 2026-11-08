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
import 'pantalla_inicio.dart';
import 'pantalla_login.dart';
import 'pantalla_producto.dart';

/// El carrito: `GET /api/v1/carrito` y sus cuatro operaciones.
///
/// **Cinco estados de pantalla, y el orden en que se preguntan importa:**
///
///  1. **Invitado.** No se llama a la API: daría 401. Se invita a ingresar.
///  2. **Correo sin verificar.** Tampoco se llama: daría 403. `Usuario` trae
///     `emailVerificado` justamente para poder mostrar la pantalla correcta
///     *antes* de chocar con el error, en vez de después.
///  3. **Cargando.**
///  4. **Error.** Con reintento, salvo que sea un 403 de verificación, que
///     tiene su propio camino.
///  5. **El carrito**, vacío o con líneas.
///
/// **Nada se calcula acá.** Totales, descuentos, preventa, disponibilidad y
/// `puede_comprar` llegan resueltos del backend. Lo único que la pantalla
/// decide es qué dibuja con cada bandera.
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
  /// Hay una operación en curso.
  ///
  /// Bloquea los controles de todas las filas, no solo la tocada: cualquier
  /// operación devuelve el carrito entero recalculado, así que dos en vuelo
  /// al mismo tiempo pueden llegar desordenadas y dejar en pantalla el
  /// resultado de la primera.
  bool _ocupado = false;

  /// Corre una operación del carrito mostrando el resultado al usuario.
  ///
  /// Los errores van a un `SnackBar` y **no desarman la lista**: el carrito
  /// que se está viendo sigue siendo el último válido, y un `+` que no llegó
  /// no es motivo para vaciar la pantalla.
  Future<void> _operar(
    Future<void> Function() accion, {
    String? exito,
  }) async {
    if (_ocupado) return;

    // **La operación corre esté la pantalla montada o no, pero el setState
    // no.** `SelectorCantidad` manda su ráfaga pendiente desde `dispose()`,
    // o sea mientras esta pantalla se desmonta: ahí el cambio de cantidad
    // tiene que llegar igual al backend —si no, el último toque se pierde en
    // silencio— pero tocar el estado del widget revienta con "setState()
    // called after dispose()". El provider vive más que la pantalla, así que
    // la llamada es segura; lo que no es seguro es el `setState` y el
    // `SnackBar`.
    final visible = mounted;

    if (visible) setState(() => _ocupado = true);

    try {
      await accion();

      if (mounted && exito != null) _avisar(exito);
    } on ErrorEmailNoVerificado {
      // El estado local decía que estaba verificado y el backend dice que no.
      // Se pide /auth/yo de nuevo: el notifier se reconstruye solo con el
      // usuario nuevo y la pantalla pasa al estado 2.
      if (mounted) {
        _avisar('Necesitás confirmar tu correo para usar el carrito.');
      }
      await ref.read(sesionProvider.notifier).refrescarUsuario();
    } on ErrorValidacion catch (e) {
      // 422. El caso real es un producto que se despublicó entre que se
      // dibujó la pantalla y que se tocó el botón.
      if (mounted) _avisar(e.mensaje);
    } on ErrorNoEncontrado {
      // 404: la línea ya no existe. Pasa si se quitó desde la web en otro
      // lado. El carrito se recarga para que la pantalla se ponga al día.
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
      appBar: AppBar(
        title: const Text('Mi carrito'),
        actions: [
          // Solo cuando hay algo que vaciar. Un botón que no hace nada es
          // peor que no tenerlo.
          if ((estado.value?.vacio ?? true) == false)
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _ocupado ? null : _confirmarVaciado,
            ),
        ],
      ),

      body: SafeArea(child: _cuerpo(usuario, estado)),
    );
  }

  Widget _cuerpo(Usuario? usuario, AsyncValue<Carrito?> estado) {
    // Estado 1: invitado. No se pide nada.
    if (usuario == null) return const _Invitado();

    // Estado 2: correo sin verificar. Tampoco se pide nada.
    if (!usuario.emailVerificado) return const _SinVerificar();

    return estado.when(
      // Estado 3.
      loading: () => const Center(child: CircularProgressIndicator()),

      // Estado 4.
      error: (e, _) => _Falla(
        error: e,
        onReintentar: () => ref.read(carritoProvider.notifier).recargar(),
      ),

      // Estado 5.
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
        onContinuar: _avisarCheckoutPendiente,
      ),
    );
  }

  /// El paso 8 es el checkout. Hasta entonces el botón existe, se habilita
  /// con `puede_comprar` y avisa: así se puede verificar que la bandera
  /// funciona sin adelantar la etapa siguiente.
  void _avisarCheckoutPendiente() {
    _avisar('El checkout llega en la próxima etapa.');
  }

  Future<void> _confirmarVaciado() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Vaciar el carrito?'),
        content: const Text(
          'Se van a quitar todos los productos. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
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
        onRefresh: onRecargar,
        child: const _Vacio(),
      );
    }

    final noDisponibles = carrito.lineasNoDisponibles.length;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRecargar,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (noDisponibles > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        ),

        ResumenCarrito(
          carrito: carrito,
          ocupado: ocupado,
          onContinuar: onContinuar,
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
    // ListView y no Column: el RefreshIndicator necesita algo desplazable
    // para poder tirar hacia abajo.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
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

/// Estado 1. El carrito exige sesión, así que no hay nada que pedir.
class _Invitado extends StatelessWidget {
  const _Invitado();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.14),
        const _Mensaje(
          icono: Icons.lock_outline,
          titulo: 'Ingresá para usar el carrito',
          detalle: 'El carrito es de tu cuenta: ahí guardamos lo que elegiste '
              'aunque cierres la app.',
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
            ),
            child: const Text('Ingresar'),
          ),
        ),
      ],
    );
  }
}

/// Estado 2. El token sirve, falta confirmar el correo.
///
/// **No se llama a la API para descubrirlo.** El backend respondería 403 con
/// `codigo: "email_no_verificado"`, pero `Usuario.emailVerificado` ya lo dice
/// sin gastar una llamada que sabemos que falla.
///
/// El botón de reenvío no se duplica acá: ya vive en "Mi cuenta", junto al
/// resto de los avisos de la cuenta, y tener dos lugares desde donde reenviar
/// el mismo correo complica el throttle de seis por minuto del backend.
class _SinVerificar extends ConsumerWidget {
  const _SinVerificar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        _Mensaje(
          icono: Icons.mark_email_unread_outlined,
          titulo: 'Confirmá tu correo',
          detalle: usuario == null
              ? 'Hasta que confirmes tu correo no podés usar el carrito.'
              : 'Te mandamos un correo a ${usuario.email}. Hasta que lo '
                  'confirmes podés mirar el catálogo, pero no armar tu '
                  'pedido.',
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () =>
                    ref.read(sesionProvider.notifier).refrescarUsuario(),
                child: const Text('Ya lo confirmé'),
              ),
              FilledButton(
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

/// Estado 4.
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
        if (error is ErrorApi)
          AvisoError(error: error as ErrorApi, onReintentar: onReintentar)
        else
          AvisoError(
            error: ErrorFormato('$error'),
            onReintentar: onReintentar,
          ),
      ],
    );
  }
}

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
    final colores = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icono, size: 56, color: colores.outline),
        const SizedBox(height: 16),
        Text(
          titulo,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            detalle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colores.outline),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
