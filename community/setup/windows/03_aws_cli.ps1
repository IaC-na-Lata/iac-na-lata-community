# ============================================================
# AWS CLI v2 - Instalação automática no Windows (PowerShell)
# + Disponibiliza o comando no Git Bash (via .bashrc/.bash_profile)
#
# Como usar:
# 1) Abra o PowerShell COMO ADMINISTRADOR (recomendado)
# 2) Cole tudo e execute
# ============================================================

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

# --- 0) Verifica se está em modo Admin (MSI geralmente exige) ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
  Write-Warn "Você NÃO está em PowerShell como Administrador."
  Write-Warn "A instalação do MSI pode falhar por permissão."
  Write-Warn "Dica: clique com botão direito no PowerShell > Executar como administrador."
}

# --- 1) Baixa o instalador oficial (MSI) ---
$msiUrl  = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$tempDir = Join-Path $env:TEMP "awscliv2-install"
$msiPath = Join-Path $tempDir "AWSCLIV2.msi"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Info "Baixando AWS CLI v2: $msiUrl"
Invoke-WebRequest $msiUrl -OutFile $msiPath
Write-Ok "MSI baixado em: $msiPath"

# --- 2) Instala silenciosamente ---
Write-Info "Instalando AWS CLI v2 (silencioso)..."
$msiArgs = "/i `"$msiPath`" /qn /norestart"
$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

if ($proc.ExitCode -ne 0) {
  throw "Falha ao instalar AWS CLI v2. ExitCode=$($proc.ExitCode)"
}
Write-Ok "AWS CLI v2 instalado com sucesso."

# --- 3) Garante que o diretório do AWS CLI está no PATH do Windows ---
$awsDir = "C:\Program Files\Amazon\AWSCLIV2"
$awsExe = Join-Path $awsDir "aws.exe"

if (-not (Test-Path $awsExe)) {
  throw "Não encontrei o aws.exe em: $awsExe. Verifique se o instalador concluiu corretamente."
}

Write-Info "Verificando PATH do Windows (usuário)..."
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($null -eq $userPath) { $userPath = "" }

$pathParts = $userPath.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)

if ($pathParts -notcontains $awsDir) {
  $newUserPath = ($pathParts + $awsDir) -join ";"
  [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
  Write-Ok "Adicionado ao PATH do usuário: $awsDir"
} else {
  Write-Ok "Já existe no PATH do usuário: $awsDir"
}

# Atualiza o PATH na sessão atual do PowerShell (para validar sem reabrir)
if ($env:Path -notmatch [Regex]::Escape($awsDir)) {
  $env:Path = "$env:Path;$awsDir"
}

# --- 4) Disponibiliza no Git Bash (adiciona export PATH no .bashrc e .bash_profile) ---
# Git Bash geralmente usa HOME = C:\Users\<user>
$home = $env:USERPROFILE

# Linhas seguras (com espaços) para Git Bash
$bashLine = 'export PATH="$PATH:/c/Program Files/Amazon/AWSCLIV2"'

$bashrc       = Join-Path $home ".bashrc"
$bashProfile  = Join-Path $home ".bash_profile"

function Ensure-LineInFile($filePath, $line) {
  if (-not (Test-Path $filePath)) {
    New-Item -ItemType File -Path $filePath -Force | Out-Null
  }
  $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue
  if ($content -notcontains $line) {
    Add-Content -Path $filePath -Value "`n# Added by AWS CLI v2 setup`n$line`n"
    Write-Ok "Atualizado: $filePath"
  } else {
    Write-Ok "Já configurado: $filePath"
  }
}

Write-Info "Aplicando configuração para Git Bash..."
Ensure-LineInFile -filePath $bashrc      -line $bashLine
Ensure-LineInFile -filePath $bashProfile -line $bashLine

# --- 5) Validações ---
Write-Info "Validando no PowerShell..."
$awsVer = & $awsExe --version 2>&1
Write-Ok "PowerShell -> $awsVer"

Write-Info "Dica para validar no Git Bash:"
Write-Host "  1) Abra um novo Git Bash" -ForegroundColor Gray
Write-Host "  2) Rode: aws --version" -ForegroundColor Gray
Write-Host "  3) Se necessário: source ~/.bashrc" -ForegroundColor Gray

Write-Ok "Setup concluído."