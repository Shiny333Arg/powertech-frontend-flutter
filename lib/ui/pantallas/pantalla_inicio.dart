
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../datos/modelos/usuario.dart';
import '../../estado/proveedores_core.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import 'pantalla_compras.dart';
import 'pantalla_perfil.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _cerrarSesion() async {
    setState(() => _cerrando = true);

    await ref.read(sesionProvider.notifier).cerrarSesion();

    if (mounted) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider) ?? widget.usuario;
    final cliente = usuario.cliente;
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          'Mi cuenta',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
            color: Color(0xFF202B3C),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          children: [
            // Encabezado del perfil.
            _TarjetaPerfil(usuario: usuario),

            const SizedBox(height: 16),

            // Mis compras.
            //
            // Va arriba de los avisos de cuenta y de los datos a propósito: es
            // la única acción de esta pantalla —el resto es informativo— y es
            // lo que el cliente viene a buscar cuando entra a "Mi cuenta".
            //
            // Ninguno de los dos se condiciona a `emailVerificado`: ni el
            // historial ni el perfil lo exigen, igual que en la web. El
            // carrito sí, y por eso ese aviso sigue apareciendo abajo.
            //
            // El perfil es, además, la salida del callejón: un cliente que se
            // equivocó al escribir su correo al registrarse lo corrige ahí.
            _FilaAcceso(
              icono: Icons.receipt_long_rounded,
              titulo: 'Mis compras',
              detalle: 'Seguí el estado de tus pedidos y mirá tus facturas.',
              onTocar: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PantallaCompras(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            _FilaAcceso(
              icono: Icons.manage_accounts_rounded,
              titulo: 'Editar mis datos',
              detalle: 'Cambiá tu nombre, tu correo, tus datos de '
                  'facturación o tu contraseña.',
              onTocar: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PantallaPerfil(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Avisos de cuenta.
            if (!usuario.emailVerificado) ...[
              AvisoInformativo(
                titulo: 'Verificá tu correo',
                detalle: 'Te mandamos un correo a ${usuario.email}. '
                    'Hasta que lo verifiques vas a poder mirar el catálogo, '
                    'pero no agregar al carrito ni comprar.',
                icono: Icons.mark_email_unread_outlined,
                accion: _reenviando ? null : _reenviarVerificacion,
                textoAccion: 'Reenviar correo',
                ocupado: _reenviando,
              ),
              const SizedBox(height: 12),
            ],

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
                icono: Icons.receipt_long_rounded,
              ),

            const SizedBox(height: 24),

            const _TituloSeccion('Información personal'),
            const SizedBox(height: 12),

            _TarjetaDatos(
              children: [
                _Dato(
                  etiqueta: 'Nombre completo',
                  valor: usuario.nombreCompleto,
                  icono: Icons.person_outline_rounded,
                ),
                _Dato(
                  etiqueta: 'Correo electrónico',
                  valor: usuario.email,
                  icono: Icons.email_outlined,
                ),
                _Dato(
                  etiqueta: 'Estado del correo',
                  valor: usuario.emailVerificado ? 'Verificado' : 'Pendiente',
                  icono: Icons.verified_user_outlined,
                  estado: usuario.emailVerificado,
                ),
              ],
            ),

            if (cliente != null) ...[
              const SizedBox(height: 24),
              const _TituloSeccion('Datos de facturación'),
              const SizedBox(height: 12),
              _TarjetaDatos(
                children: [
                  _Dato(
                    etiqueta: 'Razón social',
                    valor: cliente.razonSocial ?? '—',
                    icono: Icons.business_outlined,
                  ),
                  _Dato(
                    etiqueta: 'Teléfono',
                    valor: cliente.telefono ?? '—',
                    icono: Icons.phone_outlined,
                  ),
                  _Dato(
                    etiqueta: 'Documento',
                    valor: cliente.tipoDocumento == null
                        ? cliente.nroDoc
                        : '${cliente.tipoDocumento!.nombre} ${cliente.nroDoc}',
                    icono: Icons.badge_outlined,
                  ),
                  _Dato(
                    etiqueta: 'Condición frente al IVA',
                    valor: cliente.condicionIva?.nombre ?? '—',
                    icono: Icons.receipt_long_outlined,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Cierre de sesión.
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _cerrando ? null : _cerrarSesion,
                icon: _cerrando
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.logout_rounded, size: 19),
                label: Text(
                  _cerrando ? 'Cerrando sesión...' : 'Cerrar sesión',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC4545),
                  side: BorderSide(
                    color: const Color(0xFFDC4545).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Cerrar sesión revoca el token de este dispositivo solamente. '
                    'Si iniciaste sesión en otro, ese sigue abierto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MI CUENTA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hola, ${usuario.nombres}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: Color(0xFF202B3C),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Administrá tu información personal y de facturación.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}


/// Fila de acceso a otra pantalla de la cuenta.
///
/// Son las únicas acciones de "Mi cuenta" —el resto de la pantalla es
/// informativo— así que van arriba, antes de los avisos y los datos.
class _FilaAcceso extends StatelessWidget {
  const _FilaAcceso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTocar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

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
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colores.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icono, size: 21, color: colores.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Color(0xFF202B3C),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detalle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
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
        ),
      ),
    );
  }
}

class _EstadoCorreo extends StatelessWidget {
  const _EstadoCorreo({required this.verificado});

  final bool verificado;

  @override
  Widget build(BuildContext context) {
    final color = verificado
        ? const Color(0xFF16845B)
        : const Color(0xFFB7791F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verificado
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            verificado ? 'Correo verificado' : 'Correo pendiente',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Color(0xFF202B3C),
          ),
        ),
      ],
    );
  }
}

class _TarjetaDatos extends StatelessWidget {
  const _TarjetaDatos({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(children: children),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.estado,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final bool? estado;

  @override
  Widget build(BuildContext context) {
    final colorEstado = estado == true
        ? const Color(0xFF16845B)
        : const Color(0xFFB7791F);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icono,
              size: 19,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: estado == null
                        ? const Color(0xFF202B3C)
                        : colorEstado,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
