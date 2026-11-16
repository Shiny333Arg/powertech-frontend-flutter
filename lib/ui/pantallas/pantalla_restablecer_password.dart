import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../estado/proveedores_core.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';

/// Paso 2 de "olvidé mi contraseña": escribir la contraseña nueva.
///
/// Equivalente de `auth/reset-password.blade.php`, con una diferencia que no
/// se puede evitar: la web recibe el token en la URL porque el navegador abrió
/// el enlace, y la app no abre ese enlace. Acá el token lo trae el cliente,
/// pegando el enlace que le llegó por correo.
///
/// **Por qué el enlace se pega y no se intercepta.** El correo de recuperación
/// es uno solo y lo comparten clientes y empleados: la notificación apunta a la
/// ruta web `password.reset` y los empleados no tienen app. Cambiar ese enlace
/// por un esquema propio (`powertech://...`) habría obligado a tocar el
/// mecanismo que ya funciona en Blade, que es justo lo que no se quería mover.
/// Queda la puerta abierta: el día que se registre un App Link para
/// `/reset-password/{token}`, esta misma pantalla recibe `tokenInicial` y
/// `emailInicial` ya resueltos y el formulario no cambia.
///
/// Mientras tanto hay dos caminos y los dos terminan bien: tocar el enlace y
/// resolverlo en el navegador —que es lo que ya pasaba—, o pegarlo acá y
/// resolverlo adentro de la app.
///
/// **El token no es una credencial de sesión.** No se guarda en
/// `AlmacenSeguro`, vence en 1 hora, sirve una sola vez y no autentica ninguna
/// otra llamada. Esta pantalla tampoco inicia sesión al terminar: devuelve el
/// correo al login para que el cliente entre escribiendo la contraseña nueva,
/// que es lo que hace la web al redirigir a `login`.
class PantallaRestablecerPassword extends ConsumerStatefulWidget {
  const PantallaRestablecerPassword({
    super.key,
    this.emailInicial,
    this.tokenInicial,
  });

  final String? emailInicial;

  /// Previsto para un App Link futuro. Hoy siempre llega null y el cliente
  /// pega el enlace a mano.
  final String? tokenInicial;

  @override
  ConsumerState<PantallaRestablecerPassword> createState() =>
      _PantallaRestablecerPasswordState();
}

