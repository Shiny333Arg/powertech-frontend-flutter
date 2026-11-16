
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';
import 'pantalla_registro.dart';

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _enviando = false;
  bool _mostrarPassword = false;

  // Errores por campo que devolvió Laravel en el último intento.
  Map<String, String> _erroresCampo = {};

  // Error general (red, 429, 500).
  ErrorApi? _errorGeneral;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erroresCampo = {};
      _errorGeneral = null;
    });

    try {
      await ref.read(sesionProvider.notifier).iniciarSesion(
        email: _email.text,
        password: _password.text,
      );

      if (mounted) {
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      }
    } on ErrorValidacion catch (e) {
      setState(() {
        _erroresCampo = {
          for (final campo in e.errores.keys)
            if (e.primeroDe(campo) != null)
              campo: e.primeroDe(campo)!,
        };
      });
    } on ErrorApi catch (e) {
      setState(() => _errorGeneral = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // Al corregir un campo se borra su error del servidor.
  void _limpiarError(String campo) {
    if (!_erroresCampo.containsKey(campo)) return;

    setState(() => _erroresCampo = {..._erroresCampo}..remove(campo));
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(sesionProvider);
    final aviso = estado is SesionInvitado ? estado.aviso : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Ingresar',
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
                  border: Border.all(
                    color: const Color(0xFFE8EDF3),
                  ),
                ),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Identidad de PowerTech.
                      Center(
                        child: Image.asset(
                          'assets/images/Logo_Primary.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Bienvenido de nuevo',
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
                        'Ingresá a tu cuenta para ver precios y realizar tus compras.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Aviso de expulsión o sesión vencida.
                      if (aviso != null) ...[
                        AvisoInformativo(
                          titulo: 'Volvé a ingresar',
                          detalle: aviso,
                          icono: Icons.lock_clock,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error general de la API.
                      if (_errorGeneral != null) ...[
                        AvisoError(
                          error: _errorGeneral!,
                          onReintentar: _enviando ? null : _ingresar,
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
                        accionTeclado: TextInputAction.next,
                        errorServidor: _erroresCampo['email'],
                        onCambio: (_) => _limpiarError('email'),
                      ),

                      const SizedBox(height: 16),

                      // Contraseña con botón para mostrar u ocultar.
                      CampoFormulario(
                        controlador: _password,
                        etiqueta: 'Contraseña',
                        obligatorio: true,
                        esPassword: !_mostrarPassword,
                        habilitado: !_enviando,
                        autofill: const [AutofillHints.password],
                        accionTeclado: TextInputAction.done,
                        onEnviar: _enviando ? null : _ingresar,
                        errorServidor: _erroresCampo['password'],
                        onCambio: (_) => _limpiarError('password'),
                        sufijo: IconButton(
                          tooltip: _mostrarPassword
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          onPressed: _enviando
                              ? null
                              : () {
                            setState(() {
                              _mostrarPassword = !_mostrarPassword;
                            });
                          },
                          icon: Icon(
                            _mostrarPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 21,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _enviando ? null : _ingresar,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                            const Color(0xFF93B4F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _enviando
                              ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Ingresar'),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: const [
                          Expanded(
                            child: Divider(color: Color(0xFFE8EDF3)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '¿Sos nuevo en PowerTech?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: Color(0xFFE8EDF3)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _enviando
                            ? null
                            : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                            const PantallaRegistro(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Crear una cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
