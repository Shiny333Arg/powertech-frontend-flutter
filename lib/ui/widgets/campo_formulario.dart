
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Campo de texto que muestra los errores recibidos del backend.
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
    this.sufijo,
  });

  final TextEditingController controlador;
  final String etiqueta;
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
  final Widget? sufijo;

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
          errorText: errorServidor,
          errorMaxLines: 4,
          counterText: '',
          suffixIcon: sufijo,
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

// Desplegable para las listas fiscales.
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
            child: Text(
              textoDe(opcion),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}
