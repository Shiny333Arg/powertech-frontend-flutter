import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/categoria.dart';
import 'proveedores_core.dart';

/// Lista de categorias del catalogo.
///
/// `ref.invalidate(categoriasProvider)` fuerza un refetch: es lo que usa el
/// boton "Reintentar" de la pantalla de diagnostico.
final categoriasProvider = FutureProvider<List<Categoria>>((ref) async {
  return ref.watch(catalogoRepositoryProvider).categorias();
});
