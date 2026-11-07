import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';
import 'pantalla_diagnostico.dart';
import 'pantalla_registro.dart';

/// Ingreso con correo y contraseña.
///
/// **Los cuatro rechazos del backend llegan igual: 422 sobre `email`.**
/// Credencial incorrecta, cuenta de baja, cinco intentos fallidos y cuenta de
/// gestion comparten forma y solo cambian de texto. La pantalla no los
/// distingue ni lo intenta: muestra el mensaje que escribio Laravel debajo
/// del campo. Para el caso de la cuenta de gestion ese mensaje ya dice que
/// hay que ingresar desde el sitio web.
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

  /// Errores por campo que devolvio Laravel en el ultimo intento.
  Map<String, String> _erroresCampo = {};

  /// Error general (red, 429, 500). Los de validacion no entran aca.
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

      // Desde el paso 3 la vitrina es la primera ruta de la pila y el login
      // se apila encima, asi que hay que sacarlo: antes alcanzaba con que el
      // widget raiz cambiara de pantalla. `popUntil` y no `pop` porque esto
      // tambien corre cuando el login quedo debajo del registro.
      if (mounted) {
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      }
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

  /// Al corregir un campo se borra su error del servidor: dejarlo pegado
  /// mientras se escribe la correccion no ayuda a nadie.
  void _limpiarError(String campo) {
    if (!_erroresCampo.containsKey(campo)) return;
    setState(() => _erroresCampo = {..._erroresCampo}..remove(campo));
  }

  @override
  Widget build(BuildContext context) {
    // Aviso de expulsion: "tu sesion vencio", o el motivo del 403.
    final estado = ref.watch(sesionProvider);
    final aviso = estado is SesionInvitado ? estado.aviso : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresar'),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'PowerTech',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ingresá para ver precios y comprar.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    if (aviso != null)
                      AvisoInformativo(
                        titulo: 'Volvé a ingresar',
                        detalle: aviso,
                        icono: Icons.lock_clock,
                      ),

                    if (_errorGeneral != null)
                      AvisoError(
                        error: _errorGeneral!,
                        onReintentar: _enviando ? null : _ingresar,
                      ),

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

                    CampoFormulario(
                      controlador: _password,
                      etiqueta: 'Contraseña',
                      obligatorio: true,
                      esPassword: true,
                      habilitado: !_enviando,
                      autofill: const [AutofillHints.password],
                      accionTeclado: TextInputAction.done,
                      onEnviar: _enviando ? null : _ingresar,
                      errorServidor: _erroresCampo['password'],
                      onCambio: (_) => _limpiarError('password'),
                    ),

                    const SizedBox(height: 8),

                    FilledButton(
                      onPressed: _enviando ? null : _ingresar,
                      child: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Ingresar'),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _enviando
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PantallaRegistro(),
                                ),
                              ),
                      child: const Text('No tengo cuenta, quiero registrarme'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
