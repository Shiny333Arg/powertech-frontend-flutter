import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../datos/modelos/usuario.dart';
import '../../estado/proveedores_core.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import 'pantalla_diagnostico.dart';

/// Pantalla provisoria de sesión iniciada.
///
/// En el paso 3 la reemplaza la vitrina. Lo que hay acá es lo mínimo para
/// poder verificar el paso 2: quién inició sesión, en qué estado está su
/// correo, y el botón de cerrar sesión.
///
/// El aviso de correo sin verificar **no es decorativo**: es el segundo de
/// los tres estados del contrato. El cliente tiene token y puede mirar, pero
/// el middleware `verified` le va a rechazar carrito y checkout. Mostrarlo
/// acá es lo que evita que se entere recién con un 403 a mitad de una
/// compra.
class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
  bool _reenviando = false;
  bool _cerrando = false;

  Future<void> _reenviarVerificacion() async {
    setState(() => _reenviando = true);

    String mensaje;

    try {
      mensaje = await ref.read(authRepositoryProvider).reenviarVerificacion();
      // Puede haber verificado desde el navegador mientras tanto.
      await ref.read(sesionProvider.notifier).refrescarUsuario();
    } on ErrorDemasiadosIntentos catch (e) {
      mensaje = e.mensaje;
    } on ErrorApi catch (e) {
      mensaje = e is ErrorRed
          ? 'No pudimos conectarnos con el servidor. Probá de nuevo.'
          : e.mensaje;
    }

    if (!mounted) return;

    setState(() => _reenviando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cerrarSesion() async {
    setState(() => _cerrando = true);

    await ref.read(sesionProvider.notifier).cerrarSesion();

    // Desde el paso 3 esta pantalla está apilada sobre la vitrina en lugar de
    // ser la raíz del cliente, así que hay que volver: si no, el usuario se
    // queda mirando sus propios datos después de cerrar sesión. La vitrina ya
    // se recargó sola —`cerrarSesion()` invalida el catálogo— y aparece sin
    // precios.
    if (mounted) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se mira el provider y no solo `widget.usuario`. En el paso 2 esta
    // pantalla era la raíz del cliente y el widget raíz la reconstruía con el
    // usuario nuevo; ahora está apilada sobre la vitrina, así que si leyera
    // únicamente el parámetro del constructor, `refrescarUsuario()` no se
    // vería: el cliente que verifica su correo en el navegador y vuelve
    // seguiría mirando el cartel de "verificá tu correo".
    //
    // El fallback cubre el instante entre cerrar sesión y el pop, cuando el
    // provider ya devuelve null pero esta pantalla todavía está en pantalla.
    final usuario = ref.watch(usuarioProvider) ?? widget.usuario;
    final cliente = usuario.cliente;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        actions: [
          IconButton(
            tooltip: 'Diagnóstico de conexión',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PantallaDiagnostico(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hola, ${usuario.nombres}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            if (!usuario.emailVerificado)
              AvisoInformativo(
                titulo: 'Verificá tu correo',
                detalle: 'Te mandamos un correo a ${usuario.email}. Hasta que '
                    'lo verifiques vas a poder mirar el catálogo, pero no '
                    'agregar al carrito ni comprar.',
                icono: Icons.mark_email_unread_outlined,
                accion: _reenviando ? null : _reenviarVerificacion,
                textoAccion: 'Reenviar correo',
                ocupado: _reenviando,
              ),

            if (cliente == null)
              const AvisoInformativo(
                titulo: 'Faltan tus datos de facturación',
                detalle: 'Tu cuenta no tiene un cliente asociado, así que no '
                    'vamos a poder facturarte. Acercate al local para que te '
                    'vinculen la cuenta.',
                icono: Icons.badge_outlined,
              )
            else if (!cliente.tieneDatosParaFacturar)
              const AvisoInformativo(
                titulo: 'Faltan tus datos de facturación',
                detalle: 'Te falta cargar el tipo de documento o la condición '
                    'frente al IVA. Sin eso no vamos a poder facturarte la '
                    'compra.',
                icono: Icons.receipt_long,
              ),

            const Divider(height: 32),

            _Dato('Nombre', usuario.nombreCompleto),
            _Dato('Correo', usuario.email),
            _Dato(
              'Correo verificado',
              usuario.emailVerificado ? 'Sí' : 'Todavía no',
            ),

            if (cliente != null) ...[
              const Divider(height: 32),
              _Dato('Razón social', cliente.razonSocial ?? '—'),
              _Dato('Teléfono', cliente.telefono ?? '—'),
              _Dato(
                'Documento',
                cliente.tipoDocumento == null
                    ? cliente.nroDoc
                    : '${cliente.tipoDocumento!.nombre} ${cliente.nroDoc}',
              ),
              _Dato('Condición IVA', cliente.condicionIva?.nombre ?? '—'),
            ],

            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed: _cerrando ? null : _cerrarSesion,
              icon: const Icon(Icons.logout),
              label: Text(_cerrando ? 'Cerrando...' : 'Cerrar sesión'),
            ),

            const SizedBox(height: 8),

            Text(
              'Cerrar sesión revoca el token de este dispositivo solamente. '
              'Si iniciaste sesión en otro, ese sigue abierto.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              etiqueta,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: SelectableText(valor)),
        ],
      ),
    );
  }
}
