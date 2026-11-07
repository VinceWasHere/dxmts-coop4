# Seguridad: cómo comprobar que el mod no tiene virus

No hace falta fiarse de nadie: todo lo que hace el mod se puede revisar y comprobar.

## 1. No hay programas dentro

Los zips no traen ningún `.exe`, `.dll` ni otro programa compilado. Solo contienen:

| Archivo | Qué es |
|---|---|
| `coop4.py` (Linux) / `coop4.ps1` (Windows) | El instalador. Es texto plano y se puede abrir con el Bloc de notas. |
| `instalar-*`, `desinstalar-*` (`.sh` / `.bat`) | Accesos de una o dos líneas que llaman a ese script. |
| `mod/pakchunk99-Windows_P.*` | Datos del juego (una tabla, un mapa, una textura y un material). El juego los lee como contenido; no se ejecutan. |
| `LEEME.txt`, `LICENSE`, `AVISO-LEGAL.md`, `SEGURIDAD.md` | Texto. |

## 2. Qué hace el instalador, línea a línea

- Busca `Game/Binaries/Win64/Game-Win64-Shipping.exe` en la carpeta del juego.
- Comprueba que los bytes de 4 posiciones concretas son los esperados. Si uno solo no coincide, se detiene sin cambiar nada.
- La primera vez copia el ejecutable original a `_backup_coop4`.
- Cambia esos pocos bytes y copia los 3 archivos de `mod/` a `Game/Content/Paks`.
- **No se conecta a internet, no descarga nada, no pide por sí mismo permisos de administrador y no toca nada fuera de la carpeta del juego.** Puedes comprobarlo buscando en el script: no hay ninguna llamada de red.

El desinstalador hace lo contrario y deja el ejecutable idéntico al original, byte a byte.

## 3. Los zips salen de este código, sin cambios

GitHub construye los zips de cada release con [`herramientas/empaquetar.sh`](herramientas/empaquetar.sh), a partir de los archivos visibles de este repositorio.

Los zips son **reproducibles**: el mismo código produce siempre los mismos bytes. En Linux puedes construirlos tú con `sh herramientas/empaquetar.sh` y comparar la huella con `SHA256SUMS.txt` de la release. En la prueba, el zip construido en un PC con Fedora y el de GitHub dieron la misma huella.

## 4. Sumas de comprobación

Cada release incluye `SHA256SUMS.txt` con la huella SHA-256 de los dos zips. Calcula la de tu archivo y compárala con la de la release:

- **Windows (PowerShell):** `Get-FileHash DXMTS-Coop4-Windows.zip`
- **Linux:** `sha256sum DXMTS-Coop4-Linux.zip`

Si no coinciden, no lo uses: el archivo no es el publicado.

## 5. Análisis antivirus

Los dos zips de cada release se analizan en [VirusTotal](https://www.virustotal.com), que los pasa por unos 60 antivirus. Los enlaces a los informes están en el README y en las notas de cada release.

Si un antivirus marca algo, suele ser por el `.bat` que ejecuta PowerShell, un patrón que algunos antivirus tratan como sospechoso aunque el script sea inofensivo. Abre `coop4.ps1` y compruébalo tú mismo.

## Avisar de un problema de seguridad

Si encuentras algo sospechoso, abre un *issue* en este repositorio o escribe a [VinceWasHere](https://github.com/VinceWasHere) en GitHub.
