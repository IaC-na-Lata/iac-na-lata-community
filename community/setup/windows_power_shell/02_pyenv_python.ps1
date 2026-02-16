param(
  [string]$PyenvWinTag = "v3.1.1",
  [string]$PythonVersion = "3.10.5",
  [switch]$ReinstallPyenvWin = $true
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==== PYENV-WIN SETUP (PowerShell) ====" -ForegroundColor Cyan

# Paths base
$base      = Join-Path $env:USERPROFILE ".pyenv"
$pyenvHome = Join-Path $base "pyenv-win"
$bin       = Join-Path $pyenvHome "bin"
$shims     = Join-Path $pyenvHome "shims"
$pyenvBat  = Join-Path $bin "pyenv.bat"

Write-Host "pyenvHome: $pyenvHome" -ForegroundColor Yellow
Write-Host "Python padrão: $PythonVersion" -ForegroundColor Yellow

# ===============================
# 1) Instala/Reinstala pyenv-win
# ===============================
if ($ReinstallPyenvWin -and (Test-Path $base)) {
    Remove-Item $base -Recurse -Force
}

if (!(Test-Path $pyenvHome)) {

    New-Item -ItemType Directory -Force -Path $pyenvHome | Out-Null

    $zipUrl = "https://github.com/pyenv-win/pyenv-win/archive/refs/tags/$PyenvWinTag.zip"
    $zipOut = Join-Path $env:TEMP "pyenv-win.zip"
    $extractRoot = Join-Path $env:TEMP ("pyenv-extract-" + [guid]::NewGuid().ToString("N"))

    Invoke-WebRequest -Uri $zipUrl -OutFile $zipOut
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    Expand-Archive -Path $zipOut -DestinationPath $extractRoot -Force
    Remove-Item $zipOut -Force

    $tagNoV = $PyenvWinTag.TrimStart("v")
    $src = Join-Path $extractRoot ("pyenv-win-$tagNoV\pyenv-win")

    if (!(Test-Path $src)) {
        throw "Estrutura inesperada do zip."
    }

    Copy-Item -Path (Join-Path $src "*") -Destination $pyenvHome -Recurse -Force
    Remove-Item $extractRoot -Recurse -Force
}

if (!(Test-Path $pyenvBat)) {
    throw "pyenv.bat não encontrado. Instalação incompleta."
}

Write-Host "pyenv-win OK." -ForegroundColor Green

# ===============================
# 2) Configurar Variáveis + PATH
# ===============================
[Environment]::SetEnvironmentVariable("PYENV_HOME", $pyenvHome, "User")
[Environment]::SetEnvironmentVariable("PYENV_ROOT", $pyenvHome, "User")
[Environment]::SetEnvironmentVariable("PYENV",      $pyenvHome, "User")

function Prepend-PathUser([string[]]$paths) {
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if ([string]::IsNullOrWhiteSpace($userPath)) { $userPath = "" }

    $parts = $userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne "" }
    $parts = $parts | Where-Object {
        $keep = $true
        foreach ($p in $paths) {
            if ($_.Trim().ToLower() -eq $p.ToLower()) { $keep = $false }
        }
        $keep
    }

    $newPath = ($paths + $parts) -join ';'
    [Environment]::SetEnvironmentVariable("Path",$newPath,"User")
}

Prepend-PathUser @($bin,$shims)

# Atualiza sessão atual
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path","User")

Write-Host "PATH atualizado." -ForegroundColor Green

# ===============================
# 3) Instalar Python 3.10.5
# ===============================
Write-Host "Instalando Python $PythonVersion..." -ForegroundColor Cyan

Push-Location $env:USERPROFILE
try {

    # Limpa precedência
    Remove-Item Env:PYENV_VERSION -ErrorAction SilentlyContinue
    Remove-Item Env:PYENV_DIR -ErrorAction SilentlyContinue

    & $pyenvBat install -s $PythonVersion
    & $pyenvBat global $PythonVersion
    & $pyenvBat rehash
}
finally {
    Pop-Location
}

# ===============================
# 4) Validação Forte (sem PATH)
# ===============================
$pythonExe = Join-Path $pyenvHome ("versions\$PythonVersion\python.exe")

if (!(Test-Path $pythonExe)) {
    throw "Python não foi instalado corretamente."
}

Write-Host "Python instalado:" -ForegroundColor Yellow
& $pythonExe --version

Write-Host "`n==== Validação via PATH ====" -ForegroundColor Cyan

try {
    python --version
}
catch {
    Write-Host "Alias Microsoft Store pode estar ativo." -ForegroundColor Yellow
}

Write-Host "`n✅ Setup PowerShell concluído com sucesso." -ForegroundColor Green