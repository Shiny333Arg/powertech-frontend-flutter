# Parche a mano: `android/app/src/main/AndroidManifest.xml`

No pises el archivo que genero `flutter create`: hacele **dos** cambios.

## 1. Permiso de internet

Arriba de todo, como hijo directo de `<manifest>` y **antes** de
`<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />

    <application
```

`flutter create` ya pone este permiso en `debug/AndroidManifest.xml` y
`profile/AndroidManifest.xml`, pero **no** en el principal. Sin esto el
release build no tiene red y el bug aparece recien cuando armas el APK.

## 2. Config de red en texto plano

En la etiqueta `<application>`, agrega el atributo:

```xml
    <application
        android:label="powertech_tienda"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:networkSecurityConfig="@xml/network_security_config">
```

Eso apunta al archivo `android/app/src/main/res/xml/network_security_config.xml`
que viene en este paquete.

**Por que:** desde Android 9 (API 28) el trafico HTTP sin TLS esta bloqueado
por defecto. Laravel en desarrollo corre en `http://`, asi que sin este
archivo el GET a `/api/v1/categorias` falla con un `connectionError` seco que
parece un problema de IP y no lo es. Es el tropiezo numero uno de este paso.
