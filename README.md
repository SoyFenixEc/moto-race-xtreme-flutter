# 🏍️ Moto Race Xtreme

![Logo](assets/icon/logo.png)

Juego de carreras estilo arcade (endless runner) en **HTML5 Canvas**, ejecutado dentro de una **app Flutter** con **WebView**. Corre localmente sin conexión a internet (excepto para scores online y anuncios).

---

## 📋 Índice
- [Características](#-características)
- [Capturas](#-capturas)
- [Estructura del proyecto](#-estructura-del-proyecto)
- [Requisitos](#-requisitos)
- [Build & Deploy](#-build--deploy)
- [Play Console](#-play-console)
- [API Backend](#-api-backend)
- [Configuración](#-configuración)
- [Créditos](#-créditos)

---

## 🎮 Características

### 🏁 Juego
- **Endless runner** con moto que esquiva vehículos en carretera
- **3 niveles de dificultad** (Fácil / Medio / Difícil)
- **7 colores de moto** seleccionables
- **Ciclo día/noche** dinámico
- **Power-ups**: corazones (❤️) y estrellas (⭐ que suben de nivel)
- **Sistema de vidas** (3 corazones)
- **Leaderboard** online con top jugadores
- **Sonidos** con AudioContext API
- **Efectos** (confetti al subir de nivel, popups de puntuación)

### 📱 App
- **Flutter** + **flutter_inappwebview** (WebView para el juego)
- **AdMob** (banner abajo + interstitial en botones clave y cada 5 niveles)
- **Firebase Cloud Messaging** (notificaciones push)
- **Scores online** vía API PHP + MySQL
- **Zoom reducido al 80%** para mejor visualización
- **Logo original** del juego en ícono launcher

### 📢 Interstitial Ads
| Acción | Comportamiento |
|--------|---------------|
| JUGAR / REINTENTAR | Muestra interstitial, luego arranca el juego |
| PAUSA | Pausa el juego y muestra interstitial |
| CONTINUAR | Muestra interstitial, luego reanuda |
| SCORE / Leaderboard | Muestra interstitial |
| Cada 5 niveles | Pausa, muestra interstitial, reanuda |

---

## 🗂️ Estructura del proyecto

```
moto-race-xtreme-flutter/
├── pubspec.yaml                    # Dependencias Flutter
├── lib/
│   └── main.dart                   # App completa (800+ líneas)
├── android/
│   ├── app/
│   │   ├── build.gradle.kts        # Build config (SDK 36, target 35)
│   │   ├── google-services.json    # Firebase config
│   │   ├── key.properties          # Keystore config
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── res/
│   │           ├── mipmap-*/        # Iconos launcher
│   │           ├── drawable-*/      # Iconos adaptativos
│   │           └── xml/
│   │               └── network_security_config.xml
│   ├── moto_race_xtreme.jks        # Keystore (¡NO compartir!)
│   └── settings.gradle.kts
├── assets/
│   └── icon/
│       └── logo.png                # Logo del juego
├── ios/
│   └── Runner/
│       └── Assets.xcassets/        # Iconos iOS
└── build_moto.bat                  # Script de build Windows
```

---

## 📦 Requisitos

### Desarrollo (Windows)
- **Flutter SDK** ≥ 3.22 (`C:\flutter\bin\flutter.bat`)
- **Android SDK** 36.0.0 (`C:\Users\User\AppData\Local\Android\Sdk`)
- **NDK** 28.2.13676358
- **Java 17** (Eclipse Adoptium jdk-17.0.15.6-hotspot)
- **Tailscale** para acceso remoto (IP Windows: `100.92.233.39`)

### Build local
- **Usuario:** `jarbis` / pass: `12345`
- **Ruta proyecto:** `C:\StudioProjects\moto-race-xtreme-flutter`

---

## 🔨 Build & Deploy

### Clonar y buildear (primera vez)
```bash
cd C:\StudioProjects\
git clone https://github.com/SoyFenixEc/moto-race-xtreme-flutter.git
cd moto-race-xtreme-flutter
flutter pub get
flutter build apk --release
```

### Instalar en dispositivo
```bash
flutter install --release
# O especificando el dispositivo:
flutter install --release -d ZY32L5J24D
```

### Build AAB (Play Store)
```bash
flutter build appbundle --release
```

### Script de build
Ejecutar `build_moto.bat` en Windows.

---

## 🛒 Play Console

### App Info
- **Package name:** `app.motoracextreme.app`
- **App ID:** `ca-app-pub-7277241406857965~6240358026` (AdMob)
- **Estado actual:** Borrador (draft) en Play Console

### AdMob
| Tipo | Ad Unit ID |
|------|-----------|
| Banner | `ca-app-pub-7277241406857965/9182108330` |
| Interstitial | `ca-app-pub-7277241406857965/9413208474` |

### Firebase
- **Project ID:** `moto-race-xtreme`
- **Storage bucket:** `moto-race-xtreme.firebasestorage.app`
- **Google Services JSON:** `android/app/google-services.json`

### Subida Automática
```bash
# 1. Build AAB en Windows
ssh jarbis@100.92.233.39 \
  "cd C:\\StudioProjects\\moto-race-xtreme-flutter && \
   C:\\flutter\\bin\\flutter.bat build appbundle --release"

# 2. Copiar al servidor
scp jarbis@100.92.233.39:"C:/StudioProjects/.../app-release.aab" /tmp/

# 3. Subir a Play Console (via API)
python3 /tmp/upload_playstore.py
```

### Keystore
| Campo | Valor |
|-------|-------|
| Archivo | `android/moto_race_xtreme.jks` |
| Alias | `moto_race` |
| Store Password | `123456` |
| Key Password | `123456` |
| SHA1 | `BE:0D:86:34:95:EE:8C:A6:9B:9E:38:41:4C:AC:21:75:DE:41:B9:81` |

---

## 🌐 API Backend

### Servidor
| Campo | Valor |
|-------|-------|
| Host | vmi3404208 (Contabo VPS) |
| IP | `161.97.74.198` |
| OS | Ubuntu 24.04.4 LTS |
| Tailscale | `100.118.174.45` |

### PHP API
```
http://161.97.74.198/moto_racer_extreme/api.php
```

| Acción | Método | Descripción |
|--------|--------|-------------|
| `login` | POST | Login automático, devuelve `player_id` |
| `save_score` | POST | Guarda puntuación |
| `leaderboard` | GET | Top jugadores |

### Archivos del backend
```
/var/www/html/moto_racer_extreme/
├── index.html        # Juego original (para web)
├── api.php           # API REST
├── config.php        # Conexión MySQL
├── moto_racer.sql    # Schema de BD
└── logo.png          # Logo del juego (corrupto)
```

### Base de Datos MySQL
- **DB:** `moto_racer`
- **Tablas:** `players`, `scores`
- **Usuario:** root / pass: `123qweQWE`

---

## ⚙️ Configuración

### Dependencias (pubspec.yaml)
```yaml
dependencies:
  flutter_inappwebview: ^6.1.5
  google_mobile_ads: ^5.2.0
  firebase_core: ^3.12.1
  firebase_messaging: ^15.2.4
  shared_preferences: ^2.3.0
  permission_handler: ^11.3.0
  package_info_plus: ^8.1.0
  url_launcher: ^6.3.1
  flutter_launcher_icons: ^0.14.3
```

### Android Config
- **compileSdk:** 36
- **targetSdk:** 35
- **minSdk:** 24
- **ndkVersion:** 28.2.13676358
- **usesCleartextTraffic:** true
- **Network Security Config:** `res/xml/network_security_config.xml`

---

## 📱 Dispositivos de Prueba

| Dispositivo | ID | Android |
|------------|-----|---------|
| Moto G15 | `ZY32L5J24D` | Android 15 (API 35) |

### ADB over Tailscale
Requerido: conectar Moto G15 a Tailscale + habilitar ADB TCP:
```bash
adb tcpip 5555                    # (una vez por USB)
adb connect <tailscale-ip-moto>   # ADB over Tailscale
```

---

## 🧠 Arquitectura Técnica

### Flujo de la App
1. **Inicio:** Firebase initialize + AdMob initialize + FCM token
2. **WebView:** Carga el juego HTML5 desde `about:blank` con el contenido embebido en Dart
3. **API Bridge:** JavaScript llama handlers de Flutter para login/leaderboard/save_score
4. **Dart HttpClient:** Flutter hace las peticiones HTTP (evita bloqueo cleartext del WebView)
5. **Anuncios:** Banner abajo + interstitial (controlados desde JS via Flutter)
6. **Notificaciones:** FCM para push notifications

### Seguridad
- HTTP permitido solo para la API del servidor (configurado en network_security_config.xml)
- Keystore exclusivo para este proyecto (no compartir con AGAL)
- Service account de Google con acceso solo a Play Console

---

## 👥 Créditos

- **Desarrollador:** Jarbis (asistente robot 🔥)
- **Dueño del proyecto:** Cristopher — [@SoyFenixEC](https://github.com/SoyFenixEc)
- **Repo:** [github.com/SoyFenixEc/moto-race-xtreme-flutter](https://github.com/SoyFenixEc/moto-race-xtreme-flutter)
- **Empresa:** AGAL Global

---

## 📄 Licencia

Propietaria — AGAL Global. Todos los derechos reservados.
