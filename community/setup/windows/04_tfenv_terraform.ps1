#requires -RunAsAdministrator
[CmdletBinding(DefaultParameterSetName = "Secure")]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$LinuxUser,

  [Parameter(Mandatory = $true, ParameterSetName = "Secure")]
  [Security.SecureString]$LinuxPassword,

  [Parameter(Mandatory = $true, ParameterSetName = "Plain")]
  [ValidateNotNullOrEmpty()]
  [string]$LinuxPasswordPlain,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$PreferredDistro = "Ubuntu",

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$TerraformVersion = "latest",

  [Parameter()]
  [switch]$SkipWindowsShims
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-SecureStringToPlainText {
  param([Parameter(Mandatory = $true)][Security.SecureString]$SecureString)
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Ensure-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Execute este script como Administrador."
  }
}

function Get-InstalledWslDistros {
  $lines = & wsl.exe -l -q 2>$null
  if (-not $lines) { return @() }
  return @($lines | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Resolve-DistroName {
  param(
    [Parameter(Mandatory = $true)][string]$Preferred,
    [Parameter(Mandatory = $true)][string[]]$Installed
  )

  if ($Installed -contains $Preferred) { return $Preferred }

  if ($Preferred -eq "Ubuntu") {
    $candidate = $Installed | Where-Object { $_ -match "^Ubuntu($|[- ].*)" } | Select-Object -First 1
    if ($candidate) { return $candidate }
  }

  return $null
}

function Ensure-UbuntuInstalled {
  param([Parameter(Mandatory = $true)][string]$Preferred)

  $installed = Get-InstalledWslDistros
  $resolved = Resolve-DistroName -Preferred $Preferred -Installed $installed
  if ($resolved) { return $resolved }

  Write-Host "Distro '$Preferred' nao encontrada. Instalando via WSL..." -ForegroundColor Yellow
  & wsl.exe --install -d $Preferred | Out-Host
  $exitCode = $LASTEXITCODE

  if ($exitCode -ne 0) {
    throw "Falha ao executar 'wsl --install -d $Preferred'. ExitCode=$exitCode"
  }

  $installedAfter = Get-InstalledWslDistros
  $resolvedAfter = Resolve-DistroName -Preferred $Preferred -Installed $installedAfter
  if (-not $resolvedAfter) {
    throw "WSL/Ubuntu iniciado para instalacao, mas a distro ainda nao aparece. Normalmente requer reboot. Execute novamente apos reiniciar."
  }

  return $resolvedAfter
}

function Invoke-WslBash {
  param(
    [Parameter(Mandatory = $true)][string]$Distro,
    [Parameter(Mandatory = $true)][string]$Script,
    [Parameter()][string]$User = "root"
  )
  & wsl.exe -d $Distro -u $User -- bash -lc $Script
  if ($LASTEXITCODE -ne 0) {
    throw "Comando WSL falhou no distro '$Distro' (exit code $LASTEXITCODE)."
  }
}

function Ensure-WindowsShims {
  param([Parameter(Mandatory = $true)][string]$Distro)

  $shimDir = Join-Path $env:LOCALAPPDATA "tfenv-shims"
  New-Item -ItemType Directory -Force -Path $shimDir | Out-Null

  @"
@echo off
wsl.exe -d $Distro -e bash -lc "tfenv %*"
"@ | Set-Content -Encoding ASCII -Path (Join-Path $shimDir "tfenv.cmd")

  @"
@echo off
wsl.exe -d $Distro -e bash -lc "terraform %*"
"@ | Set-Content -Encoding ASCII -Path (Join-Path $shimDir "terraform.cmd")

  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ([string]::IsNullOrWhiteSpace($userPath)) {
    [Environment]::SetEnvironmentVariable("Path", $shimDir, "User")
    $env:Path = "$shimDir;$env:Path"
    return
  }

  if ($userPath -notlike "*$shimDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$shimDir;$userPath", "User")
    $env:Path = "$shimDir;$env:Path"
  }
}

Ensure-Administrator

if ($PSCmdlet.ParameterSetName -eq "Plain") {
  $LinuxPassword = ConvertTo-SecureString -String $LinuxPasswordPlain -AsPlainText -Force
}

$plainPassword = Convert-SecureStringToPlainText -SecureString $LinuxPassword

$env:TFENV_LINUX_USER = $LinuxUser
$env:TFENV_LINUX_PASS = $plainPassword
$env:TFENV_VERSION = $TerraformVersion

try {
  $resolvedDistro = Ensure-UbuntuInstalled -Preferred $PreferredDistro
  Write-Host "Usando distro: $resolvedDistro" -ForegroundColor Cyan

  $setupScript = @'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

retry() {
  local attempts=5
  local n=1
  until "$@"; do
    if [ "$n" -ge "$attempts" ]; then
      echo "Falha apos $attempts tentativas: $*" >&2
      return 1
    fi
    n=$((n+1))
    sleep 5
  done
}

U="${TFENV_LINUX_USER}"
P="${TFENV_LINUX_PASS}"
TV="${TFENV_VERSION}"

if ! id -u "$U" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$U"
fi
printf "%s:%s\n" "$U" "$P" | chpasswd
usermod -aG sudo "$U" || true

cat >/etc/wsl.conf <<EOF
[user]
default=$U
EOF

retry apt-get update -y
retry apt-get install -y git curl unzip ca-certificates build-essential

sudo -u "$U" -H bash -lc '
set -euo pipefail
if [ ! -d "$HOME/.tfenv" ]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git "$HOME/.tfenv"
else
  git -C "$HOME/.tfenv" pull --ff-only || true
fi

if ! grep -q "tfenv/bin" "$HOME/.bashrc" 2>/dev/null; then
  printf "\n# tfenv\nexport PATH=\"\$HOME/.tfenv/bin:\$PATH\"\n" >> "$HOME/.bashrc"
fi

export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install "$TV"
tfenv use "$TV"
tfenv --version
terraform -version
'
'@

  Invoke-WslBash -Distro $resolvedDistro -User "root" -Script $setupScript

  if (-not $SkipWindowsShims) {
    Ensure-WindowsShims -Distro $resolvedDistro
  }

  & wsl.exe --terminate $resolvedDistro 2>$null | Out-Null

  Write-Host ""
  Write-Host "Setup concluido com sucesso." -ForegroundColor Green
  Write-Host "Usuario Linux default: $LinuxUser" -ForegroundColor Green
  if (-not $SkipWindowsShims) {
    Write-Host "Shims Windows: $env:LOCALAPPDATA\tfenv-shims" -ForegroundColor Green
  }
  Write-Host "Reabra o PowerShell antes de usar os comandos tfenv/terraform via PATH atualizado."
}
finally {
  Remove-Item Env:TFENV_LINUX_USER -ErrorAction SilentlyContinue
  Remove-Item Env:TFENV_LINUX_PASS -ErrorAction SilentlyContinue
  Remove-Item Env:TFENV_VERSION -ErrorAction SilentlyContinue
  $plainPassword = $null
}