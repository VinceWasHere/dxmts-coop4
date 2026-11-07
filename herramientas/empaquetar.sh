#!/bin/sh
# Crea dist/DXMTS-Coop4-Windows.zip, dist/DXMTS-Coop4-Linux.zip y dist/SHA256SUMS.txt
# a partir de los archivos del repositorio. Lo usa la release de GitHub Actions.
set -eu
cd "$(dirname "$0")/.."
rm -rf dist && mkdir -p dist
comunes="LEEME.txt LICENSE AVISO-LEGAL.md SEGURIDAD.md mod"
paquete() {
    d=dist/tmp-$1/DXMTS-Coop4
    mkdir -p "$d"
    shift
    for f in $comunes "$@"; do cp -pR "$f" "$d/"; done
    # fecha fija: el mismo repositorio produce siempre los mismos bytes
    find "$d" -exec touch -h -d 2026-01-01T00:00:00Z {} +
}
paquete win Instalar-Windows.bat Desinstalar-Windows.bat coop4.ps1
paquete lin instalar-linux.sh desinstalar-linux.sh coop4.py
(cd dist/tmp-win && find DXMTS-Coop4 | LC_ALL=C sort | TZ=UTC zip -qX -@ ../DXMTS-Coop4-Windows.zip)
(cd dist/tmp-lin && find DXMTS-Coop4 | LC_ALL=C sort | TZ=UTC zip -qX -@ ../DXMTS-Coop4-Linux.zip)
rm -rf dist/tmp-win dist/tmp-lin
(cd dist && sha256sum DXMTS-Coop4-Windows.zip DXMTS-Coop4-Linux.zip > SHA256SUMS.txt && cat SHA256SUMS.txt)
