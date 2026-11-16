import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../datos/modelos/compra.dart';
import '../../estado/compras_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/chip_estado_compra.dart';
import 'pantalla_compra_detalle.dart';
import 'pantalla_login.dart';

/// Mis compras: `GET /api/v1/compras`.
///
/// Equivale a `compras/index.blade.php`. Muestra los dos canales —una compra
/// en el local también es una compra del cliente— y no muestra presupuestos,
/// que el backend ya filtra.
///
/// **Vuelve a pedir en cada apertura.** Es lo que hace `iniciar()`, igual que
/// el catálogo. Acá tiene un efecto que conviene: después de pagar, la compra
/// nueva aparece sin que nadie invalide nada, y al volver del detalle el
/// estado del pedido está fresco. El seguimiento es justo lo que cambia del
/// lado del depósito mientras el cliente no mira.
///
/// **No exige correo verificado**, a diferencia del carrito: es la misma regla
/// que la web, y por eso esta pantalla no mira `usuario.emailVerificado`.
class PantallaCompras extends ConsumerStatefulWidget {
  const PantallaCompras({super.key});

  @override
  ConsumerState<PantallaCompras> createState() => _PantallaComprasState();
}

class _PantallaComprasState extends ConsumerState<PantallaCompras> {
  @override
  void initState() {
    super.initState();

    // Diferido a la próxima microtarea, igual que `PantallaCatalogo`:
    // `iniciar()` escribe en el provider, y hacerlo mientras se construye la
    // pantalla que lo está leyendo es lo que Riverpod no admite.
    Future.microtask(() {
      if (mounted) {
        ref.read(historialComprasProvider.notifier).iniciar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider);
    final estado = ref.watch(historialComprasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          'Mis compras',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
            color: Color(0xFF202B3C),
          ),
        ),
      ),
      body: SafeArea(
        child: usuario == null
            ? _SinSesion(onIngresar: () => _irAlLogin(context))
            : _Contenido(
                estado: estado,
                onRecargar: () =>
                    ref.read(historialComprasProvider.notifier).recargar(),
                onCargarMas: () =>
                    ref.read(historialComprasProvider.notifier).cargarMas(),
                onAbrir: (compra) => _abrirDetalle(context, compra),
              ),
      ),
    );
  }

  void _irAlLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
    );
  }

  void _abrirDetalle(BuildContext context, Compra compra) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaCompraDetalle(
          compraId: compra.id,
          // Se pasa el número que ya tenemos para poder titular la pantalla
          // mientras carga, en lugar de mostrar un encabezado vacío medio
          // segundo. El detalle que llega después manda igual.
          numeroConocido: compra.numeroFormateado,
        ),
      ),
    );
  }
}

// ====================================================================
// Cuerpo
// ====================================================================

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.estado,
    required this.onRecargar,
    required this.onCargarMas,
    required this.onAbrir,
  });

  final EstadoHistorial estado;
  final Future<void> Function() onRecargar;
  final VoidCallback onCargarMas;
  final void Function(Compra) onAbrir;

  @override
  Widget build(BuildContext context) {
    // Primera carga sin nada en pantalla todavía.
    if (estado.cargandoPrimera && estado.compras.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Falló la primera página: no hay historial que mostrar.
    final error = estado.errorInicial;

    if (error != null && estado.compras.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: [
          AvisoError(error: error, onReintentar: onRecargar),
        ],
      );
    }

    if (estado.sinCompras) {
      return const _SinCompras();
    }

    return RefreshIndicator(
      onRefresh: onRecargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        // Una fila más para el pie: "cargar más", el error de la página
        // siguiente, o el contador.
        itemCount: estado.compras.length + 1,
        itemBuilder: (context, i) {
          if (i == estado.compras.length) {
            return _Pie(
              estado: estado,
              onCargarMas: onCargarMas,
            );
          }

          final compra = estado.compras[i];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TarjetaCompra(
              compra: compra,
              onTocar: () => onAbrir(compra),
            ),
          );
        },
      ),
    );
  }
}

