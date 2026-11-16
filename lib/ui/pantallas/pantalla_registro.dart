
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/codigos_afip.dart';
import '../../core/errores.dart';
import '../../datos/modelos/opcion_fiscal.dart';
import '../../estado/datos_fiscales_providers.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';

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
  bool _mostrarPassword = false;
  bool _mostrarPasswordConfirmacion = false;

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
      _irAlPrimerError();
    } on ErrorApi catch (e) {
      setState(() => _errorGeneral = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF202B3C),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202B3C),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: fiscales.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
                  // Encabezado.
                  Center(
                    child: Image.asset(
                      'assets/images/Logo_Primary.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Creá tu cuenta',
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
                    'Completá tus datos para empezar a disfrutar de PowerTech.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Errores generales.
                  if (_errorGeneral != null) ...[
                    AvisoError(error: _errorGeneral!),
                    const SizedBox(height: 16),
                  ],

                  if (_erroresCampo.isNotEmpty) ...[
                    AvisoInformativo(
                      titulo: 'Revisá los campos marcados',
                      detalle: 'El servidor rechazó ${_erroresCampo.length} '
                          '${_erroresCampo.length == 1 ? "campo" : "campos"}. '
                          'El detalle está debajo de cada uno.',
                      icono: Icons.edit_note,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Datos personales.
                  const _TituloSeccion(
                    titulo: 'Datos personales',
                    subtitulo: 'Contanos un poco sobre vos.',
                    icono: Icons.person_outline_rounded,
                  ),

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

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 28),

                  // Contraseña.
                  const _TituloSeccion(
                    titulo: 'Seguridad',
                    subtitulo: 'Elegí una contraseña para proteger tu cuenta.',
                    icono: Icons.lock_outline_rounded,
                  ),

                  CampoFormulario(
                    controlador: _password,
                    etiqueta: 'Contraseña',
                    obligatorio: true,
                    esPassword: !_mostrarPassword,
                    habilitado: !_enviando,
                    autofill: const [AutofillHints.newPassword],
                    accionTeclado: TextInputAction.next,
                    errorServidor: _erroresCampo['password'],
                    onCambio: (_) => _limpiarError('password'),
                    sufijo: IconButton(
                      tooltip: _mostrarPassword
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      icon: Icon(
                        _mostrarPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _enviando
                          ? null
                          : () {
                        setState(() {
                          _mostrarPassword = !_mostrarPassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  CampoFormulario(
                    controlador: _passwordConfirmacion,
                    etiqueta: 'Repetir contraseña',
                    obligatorio: true,
                    esPassword: !_mostrarPasswordConfirmacion,
                    habilitado: !_enviando,
                    accionTeclado: TextInputAction.next,
                    errorServidor: _erroresCampo['password_confirmation'],
                    onCambio: (_) =>
                        _limpiarError('password_confirmation'),
                    sufijo: IconButton(
                      tooltip: _mostrarPasswordConfirmacion
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      icon: Icon(
                        _mostrarPasswordConfirmacion
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _enviando
                          ? null
                          : () {
                        setState(() {
                          _mostrarPasswordConfirmacion =
                          !_mostrarPasswordConfirmacion;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Datos fiscales.
                  const _TituloSeccion(
                    titulo: 'Datos de facturación',
                    subtitulo: 'Necesitamos estos datos para tus comprobantes.',
                    icono: Icons.receipt_long_outlined,
                  ),

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

                  const SizedBox(height: 14),

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
                        _nroDoc.clear();
                      });
                      _limpiarError('tipo_documento_id');
                      _limpiarError('nro_doc');
                    },
                  ),

                  if (avisoFiscal != null) ...[
                    const SizedBox(height: 12),
                    AvisoInformativo(
                      titulo: 'Revisá el tipo de documento',
                      detalle: avisoFiscal,
                      icono: Icons.info_outline_rounded,
                    ),
                  ],

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 28),

                  // Acción principal.
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _enviando ? null : _registrar,
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
                          : const Text('Crear cuenta'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Vas a poder navegar el catálogo enseguida. '
                        'Para comprar, primero tenés que verificar tu correo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icono,
              color: const Color(0xFF2563EB),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64748B),
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

/// Si no se cargan las listas fiscales, el registro no puede completarse.
class _FallaDatosFiscales extends StatelessWidget {
  const _FallaDatosFiscales({
    required this.error,
    required this.onReintentar,
  });

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE8EDF3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pudimos preparar el registro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(height: 12),
                if (error is ErrorApi)
                  AvisoError(
                    error: error as ErrorApi,
                    onReintentar: onReintentar,
                  )
                else
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                const Text(
                  'No pudimos cargar los tipos de documento y las '
                      'condiciones de IVA, así que no se puede completar '
                      'el registro. Probá de nuevo en un momento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: onReintentar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
