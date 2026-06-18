# Setup do Secretário Pessoal
# Executa após: docker compose up -d
# Uso: .\scripts\setup.ps1

param(
    [string]$InstanceName = "secretario",
    [string]$MeuNumero = ""
)

# Carrega .env
$envPath = "$PSScriptRoot\..\env"
if (Test-Path "$PSScriptRoot\..\.env") {
    Get-Content "$PSScriptRoot\..\.env" | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.+)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), 'Process')
        }
    }
}

$EVOLUTION_URL = "http://localhost:8081"
$EVOLUTION_KEY = $env:EVOLUTION_API_KEY
$N8N_URL       = "http://localhost:8080"
$N8N_WEBHOOK   = "$N8N_URL/webhook/whatsapp"

Write-Host "=== Setup Secretário Pessoal ===" -ForegroundColor Cyan

# 1. Aguarda containers subirem
Write-Host "`n[1/4] Aguardando containers..." -ForegroundColor Yellow
$tentativas = 0
do {
    Start-Sleep -Seconds 3
    $tentativas++
    try {
        $resp = Invoke-RestMethod "$EVOLUTION_URL/" -ErrorAction Stop
        break
    } catch {
        Write-Host "  Aguardando Evolution API... ($tentativas/10)"
        if ($tentativas -ge 10) { Write-Error "Evolution API não respondeu. Verifique: docker compose logs evolution-api"; exit 1 }
    }
} while ($true)
Write-Host "  ✅ Containers online" -ForegroundColor Green

# 2. Cria instância WhatsApp
Write-Host "`n[2/4] Criando instância '$InstanceName'..." -ForegroundColor Yellow
$headers = @{ "apikey" = $EVOLUTION_KEY; "Content-Type" = "application/json" }
$body = @{ instanceName = $InstanceName; qrcode = $true } | ConvertTo-Json

try {
    $inst = Invoke-RestMethod "$EVOLUTION_URL/instance/create" -Method POST -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "  ✅ Instância criada: $($inst.instance.instanceName)" -ForegroundColor Green
} catch {
    Write-Host "  ℹ️ Instância pode já existir, continuando..." -ForegroundColor Yellow
}

# 3. Configura webhook da instância para o n8n
Write-Host "`n[3/4] Configurando webhook → $N8N_WEBHOOK..." -ForegroundColor Yellow
$webhookBody = @{
    url = $N8N_WEBHOOK
    webhook_by_events = $false
    webhook_base64 = $false
    events = @("MESSAGES_UPSERT")
} | ConvertTo-Json

try {
    Invoke-RestMethod "$EVOLUTION_URL/webhook/set/$InstanceName" -Method POST -Headers $headers -Body $webhookBody | Out-Null
    Write-Host "  ✅ Webhook configurado" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Erro ao configurar webhook: $_" -ForegroundColor Red
}

# 4. QR Code para conectar WhatsApp
Write-Host "`n[4/4] Obtendo QR Code..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Acesse: $EVOLUTION_URL/instance/qrcode/$InstanceName" -ForegroundColor Cyan
Write-Host "  Ou abra o Evolution Manager em: $EVOLUTION_URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "=== PRÓXIMOS PASSOS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Escaneie o QR Code com o WhatsApp do seu iPhone"
Write-Host "  2. Acesse o n8n em: $N8N_URL"
Write-Host "  3. Importe os workflows de n8n\workflows\"
Write-Host "  4. Configure a credencial Redis:"
Write-Host "     - Host: redis  |  Port: 6379  |  DB: 0"
Write-Host "  5. Adicione MEU_NUMERO no .env (ex: 5544999999999)"
Write-Host "  6. Ative todos os workflows"
Write-Host ""
Write-Host "=== IDs de Drive a preencher em prompts\system.md ===" -ForegroundColor Yellow
Write-Host "  - ID_TRACKER: ID do Google Doc do tracker"
Write-Host "  - ID_CRONOGRAMA: ID do cronograma financeiro"
Write-Host "  - ID_IMPULSO_MARINGA: ID do doc Impulso Maringá"
Write-Host ""
Write-Host "=== Caminhos SSH a preencher nos handlers ===" -ForegroundColor Yellow
Write-Host "  - /path/to/secretario → caminho real no PC desktop"
Write-Host "  - /path/to/clube-do-gole → caminho real no PC desktop"
