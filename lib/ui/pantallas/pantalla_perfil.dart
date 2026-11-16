
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/codigos_afip.dart';
import '../../core/errores.dart';
import '../../datos/modelos/opcion_fiscal.dart';
import '../../datos/modelos/perfil.dart';
import '../../estado/datos_fiscales_providers.dart';
import '../../estado/perfil_providers.dart';
import '../../estado/proveedores_core.dart';
import '../../estado/sesion_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/campo_formulario.dart';

/// Edición de los datos del cliente: GET y PATCH /api/v1/perfil.
class PantallaPerfil extends ConsumerWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider);
    final fiscales = ref.watch(datosFiscalesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          'Mis datos',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
            color: Color(0xFF202B3C),
          ),
        ),
      ),
      body: SafeArea(child: _cuerpo(ref, perfil, fiscales)),
    );
  }

  Widget _cuerpo(
      WidgetRef ref,
      AsyncValue<Perfil> perfil,
      AsyncValue<DatosFiscales> fiscales,
      ) {
    final datos = perfil.value;
    final listas = fiscales.value;

    if (datos == null || listas == null) {
      final error = perfil.error ?? fiscales.error;

      if (error != null) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          children: [
            AvisoError(
              error: error is ErrorApi
                  ? error
                  : ErrorFormato('Error inesperado: $error'),
              onReintentar: () {
                ref.invalidate(perfilProvider);
                ref.invalidate(datosFiscalesProvider);
              },
            ),
          ],
        );
      }

      return const Center(child: CircularProgressIndicator());
    }

    return _Contenido(perfil: datos, fiscales: listas);
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.perfil, required this.fiscales});

  final Perfil perfil;
  final DatosFiscales fiscales;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        _TarjetaDatos(perfil: perfil, fiscales: fiscales),
        const SizedBox(height: 16),
        _TarjetaPassword(tienePassword: perfil.tienePassword),
      ],
    );
  }
}

// ====================================================================
// Datos personales y fiscales
// ====================================================================

class _TarjetaDatos extends ConsumerStatefulWidget {
  const _TarjetaDatos({required this.perfil, required this.fiscales});

  final Perfil perfil;
  final DatosFiscales fiscales;

  @override
  ConsumerState<_TarjetaDatos> createState() => _TarjetaDatosState();
}

class _TarjetaDatosState extends ConsumerState<_TarjetaDatos> {
  final _formulario = GlobalKey<FormState>();

  final _nombres = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _nroDoc = TextEditingController();
  final _razonSocial = TextEditingController();

  OpcionFiscal? _tipoDocumento;
  OpcionFiscal? _condicionIva;

  bool _enviando = false;
  Map<String, String> _erroresCampo = {};
  ErrorApi? _errorGeneral;

  @override
  void initState() {
    super.initState();
    _prellenar();
  }

  @override
  void didUpdateWidget(_TarjetaDatos anterior) {
    super.didUpdateWidget(anterior);

    if (widget.perfil != anterior.perfil) {
      _prellenar();
    }
  }

  void _prellenar() {
    final usuario = widget.perfil.usuario;
    final cliente = widget.perfil.cliente;

    _nombres.text = usuario.nombres;
    _apellido.text = usuario.apellido;
    _email.text = usuario.email;
    _telefono.text = cliente?.telefono ?? '';
    _nroDoc.text = cliente?.nroDoc ?? '';
    _razonSocial.text = cliente?.razonSocial ?? '';

    _tipoDocumento =
        _buscar(widget.fiscales.tiposDocumento, cliente?.tipoDocumento?.id);
    _condicionIva =
        _buscar(widget.fiscales.condicionesIva, cliente?.condicionIva?.id);
  }

  static OpcionFiscal? _buscar(List<OpcionFiscal> lista, int? id) {
    if (id == null) return null;

    for (final opcion in lista) {
      if (opcion.id == id) return opcion;
    }

    return null;
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellido.dispose();
    _email.dispose();
    _telefono.dispose();
    _nroDoc.dispose();
    _razonSocial.dispose();
    super.dispose();
  }

