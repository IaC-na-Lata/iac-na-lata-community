# ============================================================
# TFENV/TERRAFORM no PowerShell usando WSL
# ============================================================

$shimDir = Join-Path $env:LOCALAPPDATA "tfenv-shims"
New-Item -ItemType Directory -Force -Path $shimDir | Out-Null

@"
@echo off
wsl.exe -d Ubuntu -e bash -ic "tfenv %*"
"@ | Set-Content -Encoding ASCII -Path (Join-Path $shimDir "tfenv.cmd")

@"
@echo off
wsl.exe -d Ubuntu -e bash -ic "terraform %*"
"@ | Set-Content -Encoding ASCII -Path (Join-Path $shimDir "terraform.cmd")

# Adiciona ao PATH do usuário
$UserPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($UserPath -notlike "*$shimDir*") {
    [Environment]::SetEnvironmentVariable("Path","$shimDir;$UserPath","User")
}

Write-Host "Wrappers criados. Feche e reabra o terminal."