class _PantallaRestablecerPasswordState
    extends ConsumerState<PantallaRestablecerPassword> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _enlace;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _repetir = TextEditingController();

  bool _enviando = false;
  bool _mostrarPassword = false;
  bool _mostrarRepetir = false;

  /// Con texto, la contraseña ya se cambió y la pantalla muestra el final.
  String? _listo;

  Map<String, String> _erroresCampo = {};
  ErrorApi? _errorGeneral;

  @override
  void initState() {
    super.initState();
    _enlace = TextEditingController(text: widget.tokenInicial ?? '');
    _email = TextEditingController(text: widget.emailInicial ?? '');
  }

  @override
  void dispose() {
    _enlace.dispose();
    _email.dispose();
    _password.dispose();
    _repetir.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Envío
  // ------------------------------------------------------------------

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    final leido = interpretarEnlaceDeRecuperacion(_enlace.text);

    // El correo del enlace manda sobre el tipeado: el token está emitido para
    // ese correo y no para otro. Se escribe en el campo —en lugar de usarlo
    // callado— para que el cliente vea con qué cuenta se está cambiando la
    // contraseña, y para que un error de "enlace inválido" no sea un misterio.
    if (leido.email != null && leido.email != _email.text.trim()) {
      _email.text = leido.email!;
    }

    final errores = _validacionLocal(token: leido.token);

    if (errores.isNotEmpty) {
      setState(() => _erroresCampo = errores);
      return;
    }

    setState(() {
      _enviando = true;
      _erroresCampo = {};
      _errorGeneral = null;
    });

    try {
      final mensaje = await ref.read(authRepositoryProvider).restablecerPassword(
            token: leido.token,
            email: _email.text,
            password: _password.text,
            passwordConfirmation: _repetir.text,
          );

      if (mounted) setState(() => _listo = mensaje);
    } on ErrorValidacion catch (e) {
      // El enlace vencido, el ya usado, el equivocado y el correo inexistente
      // llegan todos acá, sobre el campo `email` y con el mismo texto: el
      // backend los mantiene indistinguibles a propósito. Por eso la pantalla
      // deja siempre a mano el botón para pedir un enlace nuevo, que es el
      // equivalente del "Pedí un enlace nuevo." de reset-password.blade.php.
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

  /// Lo que se puede comprobar sin gastar el token.
  ///
  /// **No reemplaza la validación del backend, la adelanta.** Las reglas de
  /// verdad son las de `NuevaPasswordMovilRequest` (`Password::defaults()` y
  /// `confirmed`); estas dos son las mismas, acá, para no quemar un enlace de
  /// un solo uso por un error de tipeo. Si el backend endurece la política, el
  /// 422 sigue llegando y se muestra debajo del campo.
  Map<String, String> _validacionLocal({required String token}) {
    final errores = <String, String>{};

    if (token.isEmpty) {
      errores['token'] = 'Pegá el enlace que te llegó por correo.';
    }

    if (_password.text.length < 8) {
      errores['password'] = 'La contraseña necesita al menos 8 caracteres.';
    } else if (_password.text != _repetir.text) {
      errores['password_confirmation'] = 'Las dos contraseñas no coinciden.';
    }

    return errores;
  }

  void _limpiarError(String campo) {
    if (!_erroresCampo.containsKey(campo)) return;

    setState(() => _erroresCampo = {..._erroresCampo}..remove(campo));
  }

  // ------------------------------------------------------------------
  // Pantalla
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Nueva contraseña',
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
                child: _listo == null ? _formularioNueva() : _yaCambiada(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formularioNueva() {
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Elegí tu nueva contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Color(0xFF202B3C),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Pegá el enlace que te llegó por correo y escribí la contraseña '
            'que vas a usar de ahora en más.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 24),

          if (_errorGeneral != null) ...[
            AvisoError(
              error: _errorGeneral!,
              onReintentar: _enviando ? null : _guardar,
            ),
            const SizedBox(height: 16),
          ],

          CampoFormulario(
            controlador: _enlace,
            etiqueta: 'Enlace del correo',
            obligatorio: true,
            habilitado: !_enviando,
            tipoTeclado: TextInputType.url,
            accionTeclado: TextInputAction.next,
            ayuda: 'Mantené presionado el enlace del correo, copialo y pegalo acá.',
            errorServidor: _erroresCampo['token'],
            onCambio: (valor) {
              _limpiarError('token');

              // Cortesía: si el enlace trae el correo y el campo está vacío,
              // se completa solo. No sobreescribe lo que el cliente ya
              // escribió; eso recién pasa al enviar, y por el motivo que está
              // explicado en `_guardar`.
              final leido = interpretarEnlaceDeRecuperacion(valor);

              if (leido.email != null && _email.text.trim().isEmpty) {
                _email.text = leido.email!;
              }
            },
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
            etiqueta: 'Nueva contraseña',
            obligatorio: true,
            esPassword: !_mostrarPassword,
            habilitado: !_enviando,
            autofill: const [AutofillHints.newPassword],
            accionTeclado: TextInputAction.next,
            ayuda: 'Al menos 8 caracteres.',
            errorServidor: _erroresCampo['password'],
            onCambio: (_) => _limpiarError('password'),
            sufijo: _ojo(
              visible: _mostrarPassword,
              onPressed: _enviando
                  ? null
                  : () => setState(() => _mostrarPassword = !_mostrarPassword),
            ),
          ),

          CampoFormulario(
            controlador: _repetir,
            etiqueta: 'Repetí la nueva contraseña',
            obligatorio: true,
            esPassword: !_mostrarRepetir,
            habilitado: !_enviando,
            autofill: const [AutofillHints.newPassword],
            accionTeclado: TextInputAction.done,
            onEnviar: _enviando ? null : _guardar,
            errorServidor: _erroresCampo['password_confirmation'],
            onCambio: (_) => _limpiarError('password_confirmation'),
            sufijo: _ojo(
              visible: _mostrarRepetir,
              onPressed: _enviando
                  ? null
                  : () => setState(() => _mostrarRepetir = !_mostrarRepetir),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _enviando ? null : _guardar,
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
              child: _enviando
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar contraseña'),
            ),
          ),

          const SizedBox(height: 12),

          // Siempre visible, no sólo cuando falla: el enlace vence en 1 hora y
          // sirve una sola vez, así que "pedir uno nuevo" es la salida normal
          // de esta pantalla y no un caso de error.
          TextButton(
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Pedir un enlace nuevo'),
          ),
        ],
      ),
    );
  }

  /// Final del circuito. El botón devuelve el correo al login, que lo precarga.
  Widget _yaCambiada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 46,
          color: Color(0xFF16A34A),
        ),

        const SizedBox(height: 16),

        const Text(
          'Contraseña actualizada',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: Color(0xFF202B3C),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _listo!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_email.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Ir a ingresar'),
          ),
        ),
      ],
    );
  }

  Widget _ojo({required bool visible, required VoidCallback? onPressed}) {
    return IconButton(
      tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
      onPressed: onPressed,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: const Color(0xFF64748B),
        size: 21,
      ),
    );
  }
}

