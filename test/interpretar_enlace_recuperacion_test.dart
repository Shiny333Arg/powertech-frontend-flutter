import 'package:flutter_test/flutter_test.dart';
import 'package:powertech_tienda/ui/pantallas/pantalla_restablecer_password.dart';

/// Pruebas de la lectura del enlace de recuperacion.
///
/// Es la unica pieza del circuito con logica propia del lado de la app: todo
/// lo demas —vigencia del token, un solo uso, reglas de la contraseña— lo
/// decide el broker de Laravel y no se puede probar desde aca.
///
/// Correr con: flutter test test/interpretar_enlace_recuperacion_test.dart
void main() {
  group('interpretarEnlaceDeRecuperacion', () {
    test('saca el token y el correo del enlace que manda Laravel', () {
      final leido = interpretarEnlaceDeRecuperacion(
        'https://powertech.test/reset-password/abc123TOKEN?email=cliente%40ejemplo.com',
      );

      expect(leido.token, 'abc123TOKEN');
      expect(leido.email, 'cliente@ejemplo.com');
    });

    test('encuentra el enlace aunque venga rodeado de texto', () {
      final leido = interpretarEnlaceDeRecuperacion(
        'Hola: entrá a https://powertech.test/reset-password/tok99?email=a%40b.com '
        'para elegir tu contraseña.',
      );

      expect(leido.token, 'tok99');
      expect(leido.email, 'a@b.com');
    });

    test('descarta la puntuacion y los signos que pega el cliente de correo', () {
      final entreAngulos = interpretarEnlaceDeRecuperacion(
        '<https://powertech.test/reset-password/tok77>',
      );
      expect(entreAngulos.token, 'tok77');

      final conPunto = interpretarEnlaceDeRecuperacion(
        'https://powertech.test/reset-password/tok88.',
      );
      expect(conPunto.token, 'tok88');
    });

    test('acepta el token copiado solo, sin enlace', () {
      final leido = interpretarEnlaceDeRecuperacion('  soloElToken123  ');

      expect(leido.token, 'soloElToken123');
      expect(leido.email, isNull);
    });

    test('un correo con signo mas sobrevive al decodificado', () {
      // Laravel lo escribe como %2B, no como '+', asi que no se confunde con
      // un espacio.
      final leido = interpretarEnlaceDeRecuperacion(
        'https://powertech.test/reset-password/tok?email=juan%2Btienda%40ejemplo.com',
      );

      expect(leido.email, 'juan+tienda@ejemplo.com');
    });

    test('el campo vacio no devuelve token', () {
      final leido = interpretarEnlaceDeRecuperacion('   ');

      expect(leido.token, isEmpty);
      expect(leido.email, isNull);
    });

    test('sin el segmento reset-password usa el ultimo, y que decida el backend', () {
      final leido = interpretarEnlaceDeRecuperacion(
        'https://powertech.test/otra/ruta/tokRaro',
      );

      expect(leido.token, 'tokRaro');
    });
  });
}
