# rojo-serve-bucle.ps1 — HERRAMIENTA DE DESARROLLO, no entra al juego.
#
# Lanza `rojo serve` y lo relanza si se cae. Rojo 7.7.0 (y 7.7.1) se cae a
# veces cuando un editor guarda con un archivo temporal y lo renombra (la
# herramienta Edit de los agentes lo hace): "called Result::unwrap() on an
# Err value ... NotFound ... change_processor.rs" (rojo-rbx/rojo#1338). El
# arreglo upstream (PR #1319) no está en ninguna versión oficial todavía.
#
# Uso, desde la raíz del repo:
#   powershell -ExecutionPolicy Bypass -File herramientas/rojo-serve-bucle.ps1
# Ctrl+C dos veces para pararlo (la primera corta rojo, la segunda el bucle).

$rojo = Join-Path $env:USERPROFILE '.aftman\bin\rojo.exe'
if (-not (Test-Path $rojo)) { $rojo = 'rojo' }

while ($true) {
	& $rojo serve default.project.json --port 34872
	Write-Host ("[{0:HH:mm:ss}] rojo serve terminó (código {1}); se relanza en 2 s" -f (Get-Date), $LASTEXITCODE) -ForegroundColor Yellow
	Start-Sleep -Seconds 2
}
