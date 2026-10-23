# Trae al frente y maximiza la ventana del place en Roblox Studio.
# Por que: con Studio detras de otra ventana, la vista 3D no se pinta y
# screen_capture (MCP) sale negro. Lanzarlo desde el panel de Terminal
# (run_in_terminal), no desde la shell aislada de una sesion: alli Windows no
# deja pasar el primer plano.
#   powershell -ExecutionPolicy Bypass -File herramientas/studio-al-frente.ps1
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Ventana {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@
$p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "No hay ventana de Studio"; exit 1 }
[void][Ventana]::ShowWindow($p.MainWindowHandle, 3)   # SW_MAXIMIZE
$ok = [Ventana]::SetForegroundWindow($p.MainWindowHandle)
Start-Sleep -Milliseconds 500
$alFrente = [Ventana]::GetForegroundWindow() -eq $p.MainWindowHandle
"Studio '$($p.MainWindowTitle)': SetForegroundWindow=$ok, al frente=$alFrente"
