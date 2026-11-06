# Instala Trilhas da Vida no Windows e cria o atalho na Área de Trabalho.
#
#   irm https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/install.ps1 | iex
#
# Instalar de um zip já baixado (sem internet):
#   $env:TRILHAS_ZIP = "C:\caminho\TrilhasDaVida-windows.zip"; irm <url do install.ps1> | iex
# Desinstalar: rode desinstalar.ps1 (mesmo endereço, trocando o nome do arquivo).
# Seu jogo salvo fica em %APPDATA%\Godot\app_userdata\Trilhas da Vida e não é apagado ao reinstalar.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # a barra de progresso deixa o download muito lento no PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$origem = 'https://github.com/kevrauzika/TrilhasDaVida-download/releases/latest/download/TrilhasDaVida-windows.zip'
if ($env:TRILHAS_ZIP) { $origem = $env:TRILHAS_ZIP }
$pasta = Join-Path $env:LOCALAPPDATA 'TrilhasDaVida'
$exe = Join-Path $pasta 'TrilhasDaVida.exe'
$atalho = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Trilhas da Vida.lnk'
$zip = Join-Path $env:TEMP "TrilhasDaVida-$PID.zip"

Write-Host ''
Write-Host '  Trilhas da Vida - instalador' -ForegroundColor Green
Write-Host ''

if (Get-Process -Name 'TrilhasDaVida' -ErrorAction SilentlyContinue) {
    Write-Host '  O jogo está aberto. Feche o jogo e rode o instalador de novo.' -ForegroundColor Yellow
    return
}

try {
    Write-Host '  [1/4] Baixando o jogo (cerca de 45 MB)...'
    if (Test-Path -LiteralPath $origem) {
        Copy-Item -LiteralPath $origem -Destination $zip
    } else {
        Invoke-WebRequest -Uri $origem -OutFile $zip -UseBasicParsing
    }

    Write-Host "  [2/4] Instalando em $pasta"
    New-Item -ItemType Directory -Force -Path $pasta | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $pasta -Force
    if (-not (Test-Path -LiteralPath $exe)) { throw 'o pacote baixado não tem TrilhasDaVida.exe' }

    Write-Host '  [3/4] Criando o atalho na Área de Trabalho'
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($atalho)
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = $pasta
    $lnk.IconLocation = "$exe,0"
    $lnk.Description = 'Trilhas da Vida'
    $lnk.Save()

    Write-Host '  [4/4] Pronto! Abra "Trilhas da Vida" na Área de Trabalho.' -ForegroundColor Green
    Write-Host ''
    Write-Host '  Para jogar com amigos: menu > Jogar com amigos. Na primeira vez que hospedar,'
    Write-Host '  o Windows pergunta sobre o firewall: clique em "Permitir acesso".'
    Write-Host ''
} catch {
    Write-Host "  Não deu certo: $($_.Exception.Message)" -ForegroundColor Red
    if ($origem -like 'http*') {
        Write-Host '  Confira a internet e se o repositório/Release está público.' -ForegroundColor Red
    }
} finally {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
}
