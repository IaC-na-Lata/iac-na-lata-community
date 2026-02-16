# ============================================================
# WSL2 + UBUNTU + TFENV + TERRAFORM
# EXECUTAR COMO ADMINISTRADOR
# ============================================================

$ErrorActionPreference = "Stop"

$LinuxUser     = $env:LINUX_USER
$LinuxPassword = $env:LINUX_PASS

if (-not $LinuxUser -or -not $LinuxPassword) {
    Write-Host "ERRO: Defina LINUX_USER e LINUX_PASS antes." -ForegroundColor Red
    exit 1
}

Write-Host "==== CHECANDO UBUNTU NO WSL ====" -ForegroundColor Cyan

$distros   = & wsl.exe -l -q 2>$null
$hasUbuntu = $false

foreach ($d in $distros) {
    if ($d.Trim() -eq "Ubuntu") {
        $hasUbuntu = $true
    }
}

if (-not $hasUbuntu) {
    Write-Host "Ubuntu não encontrado. Instalando..." -ForegroundColor Yellow
    & wsl.exe --install -d Ubuntu
    Write-Host "Reinicie e execute novamente o script." -ForegroundColor Yellow
    exit 0
}

# Configuração do usuário Linux
$env:TFENV_LINUX_USER = $LinuxUser
$env:TFENV_LINUX_PASS = $LinuxPassword

& wsl.exe -d Ubuntu -- bash -lc @'
set -e
U="$TFENV_LINUX_USER"
P="$TFENV_LINUX_PASS"

if ! id -u "$U" >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash "$U"
    printf "%s:%s\n" "$U" "$P" | sudo chpasswd
    sudo usermod -aG sudo "$U"
fi
'@

& wsl.exe -d Ubuntu --set-default-user $LinuxUser

# Atualização e dependências
& wsl.exe -d Ubuntu -- bash -lc @'
set -e
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y git curl unzip ca-certificates build-essential
'@

# Instala tfenv
& wsl.exe -d Ubuntu -- bash -lc @'
set -e
if [ ! -d "$HOME/.tfenv" ]; then
    git clone --depth=1 https://github.com/tfutils/tfenv.git "$HOME/.tfenv"
fi

grep -qxF 'export PATH="$HOME/.tfenv/bin:$PATH"' "$HOME/.bashrc" || \
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> "$HOME/.bashrc"

export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install latest
tfenv use latest
terraform -version
'@

Write-Host "SETUP FINALIZADO 🚀" -ForegroundColor Green