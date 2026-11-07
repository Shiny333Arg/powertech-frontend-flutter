/// Categoria del catalogo. `GET /api/v1/categorias` devuelve
/// `{ "data": [ { "id": 1, "nombre": "Placas de video", "slug": "placas" } ] }`
///
/// `fromJson` a mano, sin freezed ni build_runner. Es defensivo con los tipos
/// porque MySQL/PDO puede mandar el id como numero o como string.
class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    required this.slug,
  });

  final int id;
  final String nombre;
  final String slug;

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: _comoEntero(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'slug': slug,
      };

  @override
  String toString() => 'Categoria($id, $nombre)';
}

int _comoEntero(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse('$valor') ?? 0;
}