  void _limpiarError(String campo) {
    if (!_erroresCampo.containsKey(campo)) return;

    setState(() => _erroresCampo = {..._erroresCampo}..remove(campo));
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erroresCampo = {};
      _errorGeneral = null;
    });

    try {
      final guardado = await ref.read(perfilRepositoryProvider).actualizar(
        nombres: _nombres.text,
        apellido: _apellido.text,
        email: _email.text,
        tipoDocumentoId: _tipoDocumento!.id,
        nroDoc: _nroDoc.text,
        condicionIvaId: _condicionIva!.id,
        telefono: _telefono.text,
        razonSocial: _razonSocial.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(guardado.mensaje)),
      );

      try {
        await ref.read(sesionProvider.notifier).refrescarUsuario();
      } on ErrorApi {
        if (mounted) ref.invalidate(perfilProvider);
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

  @override
  Widget build(BuildContext context) {
    final perfil = widget.perfil;
    final codigoDoc = _tipoDocumento?.codigoAfip;

    final avisoFiscal = CodigosAfip.avisoCoherenciaFiscal(
      codigoDocumento: codigoDoc,
      codigoIva: _condicionIva?.codigoAfip,
    );

    final cambiaElCorreo = _email.text.trim().toLowerCase() !=
        perfil.usuario.email.trim().toLowerCase();

    final bloqueado = perfil.documentoBloqueado;
    final motivoBloqueo = perfil.motivoDocumentoBloqueado;

    return _Tarjeta(
      titulo: 'Datos personales',
      subtitulo: 'Tus datos de contacto y los que usamos para facturarte.',
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!perfil.tieneFichaDeCliente) ...[
              const AvisoInformativo(
                titulo: 'No podemos guardar tus datos todavía',
                detalle: 'Tu cuenta no tiene una ficha de cliente asociada, '
                    'así que no vamos a poder facturarte. Acercate al local '
                    'para que te la vinculen.',
                icono: Icons.badge_outlined,
              ),
            ],

            if (_errorGeneral != null) ...[
              AvisoError(error: _errorGeneral!),
            ],

            if (_erroresCampo.isNotEmpty) ...[
              AvisoInformativo(
                titulo: 'Revisá los campos marcados',
                detalle: 'El servidor rechazó ${_erroresCampo.length} '
                    '${_erroresCampo.length == 1 ? "campo" : "campos"}. '
                    'El detalle está debajo de cada uno.',
                icono: Icons.edit_note,
              ),
            ],

            CampoFormulario(
              controlador: _nombres,
              etiqueta: 'Nombres',
              obligatorio: true,
              habilitado: !_enviando,
              largoMaximo: 80,
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
              largoMaximo: 80,
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
              largoMaximo: 150,
              tipoTeclado: TextInputType.emailAddress,
              autofill: const [AutofillHints.email],
              accionTeclado: TextInputAction.next,
              errorServidor: _erroresCampo['email'],
              onCambio: (_) {
                _limpiarError('email');
                setState(() {});
              },
            ),

            if (cambiaElCorreo) ...[
              const AvisoInformativo(
                titulo: 'Vas a tener que verificar el correo nuevo',
                detalle: 'Cuando guardes, te mandamos un enlace a esa '
                    'dirección. Hasta que lo toques vas a poder mirar el '
                    'catálogo y tus compras, pero no agregar al carrito ni '
                    'pagar.',
                icono: Icons.mark_email_unread_outlined,
              ),
            ],

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

            const _Subtitulo(
              titulo: 'Datos para tu factura',
              detalle: 'Si sos responsable inscripto, monotributista o '
                  'exento, identificate con tu CUIT.',
            ),

            if (bloqueado && motivoBloqueo != null) ...[
              AvisoInformativo(
                titulo: 'Tu documento no se puede cambiar',
                detalle: motivoBloqueo,
                icono: Icons.lock_outline_rounded,
              ),
            ],

            CampoDesplegable<OpcionFiscal>(
              valor: _condicionIva,
              opciones: widget.fiscales.condicionesIva,
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
              opciones: widget.fiscales.tiposDocumento,
              etiqueta: 'Tipo de documento',
              textoDe: (o) => o.nombre,
              habilitado: !_enviando && !bloqueado,
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
              AvisoInformativo(
                titulo: 'Revisá el tipo de documento',
                detalle: avisoFiscal,
                icono: Icons.info_outline_rounded,
              ),
            ],

            CampoFormulario(
              controlador: _nroDoc,
              etiqueta: 'Número de documento',
              obligatorio: true,
              habilitado: !_enviando && !bloqueado && _tipoDocumento != null,
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
              onEnviar: _enviando ? null : _guardar,
              errorServidor: _erroresCampo['razon_social'],
              onCambio: (_) => _limpiarError('razon_social'),
            ),

            const SizedBox(height: 10),

            _BotonGuardar(
              onPresionar: perfil.tieneFichaDeCliente && !_enviando
                  ? _guardar
                  : null,
              enviando: _enviando,
              texto: 'Guardar cambios',
              textoEnviando: 'Guardando...',
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Contraseña
// ====================================================================

class _TarjetaPassword extends ConsumerStatefulWidget {
  const _TarjetaPassword({required this.tienePassword});

  final bool tienePassword;

  @override
  ConsumerState<_TarjetaPassword> createState() => _TarjetaPasswordState();
}

class _TarjetaPasswordState extends ConsumerState<_TarjetaPassword> {
  final _formulario = GlobalKey<FormState>();

  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();

  bool _enviando = false;

  // Visibilidad independiente para cada campo.
  bool _mostrarActual = false;
  bool _mostrarNueva = false;
  bool _mostrarRepetir = false;

  Map<String, String> _erroresCampo = {};
  ErrorApi? _errorGeneral;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  void _limpiarError(String campo) {
    if (!_erroresCampo.containsKey(campo)) return;

    setState(() => _erroresCampo = {..._erroresCampo}..remove(campo));
  }

  Future<void> _cambiar() async {
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erroresCampo = {};
      _errorGeneral = null;
    });

    try {
      final mensaje = await ref.read(perfilRepositoryProvider).cambiarPassword(
        passwordActual: widget.tienePassword ? _actual.text : null,
        password: _nueva.text,
        passwordConfirmation: _repetir.text,
      );

      if (!mounted) return;

      _actual.clear();
      _nueva.clear();
      _repetir.clear();

      // Por seguridad, también se ocultan nuevamente los campos.
      setState(() {
        _mostrarActual = false;
        _mostrarNueva = false;
        _mostrarRepetir = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
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

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Contraseña',
      subtitulo: widget.tienePassword
          ? 'Para cambiarla, confirmá la que usás hoy.'
          : null,
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorGeneral != null) ...[
              AvisoError(error: _errorGeneral!),
            ],

            if (widget.tienePassword)
              CampoFormulario(
                controlador: _actual,
                etiqueta: 'Contraseña actual',
                obligatorio: true,
                esPassword: !_mostrarActual,
                habilitado: !_enviando,
                autofill: const [AutofillHints.password],
                accionTeclado: TextInputAction.next,
                errorServidor: _erroresCampo['current_password'],
                onCambio: (_) => _limpiarError('current_password'),
                sufijo: IconButton(
                  tooltip: _mostrarActual
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  icon: Icon(
                    _mostrarActual
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: _enviando
                      ? null
                      : () {
                    setState(() {
                      _mostrarActual = !_mostrarActual;
                    });
                  },
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'Hoy ingresás con Google. Si elegís una contraseña, también '
                      'vas a poder ingresar con tu correo.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),

            CampoFormulario(
              controlador: _nueva,
              etiqueta: 'Nueva contraseña',
              obligatorio: true,
              esPassword: !_mostrarNueva,
              habilitado: !_enviando,
              ayuda: 'Al menos 8 caracteres.',
              autofill: const [AutofillHints.newPassword],
              accionTeclado: TextInputAction.next,
              errorServidor: _erroresCampo['password'],
              onCambio: (_) => _limpiarError('password'),
              sufijo: IconButton(
                tooltip: _mostrarNueva
                    ? 'Ocultar contraseña'
                    : 'Mostrar contraseña',
                icon: Icon(
                  _mostrarNueva
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: _enviando
                    ? null
                    : () {
                  setState(() {
                    _mostrarNueva = !_mostrarNueva;
                  });
                },
              ),
            ),

            CampoFormulario(
              controlador: _repetir,
              etiqueta: 'Repetí la nueva contraseña',
              obligatorio: true,
              esPassword: !_mostrarRepetir,
              habilitado: !_enviando,
              accionTeclado: TextInputAction.done,
              onEnviar: _enviando ? null : _cambiar,
              errorServidor: _erroresCampo['password_confirmation'],
              onCambio: (_) => _limpiarError('password_confirmation'),
              sufijo: IconButton(
                tooltip: _mostrarRepetir
                    ? 'Ocultar contraseña'
                    : 'Mostrar contraseña',
                icon: Icon(
                  _mostrarRepetir
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: _enviando
                    ? null
                    : () {
                  setState(() {
                    _mostrarRepetir = !_mostrarRepetir;
                  });
                },
              ),
            ),

            const SizedBox(height: 10),

            _BotonGuardar(
              onPresionar: _enviando ? null : _cambiar,
              enviando: _enviando,
              texto: 'Cambiar contraseña',
              textoEnviando: 'Cambiando...',
            ),

            const SizedBox(height: 10),

            const Text(
              'Cambiar la contraseña no cierra las sesiones de otros '
                  'dispositivos.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Piezas compartidas
// ====================================================================

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.titulo,
    required this.child,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final detalle = subtitulo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Color(0xFF202B3C),
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 5),
            Text(
              detalle,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo({required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Color(0xFF202B3C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detalle,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  const _BotonGuardar({
    required this.onPresionar,
    required this.enviando,
    required this.texto,
    required this.textoEnviando,
  });

  final VoidCallback? onPresionar;
  final bool enviando;
  final String texto;
  final String textoEnviando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: onPresionar,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: enviando
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(textoEnviando),
          ],
        )
            : Text(texto),
      ),
    );
  }
}
