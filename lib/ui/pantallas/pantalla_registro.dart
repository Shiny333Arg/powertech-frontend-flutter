import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/codigos_afip.dart';
import '../../core/errores.dart';
import '../../datos/modelos/opcion_fiscal.dart';
import '../../estado/datos_fiscales_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';

/// Alta de un cliente desde la app.
///
/// Los nombres de los campos son los de `RegistroClienteRequest`, que el
/// backend reutiliza tal cual del registro web: por eso las claves del 422
/// coinciden una a una con los controladores de abajo.
///
/// Las dos listas fiscales se piden a `/datos-fiscales`. **Ningun id esta
/// escrito en la app**: lo unico que viaja en el codigo son los codigos de
/// ARCA de [CodigosAfip], y solo para elegir el teclado y adelantar un
/// aviso. Quien valida es Laravel.
class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final _formulario = GlobalKey<FormState>();

  final _nombres = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmacion = TextEditingController();
  final _nroDoc = TextEditingController();
  final _razonSocial = TextEditingController();
  final _telefono = TextEditingController();

  OpcionFiscal? _tipoDocumento;
  OpcionFiscal? _condicionIva;

  bool _enviando = false;
  Map<String, String> _erroresCampo = {};
  ErrorApi? _errorGeneral;

  @override
  void dispose() {
    _nombres.dispose();
    _apellido.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirmacion.dispose();
    _nroDoc.dispose();
    _razonSocial.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erroresCampo = {};
      _errorGeneral = null;
    });

    try {
      await ref.read(sesionProvider.notifier).registrar(
            nombres: _nombres.text,
            apellido: _apellido.text,
            email: _email.text,
            password: _password.text,
            passwordConfirmation: _passwordConfirmacion.text,
            tipoDocumentoId: _tipoDocumento!.id,
            nroDoc: _nroDoc.text,
            condicionIvaId: _condicionIva!.id,
            razonSocial: _razonSocial.text,
            telefono: _telefono.text,
          );

      // Esta pantalla esta apilada sobre el login, que a su vez esta apilado
      // sobre la vitrina. Un `pop` suelto dejaria al cliente recien
      // registrado mirando el formulario de login: hay que volver hasta la
      // vitrina, que desde el paso 3 es la primera ruta.
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
      _irAlPrimerError();
    } on ErrorApi catch (e) {
      setState(() => _errorGeneral = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// El formulario es largo: si el error cayo arriba y el usuario esta abajo,
  /// no lo ve. Se sube al principio, donde esta el resumen.
  void _irAlPrimerError() {
    if (!mounted || _erroresCampo.isEmpty) return;
    Scrollable.ensureVisible(
      _formulario.currentContext!,
      duration: const Duration(milliseconds: 250),
      alignment: 0,
    );
  }

  void _limpiarError(String campo) {
    if (!_erroresCampo.containsKey(campo)) return;
    setState(() => _erroresCampo = {..._erroresCampo}..remove(campo));
  }

  @override
  Widget build(BuildContext context) {
    final fiscales = ref.watch(datosFiscalesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: fiscales.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _FallaDatosFiscales(
            error: e,
            onReintentar: () => ref.invalidate(datosFiscalesProvider),
          ),
          data: _formularioCompleto,
        ),
      ),
    );
  }

  Widget _formularioCompleto(DatosFiscales fiscales) {
    final codigoDoc = _tipoDocumento?.codigoAfip;

    final avisoFiscal = CodigosAfip.avisoCoherenciaFiscal(
      codigoDocumento: codigoDoc,
      codigoIva: _condicionIva?.codigoAfip,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorGeneral != null) AvisoError(error: _errorGeneral!),

                if (_erroresCampo.isNotEmpty)
                  AvisoInformativo(
                    titulo: 'Revisá los campos marcados',
                    detalle: 'El servidor rechazó ${_erroresCampo.length} '
                        '${_erroresCampo.length == 1 ? "campo" : "campos"}. '
                        'El detalle está debajo de cada uno.',
                    icono: Icons.edit_note,
                  ),

                const _Titulo('Tus datos'),

                CampoFormulario(
                  controlador: _nombres,
                  etiqueta: 'Nombres',
                  obligatorio: true,
                  habilitado: !_enviando,
                  autofill: const [AutofillHints.givenName],
                  accionTeclado: TextInputAction.next,
                  errorServidor: _erroresCampo['nombres'],
                  onCambio: (_) => _limpiarError('nombres'),
                ),

                CampoFormulario(
                  controlador: _apellido,
                  etiqueta: 'Apellido',
                  obligatorio: true,
                  habilitado: !_enviando,
                  autofill: const [AutofillHints.familyName],
                  accionTeclado: TextInputAction.next,
                  errorServidor: _erroresCampo['apellido'],
                  onCambio: (_) => _limpiarError('apellido'),
                ),

                CampoFormulario(
                  controlador: _email,
                  etiqueta: 'Correo electrónico',
                  obligatorio: true,
                  habilitado: !_enviando,
                  tipoTeclado: TextInputType.emailAddress,
                  autofill: const [AutofillHints.email],
                  accionTeclado: TextInputAction.next,
                  ayuda: 'Te vamos a mandar un correo para verificarlo.',
                  errorServidor: _erroresCampo['email'],
                  onCambio: (_) => _limpiarError('email'),
                ),

                CampoFormulario(
                  controlador: _telefono,
                  etiqueta: 'Teléfono (opcional)',
                  habilitado: !_enviando,
                  tipoTeclado: TextInputType.phone,
                  largoMaximo: 30,
                  accionTeclado: TextInputAction.next,
                  errorServidor: _erroresCampo['telefono'],
                  onCambio: (_) => _limpiarError('telefono'),
                ),

                const SizedBox(height: 8),
                const _Titulo('Contraseña'),

                CampoFormulario(
                  controlador: _password,
                  etiqueta: 'Contraseña',
                  obligatorio: true,
                  esPassword: true,
                  habilitado: !_enviando,
                  autofill: const [AutofillHints.newPassword],
                  accionTeclado: TextInputAction.next,
                  // El largo minimo y las reglas las pone Password::defaults()
                  // en Laravel. No se replican aca para no quedar
                  // desincronizadas si alla cambian.
                  errorServidor: _erroresCampo['password'],
                  onCambio: (_) => _limpiarError('password'),
                ),

                CampoFormulario(
                  controlador: _passwordConfirmacion,
                  etiqueta: 'Repetir contraseña',
                  obligatorio: true,
                  esPassword: true,
                  habilitado: !_enviando,
                  accionTeclado: TextInputAction.next,
                  // La regla 'confirmed' cuelga el error de 'password', no de
                  // 'password_confirmation'. Se muestra en los dos para que
                  // se vea al lado del campo que hay que corregir.
                  errorServidor: _erroresCampo['password_confirmation'],
                  onCambio: (_) => _limpiarError('password_confirmation'),
                ),

                const SizedBox(height: 8),
                const _Titulo('Datos para facturarte'),

                CampoDesplegable<OpcionFiscal>(
                  valor: _condicionIva,
                  opciones: fiscales.condicionesIva,
                  etiqueta: 'Condición frente al IVA',
                  textoDe: (o) => o.nombre,
                  habilitado: !_enviando,
                  errorServidor: _erroresCampo['condicion_iva_id'],
                  onCambio: (valor) {
                    setState(() => _condicionIva = valor);
                    _limpiarError('condicion_iva_id');
                  },
                ),

                CampoDesplegable<OpcionFiscal>(
                  valor: _tipoDocumento,
                  opciones: fiscales.tiposDocumento,
                  etiqueta: 'Tipo de documento',
                  textoDe: (o) => o.nombre,
                  habilitado: !_enviando,
                  errorServidor: _erroresCampo['tipo_documento_id'],
                  onCambio: (valor) {
                    setState(() {
                      _tipoDocumento = valor;
                      // Cambiar de DNI a CUIT cambia el largo esperado: lo
                      // que estaba escrito ya no sirve.
                      _nroDoc.clear();
                    });
                    _limpiarError('tipo_documento_id');
                    _limpiarError('nro_doc');
                  },
                ),

                if (avisoFiscal != null)
                  AvisoInformativo(
                    titulo: 'Revisá el tipo de documento',
                    detalle: avisoFiscal,
                    icono: Icons.receipt_long,
                  ),

                CampoFormulario(
                  controlador: _nroDoc,
                  etiqueta: 'Número de documento',
                  obligatorio: true,
                  habilitado: !_enviando && _tipoDocumento != null,
                  soloDigitos: true,
                  tipoTeclado: TextInputType.number,
                  largoMaximo: CodigosAfip.largoMaximo(codigoDoc),
                  ayuda: _tipoDocumento == null
                      ? 'Elegí primero el tipo de documento.'
                      : CodigosAfip.ayudaDocumento(codigoDoc),
                  accionTeclado: TextInputAction.next,
                  errorServidor: _erroresCampo['nro_doc'],
                  onCambio: (_) => _limpiarError('nro_doc'),
                ),

                CampoFormulario(
                  controlador: _razonSocial,
                  etiqueta: 'Razón social (opcional)',
                  habilitado: !_enviando,
                  largoMaximo: 150,
                  ayuda: 'Si la dejás vacía usamos tu apellido y nombres.',
                  accionTeclado: TextInputAction.done,
                  onEnviar: _enviando ? null : _registrar,
                  errorServidor: _erroresCampo['razon_social'],
                  onCambio: (_) => _limpiarError('razon_social'),
                ),

                const SizedBox(height: 8),

                FilledButton(
                  onPressed: _enviando ? null : _registrar,
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear cuenta'),
                ),

                const SizedBox(height: 12),

                Text(
                  'Vas a poder navegar el catálogo enseguida. Para comprar, '
                  'primero tenés que verificar tu correo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Sin las listas fiscales el formulario no se puede armar: los dos
/// desplegables quedarian vacios y el registro fallaria con un 422 que el
/// usuario no puede corregir. Por eso se corta aca en lugar de mostrar el
/// formulario a medias.
class _FallaDatosFiscales extends StatelessWidget {
  const _FallaDatosFiscales({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error is ErrorApi)
            AvisoError(error: error as ErrorApi, onReintentar: onReintentar)
          else
            Text('$error'),
          const SizedBox(height: 8),
          const Text(
            'No pudimos cargar los tipos de documento y las condiciones de '
            'IVA, así que no se puede completar el registro. Probá de nuevo '
            'en un momento.',
          ),
        ],
      ),
    );
  }
}
