# yt-dlp 2026.08.19, copia incluida

[English](README.md) · Español

Esta carpeta contiene una copia sin modificar de [yt-dlp](https://github.com/yt-dlp/yt-dlp),
versión 2026.08.19. Haul está hecho y probado con esa versión exacta y la ejecuta desde
dentro de la aplicación. Así su comportamiento no cambia cuando yt-dlp publica una versión nueva, y
el proyecto sigue funcionando aunque el repositorio original deje de estar disponible.

| Archivo | Contenido |
|---|---|
| `yt-dlp` | Ejecutable zipimport oficial, independiente de la plataforma; necesita Python 3.10 o posterior |
| `yt-dlp.tar.gz` | Código fuente oficial de la misma versión |
| `SHA2-256SUMS`, `SHA2-256SUMS.sig` | Sumas de verificación oficiales de la versión y su firma |
| `public.key` | Clave pública de firma de yt-dlp |
| `VERSION` | Versión incluida; la lee `scripts/compilar.sh` |
| `licenses/` | Textos de licencia y lista de autores de yt-dlp |

## Procedencia

Los archivos se descargaron el 19 de octubre de 2026 de la
[versión 2026.08.19](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19). Las sumas SHA-256 de
`yt-dlp` y `yt-dlp.tar.gz` coinciden con `SHA2-256SUMS`, y la firma de ese archivo se verificó con
la clave de firma de yt-dlp `AC0C BBE6 848D 6A87 3464 AF4E 57CF 6593 3B5A 7581` (Simon Sawicki).
`scripts/compilar.sh` vuelve a comprobar la suma de `yt-dlp` en cada compilación.

Para verificarlo a mano:

```
gpg --import public.key
gpg --verify SHA2-256SUMS.sig SHA2-256SUMS
shasum -a 256 --ignore-missing -c SHA2-256SUMS
```

## Créditos y licencias

yt-dlp lo desarrollan los colaboradores de yt-dlp (ver `licenses/yt-dlp-AUTHORS`) y es un fork de
youtube-dl. Es de dominio público, bajo la
[Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE) (`licenses/yt-dlp-LICENSE`).

El ejecutable zipimport y el código fuente incluyen además
[yt-dlp-ejs](https://github.com/yt-dlp/ejs) (Unlicense), que a su vez contiene:

- [meriyah](https://github.com/meriyah/meriyah), licencia ISC, copyright de KFlash y otros
  (`licenses/meriyah-LICENSE.md`);
- [astring](https://github.com/davidbonnet/astring), licencia MIT, copyright de David Bonnet
  (`licenses/astring-LICENSE`).

Estos archivos conservan sus propias licencias; la licencia GPL-2.0-only de Haul no se les
aplica.

## Actualización

`scripts/actualizar-yt-dlp.sh <versión>` descarga otra versión, verifica su firma y sus sumas, y
reemplaza los archivos de esta carpeta. Después hay que revisar los textos de licencia de terceros
contra el README de la versión nueva.
