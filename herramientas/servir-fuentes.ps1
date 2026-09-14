# servir-fuentes.ps1 — HERRAMIENTA DE DESARROLLO, no entra al juego.
#
# Sirve los archivos de src/ por HTTP en localhost para que
# herramientas/instalar-desde-http.luau (ejecutado en la barra de comandos de
# Studio o por execute_luau) pueda crear el arbol del juego SIN el plugin de
# Rojo. Es un sustituto de emergencia de "rojo serve" + Connect; el flujo
# normal sigue siendo Rojo.
#
#   GET /index.json   lista de archivos bajo src/ (ruta relativa, bytes)
#   GET /src/...      contenido del archivo (UTF-8)
#
# Uso:  powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1
# Para parar: Ctrl+C (o cerrar la ventana).

param(
    [int]$Puerto = 8123
)

$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$srcDir = Join-Path $raiz "src"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Puerto/")
$listener.Start()
Write-Host "Sirviendo $srcDir en http://localhost:$Puerto/"

function Escribir($ctx, [string]$texto, [string]$tipo, [int]$codigo) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($texto)
    $ctx.Response.StatusCode = $codigo
    $ctx.Response.ContentType = $tipo
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $ruta = $ctx.Request.Url.AbsolutePath
    try {
        if ($ruta -eq "/index.json") {
            $archivos = Get-ChildItem -Path $srcDir -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($raiz.Length + 1).Replace("\", "/")
                '{"ruta":"' + $rel + '","bytes":' + $_.Length + '}'
            }
            Escribir $ctx ("[" + ($archivos -join ",") + "]") "application/json" 200
        }
        elseif ($ruta.StartsWith("/src/") -or $ruta.StartsWith("/herramientas/")) {
            $relativo = $ruta.Substring(1).Replace("/", "\")
            $completo = Join-Path $raiz $relativo
            if ((Test-Path $completo) -and $completo.StartsWith($raiz)) {
                $contenido = [System.IO.File]::ReadAllText($completo, [System.Text.Encoding]::UTF8)
                Escribir $ctx $contenido "text/plain; charset=utf-8" 200
            }
            else {
                Escribir $ctx "no existe" "text/plain" 404
            }
        }
        elseif ($ruta -eq "/ping") {
            Escribir $ctx "ok" "text/plain" 200
        }
        else {
            Escribir $ctx "404" "text/plain" 404
        }
    }
    catch {
        try { Escribir $ctx ("error: " + $_.Exception.Message) "text/plain" 500 } catch {}
    }
}
