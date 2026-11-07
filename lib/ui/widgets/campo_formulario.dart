import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto que sabe mostrar el error que vino del backend.
///
/// La validacion que manda es la de Laravel, no la del cliente: [errorServidor]
/// es el string que salio de `ErrorValidacion.primeroDe('campo')`. El
/// `validator` local solo evita el viaje de ida cuando el campo esta vacio.
///
/// Cuando hay error del servidor y el usuario empieza a corregir, el error se
/// borra: dejarlo pegado mientras se escribe la correccion es confuso. De eso
/// se encarga la pantalla con [onCambio].
class CampoFormulario extends StatelessWidget {
  const CampoFormulario({
    super.key,
    required this.controlador,
    required this.etiqueta,
    this.errorServidor,
    this.ayuda,
    this.obligatorio = false,
    this.esPassword = false,
    this.tipoTeclado,
    this.largoMaximo,
    this.soloDigitos = false,
    this.autofill,
    this.onCambio,
    this.habilitado = true,
    this.accionTeclado,
    this.onEnviar,
  });

  final TextEditingController controlador;
  final String etiqueta;

  /// El mensaje que devolvio Laravel para este campo.
  final String? errorServidor;

  final String? ayuda;
  final bool obligatorio;
  final bool esPassword;
  final TextInputType? tipoTeclado;
  final int? largoMaximo;
  final bool soloDigitos;
  final List<String>? autofill;
  final ValueChanged<String>? onCambio;
  final bool habilitado;
  final TextInputAction? accionTeclado;
  final VoidCallback? onEnviar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controlador,
        enabled: habilitado,
        obscureText: esPassword,
        keyboardType: tipoTeclado,
        textInputAction: accionTeclado,
        autofillHints: autofill,
        maxLength: largoMaximo,
        inputFormatters:
            soloDigitos ? [FilteringTextInputFormatter.digitsOnly] : null,
        onChanged: onCambio,
        onFieldSubmitted: onEnviar == null ? null : (_) => onEnviar!(),
        decoration: InputDecoration(
          labelText: etiqueta,
          border: const OutlineInputBorder(),
          helperText: ayuda,
          // El error del servidor gana sobre el helper y sobre el contador.
          errorText: errorServidor,
          errorMaxLines: 4,
          counterText: '',
        ),
        validator: (valor) {
          if (!obligatorio) return null;
          return (valor == null || valor.trim().isEmpty)
              ? 'Completá este campo.'
              : null;
        },
      ),
    );
  }
}

/// Desplegable para las listas fiscales. Misma logica de error que
/// [CampoFormulario]: el mensaje lo escribe Laravel.
class CampoDesplegable<T> extends StatelessWidget {
  const CampoDesplegable({
    super.key,
    required this.valor,
    required this.opciones,
    required this.etiqueta,
    required this.textoDe,
    required this.onCambio,
    this.errorServidor,
    this.ayuda,
    this.habilitado = true,
  });

  final T? valor;
  final List<T> opciones;
  final String etiqueta;
  final String Function(T) textoDe;
  final ValueChanged<T?> onCambio;
  final String? errorServidor;
  final String? ayuda;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        initialValue: valor,
        isExpanded: true,
        onChanged: habilitado ? onCambio : null,
        decoration: InputDecoration(
          labelText: etiqueta,
          border: const OutlineInputBorder(),
          helperText: ayuda,
          errorText: errorServidor,
          errorMaxLines: 4,
        ),
        validator: (v) => v == null ? 'Elegí una opción.' : null,
        items: opciones
            .map(
              (opcion) => DropdownMenuItem<T>(
                value: opcion,
                child: Text(textoDe(opcion), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
      ),
    );
  }
}
