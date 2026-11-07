#!/usr/bin/env python3
"""Coop de Escenario a 4 jugadores y escalado para el 4.o jugador.

Uso:  python3 coop4.py estado|aplicar|revertir

Cambios en el ejecutable (los modos de batalla/PvP no cambian):
  sala       maximo de la sala de Escenario: 3 -> 4.
  rompibles  objetos rompibles: con 4 jugadores el juego usaba la fila de
             1 jugador; ahora usa la fila de 4 que anade el pak del mod.
  tope       tope de enemigos/actores activos por zona (5/5/6/8 segun 1-4
             jugadores): con 4 caia a 5; ahora 10.
  coloc      colocacion lateral por jugador: con 4 no habia hueco y quedaban
             en el mismo sitio; ahora usa el reparto de 3.
Y copia el pak del mod (tabla con la fila de 4 jugadores y 4.o soporte del
hangar) a Game/Content/Paks.

Todos los jugadores de la sala deben aplicarlo. Si la version del juego no
coincide, el script no toca nada.
"""
import hashlib
import os
import shutil
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
RUTA_EXE = os.path.join("Game", "Binaries", "Win64", "Game-Win64-Shipping.exe")
# Vale tanto dentro de la carpeta del juego como en una subcarpeta suya.
DIR = next((d for d in (AQUI, os.path.dirname(AQUI)) if os.path.isfile(os.path.join(d, RUTA_EXE))), AQUI)
EXE = os.path.join(DIR, RUTA_EXE)
PAKS = os.path.join(DIR, "Game", "Content", "Paks")
MOD = os.path.join(AQUI, "mod")
PAK = ["pakchunk99-Windows_P" + e for e in (".pak", ".ucas", ".utoc")]
BACKUP = os.path.join(DIR, "_backup_coop4")

# (nombre, offset en el fichero, bytes originales, bytes parcheados)
PARCHES = [
    ("sala", 0x5414A40,
     "0fb69121050000"   # movzx edx, byte [rcx+0x521]  ; modo de la sala
     "b806000000"       # mov eax, 6
     "80ea02"           # sub dl, 2
     "b903000000"       # mov ecx, 3
     "80fa02"           # cmp dl, 2
     "0f47c1"           # cmova eax, ecx
     "c3cccccccccc",    # ret + relleno
     "0fb69121050000"   # movzx edx, byte [rcx+0x521]
     "b804000000"       # mov eax, 4
     "84d2"             # test dl, dl
     "740e"             # je fin                       ; modo 0 = Escenario -> 4
     "80ea02"           # sub dl, 2
     "80fa03"           # cmp dl, 3
     "19c0"             # sbb eax, eax
     "83e003"           # and eax, 3
     "83c003"           # add eax, 3                   ; modos 2-4 -> 6, resto -> 3
     "c3cc"),           # fin: ret
    ("rompibles", 0x521DC82,
     "0fb6c883e901741c83e901740e83f9017512488b82c0070000eb10488b82b8070000eb07488b82b0070000",
     "0fb6c8"           # movzx ecx, al                ; jugadores
     "488b82b0070000"   # mov rax, [rdx+0x7b0]         ; fila de 1
     "83f902"           # cmp ecx, 2
     "721a"             # jb fin
     "488b82b8070000"   # mov rax, [rdx+0x7b8]         ; fila de 2
     "7411"             # je fin
     "488b82c0070000"   # mov rax, [rdx+0x7c0]         ; fila de 3
     "83f904"           # cmp ecx, 4
     "7205"             # jb fin
     "480fbae821"       # bts rax, 33                  ; 4+: misma fila con sufijo _1 (pak)
     "9090"),           # fin
    ("tope", 0x55D5AD1,
     "448b2285c9780f3b0deae157047d074863c1448b2482",
     "41bc0a000000"     # mov r12d, 10                 ; 4+ jugadores
     "83f904"           # cmp ecx, 4
     "7307"             # jae fin
     "4863c1"           # movsxd rax, ecx
     "448b2482"         # mov r12d, [rdx+rax*4]        ; 1-3: valor del juego
     "90909090"),       # fin
    ("coloc", 0x4D9876D,
     "0f85cc000000",    # jne (solo 3 jugadores)
     "0f8ccc000000"),   # jl  (3 o mas)
]


def leer():
    with open(EXE, "rb") as f:
        return f.read()


def estado(datos):
    """Devuelve {nombre: 'original'|'parcheado'} o None si la version no coincide."""
    res = {}
    for nombre, off, orig, parch in PARCHES:
        actual = datos[off:off + len(orig) // 2].hex()
        if actual == orig:
            res[nombre] = "original"
        elif actual == parch:
            res[nombre] = "parcheado"
        else:
            return None
    return res


def escribir(datos, cual):
    nuevo = bytearray(datos)
    for nombre, off, orig, parch in PARCHES:
        b = bytes.fromhex(orig if cual == "original" else parch)
        nuevo[off:off + len(b)] = b
    tmp = EXE + ".coop4.tmp"
    with open(tmp, "wb") as f:
        f.write(nuevo)
    shutil.copymode(EXE, tmp)
    os.replace(tmp, EXE)
    if set(estado(leer()).values()) != {cual}:
        sys.exit("ERROR: la comprobacion tras escribir ha fallado.")


def pak_instalado():
    return all(os.path.isfile(os.path.join(PAKS, p)) for p in PAK)


def main():
    orden = sys.argv[1] if len(sys.argv) > 1 else "estado"
    if orden not in ("estado", "aplicar", "revertir"):
        sys.exit(__doc__)
    if not os.path.isfile(EXE):
        sys.exit(f"ERROR: no encuentro {EXE}. Descomprime esta carpeta dentro de la carpeta del juego.")

    datos = leer()
    est = estado(datos)
    if est is None:
        sys.exit("ERROR: version del juego no reconocida; no se ha tocado nada.")

    for nombre, valor in est.items():
        print(f"  {nombre:10} {valor}")
    print("  pak        " + ("instalado" if pak_instalado() else "no instalado"))
    print("SHA-256:", hashlib.sha256(datos).hexdigest())

    if orden == "aplicar":
        if not all(os.path.isfile(os.path.join(MOD, p)) for p in PAK):
            sys.exit("ERROR: falta la carpeta mod del zip; no se ha tocado nada.")
        if set(est.values()) != {"parcheado"}:
            if set(est.values()) == {"original"}:
                destino = os.path.join(BACKUP, time.strftime("%Y%m%d-%H%M%S"))
                os.makedirs(destino)
                shutil.copy2(EXE, destino)
                print("Copia de seguridad:", destino)
            escribir(datos, "parcheado")
        for p in PAK:
            shutil.copyfile(os.path.join(MOD, p), os.path.join(PAKS, p))
        print("Aplicado: Escenario para 4 jugadores con escalado completado.")
    elif orden == "revertir":
        if set(est.values()) != {"original"}:
            escribir(datos, "original")
        for p in PAK:
            if os.path.isfile(os.path.join(PAKS, p)):
                os.remove(os.path.join(PAKS, p))
        print("Revertido: el juego vuelve a su estado original.")


if __name__ == "__main__":
    main()
