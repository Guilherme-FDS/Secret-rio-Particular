# Setup Tailscale + SSH no Windows para o Secretário Pessoal
# Precisa rodar como Administrador
# Uso: powershell -ExecutionPolicy Bypass -File .\scripts\setup-tailscale.ps1

param(
    [string]$TailscaleAuthKey = "",  # tskey-auth-xxx (opcional — pode logar via browser)
    [string]$SshUser = $env:USERNAME
)

# Verifica se é admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Execute como Administrador: clique direito no PowerShell → 'Executar como administrador'"
    exit 1
}

Write-Host "=== Setup Tailscale + SSH Windows ===" -ForegroundColor Cyan

# ── 1. OpenSSH Server ──────────────────────────────────────────────────────
Write-Host "`n[1/4] Instalando OpenSSH Server..." -ForegroundColor Yellow
$sshCapability = Get-WindowsCapability -Online -Name OpenSSH.Server*
if ($sshCapability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    Write-Host "  ✅ OpenSSH Server instalado" -ForegroundColor Green
} else {
    Write-Host "  ℹ️  OpenSSH Server já instalado" -ForegroundColor Yellow
}

# Inicia e configura para iniciar automaticamente
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic
Write-Host "  ✅ sshd rodando e configurado para iniciar automaticamente" -ForegroundColor Green

# ── 2. Chave SSH para o n8n ───────────────────────────────────────────────
Write-Host "`n[2/4] Configurando chave SSH para o n8n..." -ForegroundColor Yellow
$sshDir = "$env:USERPROFILE\.ssh"
$keyPath = "$sshDir\secretario_n8n"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

if (-not (Test-Path $keyPath)) {
    ssh-keygen -t ed25519 -C "n8n-secretario" -f $keyPath -N '""' | Out-Null
    Write-Host "  ✅ Chave gerada: $keyPath" -ForegroundColor Green
} else {
    Write-Host "  ℹ️  Chave já existe: $keyPath" -ForegroundColor Yellow
}

# Adiciona chave pública ao authorized_keys
$pubKey = Get-Content "$keyPath.pub"
$authKeys = "$sshDir\authorized_keys"
$existente = (Test-Path $authKeys) -and ((Get-Content $authKeys) -contains $pubKey)
if (-not $existente) {
    Add-Content -Path $authKeys -Value $pubKey
    Write-Host "  ✅ Chave pública adicionada ao authorized_keys" -ForegroundColor Green
}

# Copia a chave privada para o volume do n8n
$n8nSshDir = "C:\Users\$env:USERNAME\Desktop\Projetos\secretario-pessoal\n8n\ssh"
New-Item -ItemType Directory -Force -Path $n8nSshDir | Out-Null
Copy-Item $keyPath "$n8nSshDir\id_ed25519" -Force
Write-Host "  ✅ Chave privada copiada para: $n8nSshDir\id_ed25519" -ForegroundColor Green

# ── 3. Instala Tailscale ───────────────────────────────────────────────────
Write-Host "`n[3/4] Instalando Tailscale..." -ForegroundColor Yellow
$tsInstalled = Test-Path "C:\Program Files\Tailscale\tailscale.exe"
if (-not $tsInstalled) {
    Write-Host "  Baixando instalador do Tailscale..."
    $installer = "$env:TEMP\tailscale-installer.exe"
    Invoke-WebRequest "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile $installer
    Start-Process $installer -ArgumentList "/S" -Wait
    Write-Host "  ✅ Tailscale instalado" -ForegroundColor Green
} else {
    Write-Host "  ℹ️  Tailscale já instalado" -ForegroundColor Yellow
}

# Login no Tailscale
Write-Host ""
if ($TailscaleAuthKey -ne "") {
    & "C:\Program Files\Tailscale\tailscale.exe" login --authkey $TailscaleAuthKey
    Write-Host "  ✅ Tailscale autenticado via authkey" -ForegroundColor Green
} else {
    Write-Host "  📌 Abrindo login do Tailscale no browser..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Tailscale\tailscale.exe" -ArgumentList "login"
    Write-Host "  ⏳ Aguarde o login e pressione Enter para continuar..."
    Read-Host
}

# ── 4. Atualiza .env com configurações SSH ────────────────────────────────
Write-Host "`n[4/4] Atualizando .env..." -ForegroundColor Yellow
$envPath = "C:\Users\$env:USERNAME\Desktop\Projetos\secretario-pessoal\.env"
if (Test-Path $envPath) {
    # Pega IP Tailscale da máquina
    $tsStatus = & "C:\Program Files\Tailscale\tailscale.exe" status --json 2>$null | ConvertFrom-Json
    $tsIP = $tsStatus?.Self?.TailscaleIPs?[0] ?? "100.x.x.x"

    $content = Get-Content $envPath -Raw
    $content = $content -replace 'SSH_HOST=.*', "SSH_HOST=$tsIP"
    $content = $content -replace 'SSH_USER=.*', "SSH_USER=$SshUser"
    $content = $content -replace 'SSH_KEY_PATH=.*', "SSH_KEY_PATH=C:/Users/$SshUser/.ssh/secretario_n8n"
    Set-Content $envPath $content
    Write-Host "  ✅ .env atualizado com SSH_HOST=$tsIP" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  .env não encontrado. Copie .env.example para .env e configure." -ForegroundColor Red
}

# ── Resumo ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== CONFIGURAÇÃO CONCLUÍDA ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Chave SSH para o n8n:" -ForegroundColor White
Write-Host "  Privada: $n8nSshDir\id_ed25519"
Write-Host "  (já configurada no docker-compose.yml via SSH_KEY_PATH)"
Write-Host ""
Write-Host "Tailscale IP deste PC:" -ForegroundColor White
$tsIP2 = & "C:\Program Files\Tailscale\tailscale.exe" ip -4 2>$null
Write-Host "  $tsIP2"
Write-Host ""
Write-Host "PRÓXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host "  1. cd 'Desktop\Projetos\secretario-pessoal'"
Write-Host "  2. cp .env.example .env  (se ainda não fez)"
Write-Host "  3. Preencha as chaves (Anthropic, Groq, Google, Evolution)"
Write-Host "  4. docker compose up -d --build"
Write-Host "  5. .\scripts\setup.ps1  (cria instância WhatsApp)"
