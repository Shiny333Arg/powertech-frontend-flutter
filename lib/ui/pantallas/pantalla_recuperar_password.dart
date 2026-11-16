import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../estado/proveedores_core.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';
import 'pantalla_restablecer_password.dart';

/// Paso 1 de "olvidé mi contraseña": pedir el correo con el enlace.
///
/// Equivalente de `auth/forgot-password.blade.php`. Se llega desde el enlace
/// de [PantallaLogin] y se vuelve ahí; no hay otra entrada.
///
/// **No toca la sesión y es lo que la hace segura de apilar sobre el login.**
/// No lee `sesionProvider`, no lo escribe y no guarda ningún token: llama al
/// repositorio directo, como hacen `pantalla_perfil.dart` con el cambio de
/// contraseña y `pantalla_inicio.dart` con el reenvío de verificación. Mientras
/// este flujo corre, la app sigue siendo invitada para todo lo demás, así que
/// no hay forma de caer en una pantalla que pida autenticación: el estado que
/// las habilita nunca cambia.
///
/// **El éxito no confirma que el correo exista.** El backend contesta lo mismo
/// para una cuenta real, una inexistente y una dada de baja, así que acá se
/// muestra su mensaje tal cual. Decir "te enviamos el correo" en un caso y
/// "ese correo no existe" en otro convertiría la pantalla en un verificador de
/// clientes de PowerTech.
class PantallaRecuperarPassword extends ConsumerStatefulWidget {
  const PantallaRecuperarPassword({super.key, this.emailInicial});

  /// Lo que el cliente ya había escrito en el login, para no hacerlo tipear
  /// dos veces.
  final String? emailInicial;

  @override
  ConsumerState<PantallaRecuperarPassword> createState() =>
      _PantallaRecuperarPasswordState();
}

class _PantallaRecuperarPasswordState
    extends ConsumerState<PantallaRecuperarPassword> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _email;

  bool _enviando = false;

  /// Mensaje genérico del backend, ya enviada la solicitud. Cuando tiene
  /// texto, la pantalla pasa al estado "revisá tu correo".
  String? _enviado;

  Map<String, String> _erroresCampo = {};
  ErrorApi? _errorGeneral;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.emailInicial ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erroresCampo = {};
      _errorGeneral = null;
    });

    try {
      final mensaje = await ref
          .read(authRepositoryProvider)
          .solicitarEnlaceDeRecuperacion(email: _email.text);

      if (mounted) setState(() => _enviado = mensaje);
    } on ErrorValidacion catch (e) {
      setState(() {
        _erroresCampo = {
          for (final campo in e.errores.keys)
            if (e.primeroDe(campo) != null) campo: e.primeroDe(campo)!,
        };
      });
    } on ErrorApi catch (e) {
      setState(() => _errorGeneral = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Abre el paso 2. Si vuelve con un correo, la contraseña se cambió: esta
  /// pantalla se cierra pasándoselo al login, que lo precarga y avisa.
  ///
  /// El dato viaja de vuelta en lugar de hacer `popUntil(isFirst)` porque
  /// `isFirst` es la vitrina, no el login: saltaría dos pantallas y dejaría al
  /// cliente con la contraseña nueva y sin dónde escribirla.
  Future<void> _irAlPaso2() async {
    final correoCambiado = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => PantallaRestablecerPassword(
          emailInicial: _email.text.trim().isEmpty ? null : _email.text.trim(),
        ),
      ),
    );

    if (correoCambiado != null && mounted) {
      Navigator.of(context).pop(correoCambiado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Recuperar contraseña',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF202B3C),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202B3C),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                ),
                child: _enviado == null ? _formularioPedido() : _yaEnviado(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Estado inicial: pedir el correo
  // ------------------------------------------------------------------

  Widget _formularioPedido() {
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset,
            size: 46,
            color: Color(0xFF2563EB),
          ),

          const SizedBox(height: 16),

          const Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Color(0xFF202B3C),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Escribí el correo con el que ingresás y te enviamos un enlace '
            'para elegir una contraseña nueva.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 28),

          if (_errorGeneral != null) ...[
            AvisoError(
              error: _errorGeneral!,
              onReintentar: _enviando ? null : _solicitar,
            ),
            const SizedBox(height: 16),
          ],

          CampoFormulario(
            controlador: _email,
            etiqueta: 'Correo electrónico',
            obligatorio: true,
            habilitado: !_enviando,
            tipoTeclado: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
            accionTeclado: TextInputAction.done,
            onEnviar: _enviando ? null : _solicitar,
            errorServidor: _erroresCampo['email'],
            onCambio: (_) {
              if (_erroresCampo.containsKey('email')) {
                setState(() => _erroresCampo = {..._erroresCampo}..remove('email'));
              }
            },
          ),

          const SizedBox(height: 10),

          _botonPrincipal(
            texto: 'Enviar enlace',
            onPressed: _enviando ? null : _solicitar,
            cargando: _enviando,
          ),

          const SizedBox(height: 12),

          // Atajo para quien ya recibió el correo antes de abrir esta
          // pantalla: no tiene por qué pedir un enlace nuevo para usar el que
          // ya tiene.
          TextButton(
            onPressed: _enviando ? null : _irAlPaso2,
            style: _estiloEnlace(),
            child: const Text('Ya tengo el enlace del correo'),
          ),

          TextButton(
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            style: _estiloEnlace(secundario: true),
            child: const Text('Volver a ingresar'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Estado final: solicitud enviada
  // ------------------------------------------------------------------

  Widget _yaEnviado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 46,
          color: Color(0xFF16A34A),
        ),

        const SizedBox(height: 16),

        const Text(
          'Revisá tu correo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: Color(0xFF202B3C),
          ),
        ),

        const SizedBox(height: 8),

        // El texto del backend, sin reinterpretar: es el mismo para un correo
        // registrado y para uno que no lo está.
        Text(
          _enviado!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 20),

        const AvisoInformativo(
          titulo: 'Dos formas de continuar',
          detalle: 'Tocá el enlace del correo para elegir la contraseña nueva '
              'en el navegador, o copialo y pegalo acá para hacerlo dentro de '
              'la app. El enlace vence en 1 hora y sirve una sola vez.',
          icono: Icons.alt_route,
        ),

        _botonPrincipal(
          texto: 'Pegar el enlace y continuar',
          onPressed: _irAlPaso2,
          cargando: false,
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: _enviando
              ? null
              : () => setState(() {
                    _enviado = null;
                    _errorGeneral = null;
                  }),
          style: _estiloEnlace(),
          child: const Text('No me llegó, probar con otro correo'),
        ),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: _estiloEnlace(secundario: true),
          child: const Text('Volver a ingresar'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Piezas visuales compartidas con el login
  // ------------------------------------------------------------------

  Widget _botonPrincipal({
    required String texto,
    required VoidCallback? onPressed,
    required bool cargando,
  }) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF93B4F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: cargando
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(texto),
      ),
    );
  }

  ButtonStyle _estiloEnlace({bool secundario = false}) {
    return TextButton.styleFrom(
      foregroundColor:
          secundario ? const Color(0xFF64748B) : const Color(0xFF2563EB),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}
