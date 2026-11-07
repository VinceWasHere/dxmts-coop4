# Coop de Escenario a 4 jugadores y escalado para el 4.o jugador.
# Uso: coop4.ps1 estado|aplicar|revertir   (misma logica que coop4.py; ahi esta el detalle de cada cambio)
param([string]$Orden = 'estado')
$ErrorActionPreference = 'Stop'

# nombre, offset en el fichero, bytes originales, bytes parcheados
$Parches = @(
    @('sala', 0x5414A40, '0fb69121050000b80600000080ea02b90300000080fa020f47c1c3cccccccccc',
                         '0fb69121050000b80400000084d2740e80ea0280fa0319c083e00383c003c3cc'),
    @('rompibles', 0x521DC82, '0fb6c883e901741c83e901740e83f9017512488b82c0070000eb10488b82b8070000eb07488b82b0070000',
                              '0fb6c8488b82b007000083f902721a488b82b80700007411488b82c007000083f9047205480fbae8219090'),
    @('tope', 0x55D5AD1, '448b2285c9780f3b0deae157047d074863c1448b2482',
                         '41bc0a00000083f90473074863c1448b248290909090'),
    @('coloc', 0x4D9876D, '0f85cc000000', '0f8ccc000000')
)
$Pak = 'pakchunk99-Windows_P.pak', 'pakchunk99-Windows_P.ucas', 'pakchunk99-Windows_P.utoc'

function Bytes($h) { [byte[]](0..($h.Length / 2 - 1) | ForEach-Object { [Convert]::ToByte($h.Substring($_ * 2, 2), 16) }) }

# Devuelve un hashtable nombre -> original|parcheado, o $null si la version no coincide.
function Estado($exe) {
    $res = [ordered]@{}
    $f = [IO.File]::OpenRead($exe)
    try {
        foreach ($p in $Parches) {
            $n = $p[2].Length / 2; $v = New-Object byte[] $n
            [void]$f.Seek($p[1], 'Begin'); [void]$f.Read($v, 0, $n)
            $h = -join ($v | ForEach-Object { $_.ToString('x2') })
            if ($h -eq $p[2]) { $res[$p[0]] = 'original' }
            elseif ($h -eq $p[3]) { $res[$p[0]] = 'parcheado' }
            else { return $null }
        }
    } finally { $f.Close() }
    return $res
}

function Escribir($exe, $cual) {
    $f = [IO.File]::Open($exe, 'Open', 'ReadWrite', 'None')
    try {
        foreach ($p in $Parches) {
            $b = [byte[]](Bytes $(if ($cual -eq 'original') { $p[2] } else { $p[3] }))
            [void]$f.Seek($p[1], 'Begin'); $f.Write($b, 0, $b.Length)
        }
        $f.Flush()
    } finally { $f.Close() }
    if (@((Estado $exe).Values | Where-Object { $_ -ne $cual }).Count -ne 0) { throw 'La comprobacion tras escribir ha fallado.' }
}

try {
    if ($Orden -notin 'estado', 'aplicar', 'revertir') { throw 'Uso: coop4.ps1 estado|aplicar|revertir' }
    $ruta = 'Game/Binaries/Win64/Game-Win64-Shipping.exe'
    # Vale tanto dentro de la carpeta del juego como en una subcarpeta suya.
    $raiz = $PSScriptRoot, (Split-Path $PSScriptRoot -Parent) | Where-Object { Test-Path -LiteralPath (Join-Path $_ $ruta) } | Select-Object -First 1
    if (-not $raiz) { throw 'No encuentro el juego. Descomprime esta carpeta dentro de la carpeta del juego.' }
    $exe = Join-Path $raiz $ruta
    $paks = Join-Path $raiz 'Game/Content/Paks'
    $mod = Join-Path $PSScriptRoot 'mod'

    $est = Estado $exe
    if ($null -eq $est) { throw 'Version del juego no reconocida; no se ha tocado nada.' }
    foreach ($k in $est.Keys) { '  {0,-10} {1}' -f $k, $est[$k] }
    $pakOk = @($Pak | Where-Object { -not (Test-Path -LiteralPath (Join-Path $paks $_)) }).Count -eq 0
    '  pak        ' + $(if ($pakOk) { 'instalado' } else { 'no instalado' })
    'SHA-256: ' + (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLower()
    $valores = @($est.Values)

    if ($Orden -eq 'aplicar') {
        if (@($Pak | Where-Object { -not (Test-Path -LiteralPath (Join-Path $mod $_)) }).Count -ne 0) { throw 'Falta la carpeta mod del zip; no se ha tocado nada.' }
        if (@($valores | Where-Object { $_ -ne 'parcheado' }).Count -ne 0) {
            if (@($valores | Where-Object { $_ -ne 'original' }).Count -eq 0) {
                $destino = Join-Path $raiz ('_backup_coop4/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
                [void](New-Item -ItemType Directory -Path $destino)
                Copy-Item -LiteralPath $exe -Destination $destino
                "Copia de seguridad: $destino"
            }
            Escribir $exe 'parcheado'
        }
        foreach ($p in $Pak) { Copy-Item -LiteralPath (Join-Path $mod $p) -Destination (Join-Path $paks $p) -Force }
        'Aplicado: Escenario para 4 jugadores con escalado completado.'
    } elseif ($Orden -eq 'revertir') {
        if (@($valores | Where-Object { $_ -ne 'original' }).Count -ne 0) { Escribir $exe 'original' }
        foreach ($p in $Pak) { $r = Join-Path $paks $p; if (Test-Path -LiteralPath $r) { Remove-Item -LiteralPath $r } }
        'Revertido: el juego vuelve a su estado original.'
    }
} catch {
    "ERROR: $($_.Exception.Message)"
    exit 1
}
