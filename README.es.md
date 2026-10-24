# Haul

Gabriel Castiglia · 24 de octubre de 2026 · versión 1.3.0 · licencia GPL-2.0 · hecho y probado con yt-dlp 2026.08.19

[English](README.md) · Español

Repositorio: <https://github.com/Gabriel-Castiglia/haul>

Versión para Windows: <https://github.com/Gabriel-Castiglia/haul-windows>

Manual en PDF: [`docs/Haul-manual-es.pdf`](docs/Haul-manual-es.pdf)

Haul es una aplicación de macOS que hace de interfaz de
[yt-dlp](https://github.com/yt-dlp/yt-dlp). La aplicación arma el comando, muestra
el progreso y organiza una cola de descargas. El trabajo lo hacen yt-dlp, incluido en la aplicación
en una versión fija y verificada, y ffmpeg, instalado con Homebrew. La interfaz está en inglés y en castellano, y se elige en el menú Language (Idioma cuando
la app está en castellano). La primera vez arranca en inglés y después recuerda la elección. La
ventana es siempre oscura, tenga el sistema el aspecto que tenga.

## Requisitos

- macOS 15 o posterior, en una Mac con chip Apple. Se probó en macOS 27.
- [Homebrew](https://brew.sh) en `/opt/homebrew`.
- Command Line Tools de Apple (`xcode-select --install`). No se necesita Xcode.

yt-dlp viene dentro de la aplicación, y Python, deno y ffmpeg los instala el instalador, así que no
hay que instalar nada a mano.

## Instalación

```
git clone https://github.com/Gabriel-Castiglia/haul.git
cd haul
scripts/instalar.sh
```

El instalador:

1. instala Python, deno y ffmpeg con Homebrew o, si ya están, los actualiza;
2. compila la aplicación, comprueba el yt-dlp incluido contra sus sumas oficiales y firma la
   aplicación con la identidad local (ver «Firma y permisos»);
3. la copia a `/Applications/Haul.app`, cerrándola antes si estaba abierta.

Volver a ejecutarlo es la forma de actualizar todo: dependencias y aplicación.

## Uso

1. Pegar uno o varios enlaces en el recuadro superior. Se aceptan enlaces sueltos, uno por línea o
   dentro de un texto copiado de otra parte; la aplicación los extrae y descarta los duplicados. Si
   el acceso al portapapeles está permitido, al abrirla incorpora sola el enlace copiado.
2. Elegir el formato, Video (MP4) o Solo audio (MP3).
3. Elegir la carpeta de destino. La primera vez es Descargas; después se conserva la última
   elegida, igual que el formato.
4. Pulsar Descargar o ⌘↩. El recuadro se vacía al empezar la descarga, y un enlace que ya
   está en la cola no vuelve a entrar solo desde el portapapeles.

Los enlaces entran en una cola y se descargan de a uno. Mientras la cola avanza se pueden agregar
más enlaces. Cada fila muestra la miniatura, el título, el porcentaje, la velocidad y el tiempo
restante, y al terminar ofrece mostrar el archivo en el Finder o abrirlo. Las descargas con error o
canceladas se pueden reintentar o quitar. Una descarga cancelada borra los archivos a medias que había
creado; los que ya estaban en la carpeta, como una descarga anterior del mismo video en otro formato,
no se tocan nunca. La salida completa de yt-dlp está en «Detalles técnicos».

Una descarga que falla se reintenta hasta cuatro veces, con dos segundos entre cada intento, y la fila
muestra qué intento está en curso («Reintento 2/4»). Los archivos a medias se conservan entre intentos,
así yt-dlp sigue desde donde quedó. Cuando una descarga termina, la aplicación borra además los
archivos intermedios que yt-dlp no pudo quitar, como el audio original de un MP3 mientras un cliente
de sincronización de archivos lo tenía abierto.

La casilla «Limpiar terminadas automáticamente», debajo del formato, está siempre a la vista, aunque
la cola esté vacía. Mientras está marcada, cada descarga que termina o se cancela
sale sola de la lista y el resumen la sigue contando; las que fallaron quedan, para poder reintentarlas.
Al marcarla también se limpia lo que ya había terminado. La aplicación recuerda la elección.

Los videos con «instrumental» en el título esperan en la cola, en pausa, salvo que esté marcada
«Descargar instrumentales». Una fila en pausa se puede bajar sola con su botón de descarga, y al
marcar la opción se reanudan todas.

El botón ⓘ de la ventana, o Haul > Acerca de Haul en la barra de menús, muestra la versión, qué
significa el nombre, el autor, la licencia y el enlace a este repositorio, en el idioma de la interfaz.
El encabezado con ese botón queda fijo arriba de la ventana y el resto se desplaza por debajo.

También se puede iniciar con enlaces desde la Terminal o desde Atajos:

```
open -a Haul --args --descargar URL1 URL2
```

## Formatos

| Formato | Resultado | Opciones de yt-dlp |
|---|---|---|
| Video | MP4 con H.264 y AAC, a la mayor resolución disponible en H.264 | `-f bv*+ba/b -S vcodec:h264,res,acodec:aac --merge-output-format mp4` |
| Solo audio | MP3 a la máxima calidad | `-x --audio-format mp3 --audio-quality 0` |

Se prefiere H.264 porque QuickTime y iOS lo reproducen sin conversión. Los archivos llevan el título del video como nombre.

## Listas de reproducción

Un enlace a una lista o a la página de un canal se lee primero, sin descargar nada, y cada video pasa a ser una fila propia de
la cola, con su miniatura y su posición («Mix · 3/12»). Los archivos van a una subcarpeta con el nombre
de la lista y se numeran en el orden de la lista: `01 - Título.mp4`, `02 - Título.mp4`, etcétera. Cada
video se puede cancelar o reintentar por separado. Una lista de más de 200 videos pide confirmación
antes de entrar a la cola.

Un enlace a un video abierto desde una lista muestra en la ventana una tarjeta
que pregunta si se baja solo ese video o la lista entera. Los demás enlaces se descargan tal cual, un video cada uno.

Algunas páginas de etiqueta que agrupan varias publicaciones, cada una con un video embebido, se leen
igual: una fila por publicación, de la más vieja a la más nueva, así una serie conserva el orden de
sus episodios.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `fuentes/Haul.swift` | Código de la aplicación (SwiftUI, un solo archivo) |
| `icono/icono.html` | Ícono en SVG |
| `icono/icono-1024.png` | Ícono renderizado, origen de todos los tamaños |
| `scripts/instalar.sh` | Dependencias, compilación e instalación |
| `scripts/compilar.sh` | Compilación y firma en `build/` |
| `scripts/firma.sh` | Identidad de firma local (la carga `compilar.sh`) |
| `scripts/manual.sh` | Genera los manuales en PDF a partir de los README |
| `scripts/actualizar-yt-dlp.sh` | Reemplaza el yt-dlp incluido por otra versión verificada |
| `plugins/haul/` | Complemento de extractores propio de Haul para yt-dlp, para enlaces que la versión incluida no maneja |
| `vendor/yt-dlp/` | Copia incluida de yt-dlp 2026.08.19, con código fuente, sumas, firma y licencias |
| `docs/Haul-manual-es.pdf`, `docs/Haul-manual-en.pdf` | Manuales en PDF, en castellano y en inglés |
| `docs/manual.css` | Estilo de los manuales |
| `README.es.md`, `README.md` | Esta documentación, en castellano y en inglés |

La carpeta `build/` se genera al compilar y no forma parte del repositorio.

## Firma y permisos

macOS guarda los permisos que el usuario concede, como el acceso a Descargas o al portapapeles,
asociados a la firma de la aplicación. Una firma ad hoc cambia en cada compilación y macOS vuelve a
pedirlos. Por eso el proyecto firma con un certificado propio y estable, «Haul (local
signing)», que `scripts/firma.sh` crea la primera vez en la Mac donde se compila:

- el certificado y su clave quedan en un llavero dedicado,
  `~/Library/Keychains/haul-signing.keychain-db`;
- la contraseña de ese llavero queda en el llavero de inicio de sesión, con el nombre
  `haul-local-signing`.

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

Haul está hecho y probado con yt-dlp 2026.08.19, y esa copia exacta viaja dentro de la
aplicación. Una versión fija mantiene estable el comportamiento y no depende de que el repositorio
de yt-dlp siga en línea. La contra es que los sitios cambian seguido y, tarde o temprano, una versión
fija deja de funcionar con ellos. Cuando eso pase, una versión nueva de Haul pasa a un yt-dlp
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

Las preferencias (idioma, carpeta, formato, tamaño de la ventana, «Limpiar terminadas automáticamente» y
«Descargar instrumentales») se guardan en el dominio
`io.github.gabriel-castiglia.haul`. Se restablecen con
`defaults delete io.github.gabriel-castiglia.haul`.

## Notas técnicas

La aplicación ejecuta el yt-dlp incluido con el Python de Homebrew, como proceso hijo, y agrega
`/opt/homebrew/bin` al `PATH`, ya que una aplicación abierta desde el Finder no hereda el de la
Terminal y no encontraría deno ni ffmpeg. Para no
depender del texto que yt-dlp imprime para la Terminal, le pide una salida con formato propio,
separada por tabuladores:

| Línea | Contenido | Origen |
|---|---|---|
| `META` | id, canal, autor, título y miniatura, que se revisan antes de bajar | `-O pre_process:…` |
| `INFO` | título, autor, duración, miniatura y nombre del archivo | `-O before_dl:…` |
| `AVANCE` | porcentaje, velocidad y tiempo restante | `--progress-template` |
| `ARCHIVO` | ruta final del archivo | `-O after_move:…` |

Los instrumentales en pausa se frenan con `--match-filters`, así yt-dlp no baja nada hasta que se
permiten.

Algunos enlaces fallan dentro del propio yt-dlp, incluso en su última versión: una página de video
que ahora pide una cuenta aunque su reproductor embebido no la pide, y páginas cuyos datos se
mudaron de lugar. Haul trae un complemento de extractores propio en `plugins/haul/`, que se copia a
`Contents/Resources/plugins` y se pasa con `--plugin-dirs`. Los extractores de un complemento se
prueban antes que los incluidos en yt-dlp, y cada uno solo toma los enlaces que arregla. Cuando el
reproductor embebido responde con un error 401 esporádico, el complemento reintenta hasta tres
veces. Python corre con `PYTHONDONTWRITEBYTECODE=1` para no escribir `__pycache__` dentro de la
aplicación firmada.

Compilar sin Xcode impone dos limitaciones, ya resueltas en el código. La primera es que el macro
`@State` de SwiftUI no está disponible, porque su plugin solo viene con Xcode; en su lugar se usa
`@StateObject` con la clase `Marca`. La segunda es que, con la barra de título oculta, SwiftUI
ignora `.defaultSize`, y el tamaño inicial de la ventana se fija desde AppKit en
`applicationDidFinishLaunching`.

## Créditos

Haul es una interfaz; el trabajo de fondo es de estos proyectos:

| Proyecto | Papel en Haul | Licencia |
|---|---|---|
| [yt-dlp](https://github.com/yt-dlp/yt-dlp), de los colaboradores de yt-dlp, fork de youtube-dl | Motor de descarga, incluido en `vendor/yt-dlp` | [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE) |
| [yt-dlp-ejs](https://github.com/yt-dlp/ejs), dentro del ejecutable de yt-dlp | Resuelve desafíos de JavaScript | Unlicense |
| [meriyah](https://github.com/meriyah/meriyah), de KFlash y otros, dentro de yt-dlp-ejs | Analizador de JavaScript | [ISC](https://github.com/meriyah/meriyah/blob/main/LICENSE.md) |
| [astring](https://github.com/davidbonnet/astring), de David Bonnet, dentro de yt-dlp-ejs | Generador de código JavaScript | [MIT](https://github.com/davidbonnet/astring/blob/main/LICENSE) |
| [FFmpeg](https://ffmpeg.org), instalado con Homebrew, no incluido | Une imagen y sonido, convierte a MP3 | [LGPL-2.1+ / GPL-2.0+](https://ffmpeg.org/legal.html), según la compilación |
| [Deno](https://deno.com), instalado con Homebrew | Intérprete de JavaScript que usa yt-dlp | [MIT](https://github.com/denoland/deno/blob/main/LICENSE.md) |
| [Python](https://www.python.org), instalado con Homebrew | Ejecuta yt-dlp | [Licencia PSF](https://docs.python.org/3/license.html) |
| [Homebrew](https://brew.sh) | Instala las dependencias | [BSD-2-Clause](https://github.com/Homebrew/brew/blob/master/LICENSE.txt) |
| [pandoc](https://pandoc.org), solo para generar los manuales en PDF | Conversión de Markdown a HTML | [GPL-2.0+](https://github.com/jgm/pandoc/blob/main/COPYRIGHT) |

Los textos de licencia de los componentes incluidos están en `vendor/yt-dlp/licenses/` y se copian
dentro de la aplicación, en `Contents/Resources/licenses/`.

## Licencia

Copyright (C) 2026 Gabriel Castiglia.

Haul es software libre, distribuido bajo la Licencia Pública General de GNU, versión 2
(GPL-2.0-only), la misma del núcleo Linux. Se puede usar, estudiar, modificar y redistribuir; toda
versión modificada que se distribuya debe publicarse bajo la misma licencia y con su código
fuente. El texto completo está en [`LICENSE`](LICENSE).

Haul incluye una copia sin modificar de yt-dlp en `vendor/yt-dlp`, que conserva sus propias
licencias (Unlicense, con componentes ISC y MIT) y no queda cubierta por la GPL. Haul ejecuta
yt-dlp y ffmpeg como programas aparte y no los enlaza; ffmpeg no se incluye.
