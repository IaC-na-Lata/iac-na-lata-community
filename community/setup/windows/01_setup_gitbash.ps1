$ErrorActionPreference = "Stop"

function Find-GitBash {
  $candidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LocalAppData\Programs\Git\bin\bash.exe",
    "$env:LocalAppData\Programs\Git\usr\bin\bash.exe"
  )
  return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Get-WTSettingsPath {
  # WT (Store/MSIX) costuma ficar aqui:
  $p1 = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
  # WT (portable/winget não-store) às vezes fica aqui:
  $p2 = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"

  if (Test-Path $p1) { return $p1 }
  if (Test-Path $p2) { return $p2 }

  # Se não existir ainda, tentamos criar no caminho do Store (mais comum)
  $dir = Split-Path $p1 -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  return $p1
}

Write-Host "1) Instalando Windows Terminal (winget)..." -ForegroundColor Cyan
try {
  winget install --id Microsoft.WindowsTerminal -e --accept-package-agreements --accept-source-agreements
} catch {
  Write-Host "Falha ao instalar Windows Terminal via winget. Verifique se o winget está disponível." -ForegroundColor Red
  throw
}

Write-Host "2) Instalando Git for Windows (winget)..." -ForegroundColor Cyan
try {
  winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
} catch {
  # Se já estiver instalado, winget pode reclamar; seguimos
  Write-Host "Git pode já estar instalado (ou winget retornou erro). Vou tentar continuar..." -ForegroundColor Yellow
}

Write-Host "3) Localizando Git Bash..." -ForegroundColor Cyan
$bashExe = Find-GitBash
if (-not $bashExe) {
  throw "Não encontrei bash.exe do Git. Confirme se o Git for Windows foi instalado corretamente."
}
Write-Host "Git Bash encontrado em: $bashExe" -ForegroundColor Green

Write-Host "4) Ajustando Windows Terminal para abrir no Git Bash por padrão..." -ForegroundColor Cyan
$settingsPath = Get-WTSettingsPath
Write-Host "settings.json: $settingsPath" -ForegroundColor Yellow

# Se settings.json ainda não existir, cria estrutura mínima
if (!(Test-Path $settingsPath)) {
  $minimal = @{
    '$schema' = "https://aka.ms/terminal-profiles-schema"
    version   = "1.21"
    profiles  = @{
      list = @()
    }
  } | ConvertTo-Json -Depth 10
  Set-Content -Path $settingsPath -Value $minimal -Encoding UTF8
}

# Carrega JSON
$jsonText = Get-Content -Path $settingsPath -Raw -Encoding UTF8
$cfg = $jsonText | ConvertFrom-Json

# Garante profiles.list
if (-not $cfg.profiles) { $cfg | Add-Member -NotePropertyName profiles -NotePropertyValue (@{}) }
if (-not $cfg.profiles.list) { $cfg.profiles | Add-Member -NotePropertyName list -NotePropertyValue (@()) }

# GUID fixo pro Git Bash (pra não mudar toda vez)
$gitBashGuid = "{2f4eab6a-5d64-4b8e-9d3d-1a6c2b0c8f2b}"

# Procura profile existente por guid ou name
$existing = $null
foreach ($p in $cfg.profiles.list) {
  if ($p.guid -eq $gitBashGuid -or $p.name -eq "Git Bash") { $existing = $p; break }
}

# Monta/atualiza profile
$commandline = "`"$bashExe`" --login -i"

if (-not $existing) {
  $newProfile = [pscustomobject]@{
    guid        = $gitBashGuid
    name        = "Git Bash"
    commandline = $commandline
    icon        = "$env:ProgramFiles\Git\mingw64\share\git\git-for-windows.ico"
    startingDirectory = "%USERPROFILE%"
  }
  # adiciona
  $cfg.profiles.list += $newProfile
  Write-Host "Profile 'Git Bash' criado." -ForegroundColor Green
} else {
  $existing.name = "Git Bash"
  $existing.commandline = $commandline
  if (-not $existing.startingDirectory) { $existing | Add-Member -NotePropertyName startingDirectory -NotePropertyValue "%USERPROFILE%" }
  Write-Host "Profile 'Git Bash' atualizado." -ForegroundColor Green
}

# Define como padrão
$cfg.defaultProfile = $gitBashGuid
Write-Host "defaultProfile ajustado para 'Git Bash'." -ForegroundColor Green

# Salva
$cfg | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8

Write-Host "`nConcluído!" -ForegroundColor Cyan
Write-Host "Agora feche e reabra o Windows Terminal — ele deve iniciar direto no Git Bash." -ForegroundColor Cyan