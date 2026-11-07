import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/errores.dart';
import '../../datos/modelos/categoria.dart';
import '../../estado/catalogo_providers.dart';

/// Pantalla temporal del paso 0: prueba de conectividad contra
/// `GET /api/v1/categorias`. Se borra en cuanto exista la vitrina real.
class PantallaDiagnostico extends ConsumerWidget {
  const PantallaDiagnostico({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerTech - diagnostico'),
        actions: [
          IconButton(
            tooltip: 'Reintentar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(categoriasProvider),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TarjetaConfig(),
          const Divider(height: 1),
          Expanded(
            child: !Config.estaConfigurada
                ? const _SinConfigurar()
                : categorias.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _Fallo(
                      error: e,
                      onReintentar: () => ref.invalidate(categoriasProvider),
                    ),
                    data: (lista) => _ListaCategorias(categorias: lista),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaConfig extends StatelessWidget {
  const _TarjetaConfig();

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall;

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('URL base', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(
            Config.estaConfigurada
                ? Config.urlBaseApi
                : '(sin definir: falta --dart-define=API_URL_BASE)',
            style: estilo,
          ),
        ],
      ),
    );
  }
}

class _SinConfigurar extends StatelessWidget {
  const _SinConfigurar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'La app se compilo sin URL base.\n\n'
          'Corre:\n'
          'flutter run --dart-define=API_URL_BASE=http://10.0.2.2:8000\n\n'
          'Ojo: --dart-define se resuelve al compilar. Un hot reload no '
          'alcanza, hay que volver a correr.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ListaCategorias extends StatelessWidget {
  const _ListaCategorias({required this.categorias});

  final List<Categoria> categorias;

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Conexion OK, pero el backend devolvio cero categorias.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Conexion OK - ${categorias.length} categorias',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: categorias.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = categorias[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${c.id}')),
                title: Text(c.nombre),
                subtitle: Text(c.slug),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Fallo extends StatelessWidget {
  const _Fallo({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colores.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _titulo(error),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: colores.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            error is ErrorApi
                ? (error as ErrorApi).mensaje
                : error.toString(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Checklist tipica del paso 0:\n'
            '- Laravel escuchando en 0.0.0.0, no solo en 127.0.0.1\n'
            '- En el emulador la IP de tu PC es 10.0.2.2, no localhost\n'
            '- INTERNET y cleartext habilitados en AndroidManifest\n'
            '- Que la URL no termine en barra ni incluya /api/v1 dos veces',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  String _titulo(Object error) {
    return switch (error) {
      ErrorRed() => 'No se pudo conectar',
      ErrorFormato() => 'La respuesta no es la API',
      ErrorSesionVencida() => 'Sesion vencida',
      ErrorAccesoDenegado() => 'Acceso denegado',
      ErrorNoEncontrado() => 'Ruta inexistente (404)',
      ErrorValidacion() => 'Datos invalidos',
      ErrorServidor(codigo: final c) => 'El servidor fallo ($c)',
      _ => 'Error inesperado',
    };
  }
}