/// Pie de la lista: paginación y su error.
class _Pie extends StatelessWidget {
  const _Pie({required this.estado, required this.onCargarMas});

  final EstadoHistorial estado;
  final VoidCallback onCargarMas;

  @override
  Widget build(BuildContext context) {
    final errorMas = estado.errorAlCargarMas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),

        // El error de una página adicional se muestra acá y no reemplaza la
        // lista: las compras que ya están siguen siendo válidas.
        if (errorMas != null)
          AvisoError(error: errorMas, onReintentar: onCargarMas),

        if (estado.cargandoMas)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (estado.hayMas && errorMas == null)
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onCargarMas,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cargar más',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),

        if (estado.total > 0) ...[
          const SizedBox(height: 14),
          Text(
            'Mostrando ${estado.cantidadMostrada} de ${estado.total} '
            '${estado.total == 1 ? 'compra' : 'compras'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ],
    );
  }
}

// ====================================================================
// Tarjeta
// ====================================================================

/// Una compra en la lista.
///
/// Muestra lo mismo que la tarjeta de la web: número, fecha, canal cuando es
/// del mostrador, estado, modo de entrega, total y cuántos productos.
class _TarjetaCompra extends StatelessWidget {
  const _TarjetaCompra({required this.compra, required this.onTocar});

  final Compra compra;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTocar,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EDF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido ${compra.numeroFormateado}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF202B3C),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          // El canal se aclara sólo cuando es del mostrador:
                          // una compra que el cliente no hizo desde la app
                          // puede no reconocerla de entrada.
                          compra.esDelMostrador
                              ? '${Formato.fecha(compra.fecha)} · Compra en el local'
                              : Formato.fecha(compra.fecha),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Color(0xFFCBD5E1),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChipEstadoCompra(estado: compra.estado, compacto: true),
                        const SizedBox(height: 7),
                        Text(
                          compra.modoEntrega.etiqueta,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formato.pesos(compra.total),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Color(0xFF202B3C),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${compra.cantidadLineas} '
                        '${compra.cantidadLineas == 1 ? 'producto' : 'productos'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // El cobro sólo se menciona cuando falta algo. Un pedido pagado
              // no necesita una línea que lo diga: el estado ya lo cuenta.
              if (compra.pago.hayAlgoPendiente) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresTono.ambar.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 15,
                        color: ColoresTono.ambar,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          compra.pago.situacion == SituacionPago.parcial
                              ? '${compra.pago.etiqueta} · saldo ${Formato.pesos(compra.pago.saldo)}'
                              : compra.pago.etiqueta,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColoresTono.ambar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Estados sin lista
// ====================================================================

/// El cliente todavía no compró nada. **No es un error ni un estado de
/// carga**: tiene su propia pantalla, con la salida al catálogo.
class _SinCompras extends StatelessWidget {
  const _SinCompras();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 34,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Todavía no hiciste ninguna compra',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Color(0xFF202B3C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando compres, acá vas a poder seguir el estado de tus '
              'pedidos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                // Vuelve a la vitrina, que es la primera ruta de la pila. Es
                // el mismo gesto que usan login y "mi cuenta".
                onPressed: () =>
                    Navigator.of(context).popUntil((ruta) => ruta.isFirst),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Ver productos',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La sesión se cayó mientras la pantalla estaba abierta.
///
/// A esta pantalla se entra desde "Mi cuenta", así que normalmente hay sesión.
/// Esto cubre el caso en que el token venció o fue revocado desde otro
/// dispositivo: en lugar de pedir y mostrar un 401, se ofrece volver a entrar.
class _SinSesion extends StatelessWidget {
  const _SinSesion({required this.onIngresar});

  final VoidCallback onIngresar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ingresá para ver tus compras',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF202B3C),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onIngresar,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Ingresar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