// ====================================================================
// Lectura del enlace
// ====================================================================

/// Saca el token y el correo de lo que el cliente pegó.
///
/// El enlace que manda Laravel tiene esta forma:
///
///     https://host/reset-password/TOKEN?email=cliente%40ejemplo.com
///
/// La función acepta eso, acepta el enlace rodeado de texto —los clientes de
/// correo pegan de todo alrededor— y acepta el token solo, por si alguien lo
/// copia a mano. Lo que no hace es validar: si el token sirve o no lo decide el
/// broker de Laravel, que es el único que puede, porque del lado del servidor
/// está guardado hasheado.
///
/// Es una función de nivel superior y no un método privado para que se pueda
/// probar sin levantar un widget.
({String token, String? email}) interpretarEnlaceDeRecuperacion(String crudo) {
  final texto = crudo.trim();

  if (texto.isEmpty) return (token: '', email: null);

  // Un enlace embebido en el cuerpo del correo. La clase de caracteres se
  // corta en los signos con los que los clientes de correo suelen envolverlo.
  final encontrado = RegExp(r'https?://[^\s<>"\]]+').firstMatch(texto);

  final candidato = encontrado?.group(0) ?? texto;

  // Puntuación que queda pegada al final al copiar de un párrafo.
  final limpio = candidato.replaceAll(RegExp(r'[.,;:)\]]+$'), '');

  final uri = Uri.tryParse(limpio);

  if (uri == null || !uri.hasScheme || uri.pathSegments.isEmpty) {
    // No era una URL: se toma tal cual, que es el caso del token copiado solo.
    return (token: texto, email: null);
  }

  final segmentos = uri.pathSegments;
  final indice = segmentos.indexOf('reset-password');

  // Con el segmento `reset-password` presente, el token es el que sigue. Sin
  // él, el último segmento es la mejor apuesta: cubre un enlace acortado o una
  // ruta que cambió de nombre, y si está mal, el backend lo rechaza igual.
  final token = (indice >= 0 && indice + 1 < segmentos.length)
      ? segmentos[indice + 1]
      : segmentos.last;

  final email = uri.queryParameters['email']?.trim();

  return (
    token: token.trim(),
    email: (email == null || email.isEmpty) ? null : email.toLowerCase(),
  );
}
