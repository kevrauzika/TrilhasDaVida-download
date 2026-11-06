# Remove Trilhas da Vida (pasta do jogo e atalho da Área de Trabalho).
#   irm https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/desinstalar.ps1 | iex
# O jogo salvo (%APPDATA%\Godot\app_userdata\Trilhas da Vida) é mantido.

$pasta = Join-Path $env:LOCALAPPDATA 'TrilhasDaVida'
$atalho = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Trilhas da Vida.lnk'
if (Get-Process -Name 'TrilhasDaVida' -ErrorAction SilentlyContinue) {
    Write-Host 'Feche o jogo antes de desinstalar.' -ForegroundColor Yellow
    return
}
if (Test-Path -LiteralPath $atalho) { Remove-Item -LiteralPath $atalho -Force }
if (Test-Path -LiteralPath (Join-Path $pasta 'TrilhasDaVida.exe')) { Remove-Item -LiteralPath $pasta -Recurse -Force }
Write-Host 'Trilhas da Vida foi removido. Seu jogo salvo continua guardado.' -ForegroundColor Green
