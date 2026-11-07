# PowerTech Flutter — Paso 0: andamiaje

## Donde va cada archivo

Descomprimi el zip **encima de la raiz de tu proyecto** (la carpeta que tiene
`pubspec.yaml`). Los archivos respetan la estructura final:

```
powertech_tienda/                     <- raiz de tu proyecto flutter create
├── pubspec.yaml                      <- REEMPLAZA el que genero flutter create
├── lib/
│   ├── main.dart                     <- REEMPLAZA el contador de ejemplo
│   ├── core/
│   │   ├── config.dart               <- URL base por --dart-define
│   │   ├── errores.dart              <- jerarquia ErrorApi (401 != 403)
│   │   ├── api_client.dart           <- Dio unico + interceptor de token
│   │   └── almacenamiento.dart       <- token en flutter_secure_storage
│   ├── datos/
│   │   ├── modelos/
│   │   │   └── categoria.dart        <- fromJson a mano
│   │   └── repositorios/
│   │       └── catalogo_repository.dart
│   ├── estado/
│   │   ├── proveedores_core.dart     <- almacen, api, repositorios
│   │   └── catalogo_providers.dart   <- categoriasProvider
│   └── ui/
│       ├── pantallas/
│       │   └── pantalla_diagnostico.dart   <- TEMPORAL, se borra en el paso 1
│       └── widgets/                  <- vacio por ahora
└── android/app/src/main/
    ├── res/xml/network_security_config.xml   <- ARCHIVO NUEVO
    └── AndroidManifest.xml.PARCHE.md         <- instrucciones, NO es un archivo del build
```

El unico archivo que tenes que editar a mano es
`android/app/src/main/AndroidManifest.xml`: segui las dos modificaciones del
`.PARCHE.md` y despues borra ese `.md`.

## Puesta en marcha

```powershell
cd C:\ruta\a\powertech_tienda
flutter --version          # necesitas Flutter >= 3.44 / Dart >= 3.12
flutter pub get
```

### Si `flutter pub get` falla por version del SDK

`go_router 18.x` exige Dart `^3.12.0`. Dos salidas:

1. `flutter upgrade` (recomendado)
2. Si no podes actualizar, borra las lineas de version del `pubspec.yaml`,
   ajusta `environment:` a tu SDK y deja que pub elija:
   ```powershell
   flutter pub add flutter_riverpod dio flutter_secure_storage go_router intl url_launcher
   ```
   pub resuelve la version mas alta compatible con tu Flutter.

### 1. Levantar Laravel escuchando hacia afuera

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

`--host=0.0.0.0` no es opcional. Por defecto `artisan serve` escucha solo en
`127.0.0.1` y el emulador no lo ve.

Verifica desde la PC antes de tocar Flutter:

```powershell
curl http://localhost:8000/api/v1/categorias
```

### 2. Emulador de Android

```powershell
flutter run --dart-define=API_URL_BASE=http://10.0.2.2:8000
```

`10.0.2.2` es el alias que el emulador usa para el `localhost` de la PC
anfitriona. `localhost` dentro del emulador es el propio emulador: por eso
falla.

### 3. Telefono real por USB (misma red Wi-Fi)

```powershell
ipconfig                   # busca "Direccion IPv4" de tu adaptador Wi-Fi
flutter run --dart-define=API_URL_BASE=http://192.168.0.15:8000
```

Ademas:
- descomenta la linea de `192.168.0.15` en `network_security_config.xml` y
  pone tu IP real (no acepta comodines);
- abri el puerto 8000 en el Firewall de Windows:
  ```powershell
  New-NetFirewallRule -DisplayName "Laravel 8000" -Direction Inbound `
    -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
  ```

### 4. Tunel ngrok (telefono fuera de la red, o para probar HTTPS)

```powershell
ngrok http 8000
flutter run --dart-define=API_URL_BASE=https://TUSUBDOMINIO.ngrok-free.app
```

Con ngrok es HTTPS, asi que no hace falta tocar nada del archivo de seguridad
de red. El `ApiClient` ya manda la cabecera `ngrok-skip-browser-warning` para
que no te devuelva la pagina intersticial en HTML donde esperas JSON.

Del lado de Laravel, agrega el host de ngrok a `APP_URL` si usas rutas
absolutas, y revisa `TrustProxies` si te aparecen URLs en `http://`.

### Para no reescribir el `--dart-define` cada vez

`.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "PowerTech (emulador)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=API_URL_BASE=http://10.0.2.2:8000"]
    },
    {
      "name": "PowerTech (ngrok)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=API_URL_BASE=https://TUSUBDOMINIO.ngrok-free.app"]
    }
  ]
}
```

**Importante:** `--dart-define` se resuelve al compilar. Si cambias la URL,
un hot reload no alcanza: hay que parar y volver a correr.

## Que tenes que ver

Barra gris arriba con `http://10.0.2.2:8000/api/v1`, debajo
`Conexion OK - N categorias` y la lista. Si falla, la pantalla muestra el tipo
de error, la URL que intento y una checklist.

## Diagnostico rapido

| Sintoma en pantalla | Causa casi segura |
|---|---|
| "La app se compilo sin URL base" | falto el `--dart-define` |
| "No se pudo conectar" + `10.0.2.2` | `artisan serve` sin `--host=0.0.0.0`, o Laravel apagado |
| "No se pudo conectar" + IP LAN | Firewall de Windows, o falta tu IP en `network_security_config.xml` |
| "No se pudo conectar" y la URL dice `localhost` | estas usando `localhost` en el emulador: va `10.0.2.2` |
| "Ruta inexistente (404)" | la URL base quedo con `/api/v1` duplicado, o el prefijo no coincide |
| "La respuesta no es la API" | volvio HTML: pegaste a la web Blade, o a la intersticial de ngrok |
| `CLEARTEXT communication not permitted` en el log | falta el parche del AndroidManifest |
| El build de Gradle se queja de `minSdkVersion` | `flutter_secure_storage` 11.x pide API 23+. En `android/app/build.gradle.kts`, pone `minSdk = 23` |

## Lo que todavia no esta (a proposito)

- **go_router**: la dependencia esta, pero con una sola pantalla un router es
  ceremonia vacia. Entra en el paso 1 junto con el redirect por los tres
  estados de sesion.
- **cached_network_image**: lo agregamos cuando existan tarjetas de producto
  con imagen, verificando la version en ese momento.
- `pantalla_diagnostico.dart` es descartable. No le construyas nada encima.

## Versiones verificadas en pub.dev el 2026-11-06

| Paquete | Version |
|---|---|
| flutter_riverpod | 3.4.3 |
| dio | 5.11.1 |
| flutter_secure_storage | 11.2.0 |
| go_router | 18.1.3 |
| intl | 0.20.3 |
| url_launcher | 6.3.3 |
| flutter_lints | 6.0.0 |
