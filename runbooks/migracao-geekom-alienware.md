# 🚚 Migração GEEKOM → Alienware (Archimedes V2 completo)

> **Objetivo:** mover **tudo** do workstation (`10.0.0.10`, VM no Proxmox GEEKOM) para o **Alienware** (`10.0.0.208`) — cofre, RAG, projetos, vault, notas, backups e configs de agente — deixando o Alienware como máquina única. A VM de origem **permanece intacta** (só cópia).

---

## 📋 Pré-requisitos

| Item | Origem (GEEKOM) | Destino (Alienware) |
| :--- | :--- | :--- |
| Acesso | `ssh alienware` funcionando | chave `~/.ssh/id_ed25519` autorizada |
| Git | repo `archimedes-v2` atualizado | `~/.archimedes-v2` clonado |
| Python | — | `sudo apt install -y python3.12-venv` |
| Docker | — | containers `archimedes*` rodando |

> 💡 **Pegadinha:** o shell não-login do SSH **não** carrega `~/.local/bin`. Use sempre `ssh alienware 'bash -lc "..."'` para achar `hermes`/`agy`.

---

## 1️⃣ Sincronizar o cofre `archimedes-v2`

No Alienware, descarte edições locais já versionadas e puxe:

```bash
ssh alienware 'bash -lc "cd ~/archimedes-v2 && git checkout -- docker/docker-compose.yml && rm -rf docker/archimedes && git pull --ff-only origin main"'
```

> 🔒 O `docker/.env` (com `WEBUI_SECRET_KEY`) é **gitignored** e **não** é tocado pelo pull. Confirme: `ls -la ~/archimedes-v2/docker/.env`.

---

## 2️⃣ RAG semântico (`archimedes-rag`) + systemd na 8765

**a) Copiar o repo** (sem venvs/caches) — do GEEKOM:

```bash
rsync -avz --exclude '.venv' --exclude '__pycache__' --exclude '.pytest_cache' \
  ~/projetos/archimedes-rag/ alienware:~/projetos/archimedes-rag/
```

**b) Índice LanceDB** (evita reindexar tudo):

```bash
rsync -avz ~/.cache/opencode_rag/ alienware:~/.cache/opencode_rag/
```

**c) Venv + dependências** (no Alienware):

```bash
ssh alienware 'bash -lc "sudo -n apt-get install -y python3.12-venv && \
  cd ~/projetos/archimedes-rag && rm -rf .venv && python3 -m venv .venv && \
  .venv/bin/pip install --upgrade pip -q && .venv/bin/pip install -r requirements.txt"'
```

**d) Serviço systemd** (path `/home/brn/...` é idêntico → dá para copiar da VM):

```bash
scp ~/.config/systemd/user/archimedes-rag-mcp.service alienware:~/.config/systemd/user/
ssh alienware 'bash -lc "systemctl --user daemon-reload && systemctl --user enable --now archimedes-rag-mcp && systemctl --user is-active archimedes-rag-mcp"'
```

**e) Validar** (streamable-http exige `initialize` → `mcp-session-id` → `tools/list`):

```bash
ssh alienware 'bash -lc "ss -tlnp | grep 8765"'
```

---

## 3️⃣ Projetos e dados

```bash
rsync -az --exclude 'node_modules' --exclude '.venv' --exclude 'venv' \
  --exclude '__pycache__' --exclude '.pytest_cache' --exclude 'dist' \
  --exclude 'build' --exclude 'target' ~/projetos/ alienware:~/projetos/

rsync -az ~/archimedes-vault/ alienware:~/archimedes-vault/
rsync -az ~/wikisidian/      alienware:~/wikisidian/
rsync -az ~/backups/         alienware:~/backups/
rsync -az ~/Documentos/      alienware:~/Documentos/
rsync -az ~/Imagens/         alienware:~/Imagens/
rsync -az ~/.agents/         alienware:~/.agents/
```

> 💡 **Pegadinha:** a diferença de tamanho (ex.: vault 92M→5,5M) é só `node_modules`/`.venv` **excluídos de propósito** — o conteúdo real é 100% copiado.

---

## 4️⃣ Configs de agente

- `~/.agents` → migrar normalmente (rules + skills).
- `~/.gemini` → copiar **apenas** `GEMINI.md`. As configs da VM referenciam paths locais (`linuxbrew`, `bun`, `claude-mem`) que **quebrariam** o `agy` já configurado no Alienware.

---

## 5️⃣ Reapontar clientes para o RAG local

| Cliente | Antes | Depois |
| :--- | :--- | :--- |
| **hermes** (`~/.hermes/config.yaml`) | `url: http://10.0.0.10:8765/mcp` | `url: http://127.0.0.1:8765/mcp` |
| **hermes** `skills.external_dirs` | `~/linux-toolbox-tui/...` | `~/projetos/linux-toolbox-tui/...` |
| **agy** | `agy mcp add archimedes-rag http://10.0.0.10:8765/mcp` | `agy mcp add archimedes-rag http://127.0.0.1:8765/mcp` |
| **opencode (container)** | sem MCP | `extra_hosts: host-gateway` + `opencode.json` → `host.docker.internal:8765/mcp` |

> 💡 **Portabilidade:** o `mcp_config.json` do bundle `plugins/archimedes-agent` agora aponta para `127.0.0.1` — cada máquina usa o **seu próprio** RAG local.

---

## 6️⃣ Validação end-to-end

```bash
# RAG local no Alienware (fase initialize + tools/list)
ssh alienware 'bash -lc "curl -s -D - -m 8 -X POST http://127.0.0.1:8765/mcp \
  -H \"Content-Type: application/json\" -H \"Accept: application/json, text/event-stream\" \
  -d \"{\\\"jsonrpc\\\":\\\"2.0\\\",\\\"id\\\":1,\\\"method\\\":\\\"initialize\\\",\\\"params\\\":{\\\"protocolVersion\\\":\\\"2025-06-18\\\",\\\"capabilities\\\":{},\\\"clientInfo\\\":{\\\"name\\\":\\\"t\\\",\\\"version\\\":\\\"1\\\"}}}\""'

# skills do Archimedes no hermes
ssh alienware 'bash -lc "hermes skills list" | grep -E "consultar-rag|notas-atomicas|script-linux|planning-with-files"'

# MCP do container opencode alcança o host
ssh alienware 'bash -lc "docker exec archimedes sh -lc \"curl -s -o /dev/null -w %{http_code} http://host.docker.internal:8765/mcp\""'
```

---

## 🔒 Segurança

- A VM de origem (`10.0.0.10`) **não sofre nenhuma alteração** — é uma cópia unidirecional.
- **Nunca** copie `*.key`, `*.pem`, `.env` ou credenciais entre máquinas sem revisão.
- O `docker/.env` fica **apenas** no Alienware (gitignored).

## 🧯 Pegadinhas conhecidas

| Sintoma | Causa | Correção |
| :--- | :--- | :--- |
| `ensurepip is not available` | falta `python3.12-venv` | `sudo apt install -y python3.12-venv` |
| `Missing session ID` no MCP | protocolo streamable-http | enviar header `mcp-session-id` do `initialize` |
| `hermes`/`agy` não encontrado | shell não-login | `ssh alienware 'bash -lc "..."'` |
| container não vê o RAG | falta rota ao host | `extra_hosts: host.docker.internal:host-gateway` |
| RAG morre ao deslogar | `Linger=no` | `sudo loginctl enable-linger brn` |
