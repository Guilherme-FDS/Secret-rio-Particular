# Como subir o Secretário Pessoal

## Pré-requisitos
- Docker Desktop instalado e rodando
- Node.js 18+ (para Tailscale MCP no Claude Code)

---

## Passo 1 — SSH no Windows (admin necessário)

Abre PowerShell **como Administrador** e roda:

```powershell
.\scripts\setup-tailscale.ps1
```

Isso:
- Instala OpenSSH Server no Windows
- Gera chave SSH dedicada para o n8n (`~/.ssh/secretario_n8n`)
- Instala Tailscale e faz login (abre o browser)
- Atualiza o `.env` com o IP Tailscale do PC

---

## Passo 2 — Preencher credenciais

```powershell
copy .env.example .env
```

Edita o `.env` e preenche:

| Variável | Onde pegar |
|---|---|
| `ANTHROPIC_API_KEY` | console.anthropic.com → API Keys |
| `GROQ_API_KEY` | console.groq.com → API Keys |
| `EVOLUTION_API_KEY` | qualquer string segura (você escolhe) |
| `N8N_PASSWORD` | você escolhe |
| `N8N_ENCRYPTION_KEY` | string aleatória ≥32 chars |
| `GOOGLE_CLIENT_ID/SECRET` | ver Passo 3 |
| `GOOGLE_REFRESH_TOKEN` | ver Passo 3 |
| `MEU_NUMERO` | seu número com DDI+DDD (ex: 5544999999999) |

---

## Passo 3 — Google OAuth (Calendar + Drive + Gmail)

1. Acesse [Google Cloud Console](https://console.cloud.google.com)
2. Cria projeto → Habilita APIs: **Gmail API**, **Google Calendar API**, **Google Docs API**
3. Cria credencial OAuth 2.0 → Tipo: **Aplicativo Web**
4. URI de redirecionamento: `https://developers.google.com/oauthplayground`
5. Vai em [OAuth Playground](https://developers.google.com/oauthplayground):
   - Engrenagem → "Use your own OAuth credentials" → cola Client ID e Secret
   - Autoriza os escopos:
     - `https://www.googleapis.com/auth/calendar`
     - `https://www.googleapis.com/auth/drive`
     - `https://www.googleapis.com/auth/gmail.modify`
   - Step 2 → "Exchange authorization code for tokens"
   - Copia o **Refresh token** → cola no `.env`

---

## Passo 4 — Subir os containers

```powershell
cd "C:\Users\Guilherme Silva\Desktop\Projetos\secretario-pessoal"

# Opção A — local (sem Tailscale remoto):
docker compose up -d --build

# Opção B — com Tailscale sidecar (acesso remoto):
docker compose --profile tailscale up -d --build
```

Aguarda build (~2-3 min na primeira vez).

---

## Passo 5 — Conectar WhatsApp

```powershell
.\scripts\setup.ps1
```

Acessa `http://localhost:8081` → escaneia QR Code com o iPhone.

---

## Passo 6 — Importar workflows no n8n

1. Acessa `http://localhost:8080`
2. Login: usuário/senha do `.env`
3. Menu → **Workflows** → **Import from File**
4. Importa cada arquivo de `n8n/workflows/`:
   - `01-base-whatsapp.json`
   - `02-briefing-diario.json`
   - `03-resumo-email.json`
   - `04-documentacao.json`
5. Para cada workflow:
   - Clica no node **Ler Histórico Redis** → configura credencial Redis:
     - Host: `redis` | Port: `6379` | DB: `0`
   - Ativa o workflow (toggle no canto superior direito)

---

## Passo 7 — Tailscale MCP no Claude Code

O arquivo `~/.claude/settings.json` já foi criado com a configuração.
Após instalar Tailscale (Passo 1), o MCP fica disponível automaticamente
na próxima sessão do Claude Code.

Isso permite ao Claude Code:
- Listar máquinas na sua rede Tailscale
- SSH direto em qualquer máquina via `tailscale ssh`
- Executar comandos remotos durante sessões de desenvolvimento

---

## Passo 8 — Preencher IDs dos docs no Drive

No arquivo `n8n/workflows/01-base-whatsapp.json`, substitui:

```
ID_TRACKER       → ID real do Google Doc do tracker
ID_CRONOGRAMA    → ID real do cronograma financeiro
ID_IMPULSO_MARINGA → ID real do doc Impulso Maringá
```

O ID fica na URL do doc: `docs.google.com/document/d/**ID-AQUI**/edit`

---

## Verificar se está funcionando

```powershell
# Status dos containers
docker compose ps

# Logs do n8n
docker compose logs n8n -f

# Logs do WhatsApp
docker compose logs evolution-api -f
```

Manda uma mensagem no WhatsApp para si mesmo: `"oi"` — o agente deve responder.

---

## Estrutura de portas

| Serviço | Porta |
|---|---|
| n8n (UI + webhooks) | 8080 |
| Evolution API | 8081 |
| Redis | interno apenas |
