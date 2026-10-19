# Descargador

Gabriel Castiglia · 19 de octubre de 2026 · versión 1.0.0 · licencia GPL-2.0 · hecho y probado con yt-dlp 2026.08.19

[English](README.md) · Español

Repositorio: <https://github.com/Gabriel-Castiglia/descargador>

Manual en PDF: [`docs/Descargador-manual-es.pdf`](docs/Descargador-manual-es.pdf)

Descargador es una aplicación de macOS que descarga video y audio de YouTube y de los demás sitios
compatibles con [yt-dlp](https://github.com/yt-dlp/yt-dlp). La aplicación arma el comando, muestra
el progreso y organiza una cola de descargas. El trabajo lo hacen yt-dlp, incluido en la aplicación
en una versión fija y verificada, y ffmpeg, instalado con Homebrew. La interfaz está en inglés y en castellano, y se elige en el menú Language (Idioma cuando
la app está en castellano). La primera vez arranca en inglés y después recuerda la elección.

## Requisitos

- macOS 15 o posterior, en una Mac con chip Apple. Se probó en macOS 27.
- [Homebrew](https://brew.sh) en `/opt/homebrew`.
- Command Line Tools de Apple (`xcode-select --install`). No se necesita Xcode.

yt-dlp viene dentro de la aplicación, y Python, deno y ffmpeg los instala el instalador, así que no
hay que instalar nada a mano.

## Instalación

```
git clone https://github.com/Gabriel-Castiglia/descargador.git
cd descargador
scripts/instalar.sh
```

El instalador:

1. instala Python, deno y ffmpeg con Homebrew o, si ya están, los actualiza;
2. compila la aplicación, comprueba el yt-dlp incluido contra sus sumas oficiales y firma la
   aplicación con la identidad local (ver «Firma y permisos»);
3. la copia a `/Applications/Descargador.app`, cerrándola antes si estaba abierta.

Volver a ejecutarlo es la forma de actualizar todo: dependencias y aplicación.

## Uso

1. Pegar uno o varios enlaces en el recuadro superior. Se aceptan enlaces sueltos, uno por línea o
   dentro de un texto copiado de otra parte; la aplicación los extrae y descarta los duplicados. Si
   el acceso al portapapeles está permitido, al abrirla incorpora sola el enlace copiado.
2. Elegir el formato, Video (MP4) o Solo audio (MP3).
3. Elegir la carpeta de destino. La primera vez es Descargas; después se conserva la última
   elegida, igual que el formato.
4. Pulsar Descargar o ⌘↩.

Los enlaces entran en una cola y se descargan de a uno. Mientras la cola avanza se pueden agregar
más enlaces. Cada fila muestra la miniatura, el título, el porcentaje, la velocidad y el tiempo
restante, y al terminar ofrece mostrar el archivo en el Finder o abrirlo. Las descargas con error o
canceladas se pueden reintentar o quitar. La salida completa de yt-dlp está en «Detalles técnicos».

También se puede iniciar con enlaces desde la Terminal o desde Atajos:

```
open -a Descargador --args --descargar URL1 URL2
```

## Formatos

| Formato | Resultado | Opciones de yt-dlp |
|---|---|---|
| Video | MP4 con H.264 y AAC, máximo 1080p en YouTube | `-f bv*+ba/b -S vcodec:h264,res,acodec:aac --merge-output-format mp4` |
| Solo audio | MP3 a la máxima calidad | `-x --audio-format mp3 --audio-quality 0` |

Se prefiere H.264 porque QuickTime y iOS lo reproducen sin conversión; sin esa preferencia YouTube
entrega AV1 con audio Opus. Los archivos llevan el título del video como nombre. Un enlace que
apunta a una lista de reproducción descarga solo ese video.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `fuentes/Descargador.swift` | Código de la aplicación (SwiftUI, un solo archivo) |
| `icono/icono.html` | Ícono en SVG |
| `icono/icono-1024.png` | Ícono renderizado, origen de todos los tamaños |
| `scripts/instalar.sh` | Dependencias, compilación e instalación |
| `scripts/compilar.sh` | Compilación y firma en `build/` |
| `scripts/firma.sh` | Identidad de firma local (la carga `compilar.sh`) |
| `scripts/manual.sh` | Genera los manuales en PDF a partir de los README |
| `scripts/actualizar-yt-dlp.sh` | Reemplaza el yt-dlp incluido por otra versión verificada |
| `vendor/yt-dlp/` | Copia incluida de yt-dlp 2026.08.19, con código fuente, sumas, firma y licencias |
| `docs/Descargador-manual-es.pdf`, `docs/Descargador-manual-en.pdf` | Manuales en PDF, en castellano y en inglés |
| `docs/manual.css` | Estilo de los manuales |
| `README.es.md`, `README.md` | Esta documentación, en castellano y en inglés |

La carpeta `build/` se genera al compilar y no forma parte del repositorio.

## Firma y permisos

macOS guarda los permisos que el usuario concede, como el acceso a Descargas o al portapapeles,
asociados a la firma de la aplicación. Una firma ad hoc cambia en cada compilación y macOS vuelve a
pedirlos. Por eso el proyecto firma con un certificado propio y estable, «Descargador (firma
local)», que `scripts/firma.sh` crea la primera vez en la Mac donde se compila:

- el certificado y su clave quedan en un llavero dedicado,
  `~/Library/Keychains/descargador-firma.keychain-db`;
- la contraseña de ese llavero queda en el llavero de inicio de sesión, con el nombre
  `descargador-firma-local`.

Con esa firma, los permisos concedidos una vez se mantienen entre versiones. El certificado solo
existe en la Mac donde se creó: una copia ya compilada que se lleve a otra Mac se abre la primera
vez con clic derecho y Abrir.

El pegado automático de enlaces al abrir la aplicación funciona solo si el acceso al portapapeles
está en «Permitir siempre» (Ajustes del Sistema, Privacidad y seguridad, Pegar desde otras apps).
Sin ese permiso, la aplicación lee el portapapeles únicamente al pulsar Pegar y no muestra avisos
al abrirse.

## Ícono

La interfaz toma el color de acento del sistema y lo sigue si cambia. El ícono, en cambio, es fijo
(grafito con el verde del acento actual), porque un ícono adaptable al tema requiere el formato de
Icon Composer y Xcode. Para cambiar sus colores se editan los `stop-color` de `icono/icono.html`,
se vuelve a generar el PNG y se reinstala:

```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=512,512 --default-background-color=00000000 \
  --screenshot="$PWD/icono/icono-1024.png" "file://$PWD/icono/icono.html"
scripts/instalar.sh
```

Si el Dock conserva el ícono anterior, hay que quitar la aplicación del Dock y volver a agregarla.

## Mantenimiento

Descargador está hecho y probado con yt-dlp 2026.08.19, y esa copia exacta viaja dentro de la
aplicación. Una versión fija mantiene estable el comportamiento y no depende de que el repositorio
de yt-dlp siga en línea. La contra es que YouTube cambia seguido y, tarde o temprano, una versión
fija deja de funcionar con él. Cuando eso pase, una versión nueva de Descargador pasa a un yt-dlp
más reciente:

```
scripts/actualizar-yt-dlp.sh <versión>
scripts/instalar.sh
```

El primer script descarga la versión, verifica su firma con la clave guardada en
`vendor/yt-dlp/public.key` y sus sumas SHA-256, y recién entonces reemplaza los archivos. Volver a
ejecutar `scripts/instalar.sh` también actualiza Python, deno y ffmpeg.

Los errores más frecuentes de yt-dlp se muestran con un texto claro en el idioma de la interfaz
(video no disponible, video privado, sitio no compatible, sin conexión) y el resto aparece tal como
lo emite yt-dlp.

Las preferencias (idioma, carpeta, formato, tamaño de la ventana) se guardan en el dominio
`io.github.gabriel-castiglia.descargador`. Se restablecen con
`defaults delete io.github.gabriel-castiglia.descargador`.

## Notas técnicas

La aplicación ejecuta el yt-dlp incluido con el Python de Homebrew, como proceso hijo, y agrega
`/opt/homebrew/bin` al `PATH`, ya que una aplicación abierta desde el Finder no hereda el de la
Terminal y no encontraría deno ni ffmpeg. Para no
depender del texto que yt-dlp imprime para la Terminal, le pide una salida con formato propio,
separada por tabuladores:

| Línea | Contenido | Origen |
|---|---|---|
| `INFO` | título, autor, duración y miniatura | `-O before_dl:…` |
| `AVANCE` | porcentaje, velocidad y tiempo restante | `--progress-template` |
| `ARCHIVO` | ruta final del archivo | `-O after_move:…` |

Compilar sin Xcode impone dos limitaciones, ya resueltas en el código. La primera es que el macro
`@State` de SwiftUI no está disponible, porque su plugin solo viene con Xcode; en su lugar se usa
`@StateObject` con la clase `Marca`. La segunda es que, con la barra de título oculta, SwiftUI
ignora `.defaultSize`, y el tamaño inicial de la ventana se fija desde AppKit en
`applicationDidFinishLaunching`.

## Créditos

Descargador es una interfaz; el trabajo de fondo es de estos proyectos:

| Proyecto | Papel en Descargador | Licencia |
|---|---|---|
| [yt-dlp](https://github.com/yt-dlp/yt-dlp), de los colaboradores de yt-dlp, fork de youtube-dl | Motor de descarga, incluido en `vendor/yt-dlp` | [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE) |
| [yt-dlp-ejs](https://github.com/yt-dlp/ejs), dentro del ejecutable de yt-dlp | Resuelve los desafíos JavaScript de YouTube | Unlicense |
| [meriyah](https://github.com/meriyah/meriyah), de KFlash y otros, dentro de yt-dlp-ejs | Analizador de JavaScript | [ISC](https://github.com/meriyah/meriyah/blob/main/LICENSE.md) |
| [astring](https://github.com/davidbonnet/astring), de David Bonnet, dentro de yt-dlp-ejs | Generador de código JavaScript | [MIT](https://github.com/davidbonnet/astring/blob/main/LICENSE) |
| [FFmpeg](https://ffmpeg.org), instalado con Homebrew, no incluido | Une imagen y sonido, convierte a MP3 | [LGPL-2.1+ / GPL-2.0+](https://ffmpeg.org/legal.html), según la compilación |
| [Deno](https://deno.com), instalado con Homebrew | Intérprete de JavaScript que yt-dlp usa para YouTube | [MIT](https://github.com/denoland/deno/blob/main/LICENSE.md) |
| [Python](https://www.python.org), instalado con Homebrew | Ejecuta yt-dlp | [Licencia PSF](https://docs.python.org/3/license.html) |
| [Homebrew](https://brew.sh) | Instala las dependencias | [BSD-2-Clause](https://github.com/Homebrew/brew/blob/master/LICENSE.txt) |
| [pandoc](https://pandoc.org), solo para generar los manuales en PDF | Conversión de Markdown a HTML | [GPL-2.0+](https://github.com/jgm/pandoc/blob/main/COPYRIGHT) |

Los textos de licencia de los componentes incluidos están en `vendor/yt-dlp/licenses/` y se copian
dentro de la aplicación, en `Contents/Resources/licenses/`.

## Licencia

Copyright (C) 2026 Gabriel Castiglia.

Descargador es software libre, distribuido bajo la Licencia Pública General de GNU, versión 2
(GPL-2.0-only), la misma del núcleo Linux. Se puede usar, estudiar, modificar y redistribuir; toda
versión modificada que se distribuya debe publicarse bajo la misma licencia y con su código
fuente. El texto completo está en [`LICENSE`](LICENSE).

Descargador incluye una copia sin modificar de yt-dlp en `vendor/yt-dlp`, que conserva sus propias
licencias (Unlicense, con componentes ISC y MIT) y no queda cubierta por la GPL. Descargador ejecuta
yt-dlp y ffmpeg como programas aparte y no los enlaza; ffmpeg no se incluye.
