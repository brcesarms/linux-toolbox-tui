# 🏛️ Força do Archimedes no `agy` + Hermes Agent (Alienware)

> **Objetivo:** dar ao **Google Antigravity CLI (`agy`)** e ao **Hermes Agent** a MESMA força do opencode do Archimedes V2 — as 4 skills (notas-atomicas, script-linux, consultar-rag, planning-with-files), os 3 subagentes (estudante/resumidor/executor), a persona/regras do Archimedes e o **RAG semântico** (archimedes-rag) via HTTP. Tudo a partir do bundle portátil `plugins/archimedes-agent/` deste repositório.

---

## 🧩 Arquitetura

```text
┌──────────────────────────────┐        streamable-http        ┌───────────────────────────┐
│  Workstation (10.0.0.10)     │◀──────────────────────────────│  Alienware (10.0.0.208)   │
│  archimedes-rag-mcp.service  │     http://10.0.0.10:8765/mcp │  agy  (plugins+skills+    │
│  LanceDB (índice único)      │                               │        agents+MCP)        │
│  systemd user · porta 8765   │                               │  hermes (external_dirs+   │
└──────────────────────────────┘                               │          mcp_servers)     │
                                                               └───────────────────────────┘
```

- **Fonte única de verdade do índice:** o LanceDB vive na **workstation** (onde o opencode já usa o RAG).
- **Bundle portátil:** `plugins/archimedes-agent/` no repo público `linux-toolbox-tui` (veículo de deploy).
- **Skills:** padrão aberto agentskills.io (`.agents/skills/<nome>/SKILL.md`) — os 3 agentes usam o mesmo formato.

---

## 📦 Pré-requisitos

| Item | Onde | Observação |
| :--- | :--- | :--- |
| `archimedes-rag` (repo) | Workstation | `/home/brn/projetos/archimedes-rag` com `.venv` |
| Acesso SSH por nome | Workstation → Alienware | `ssh alienware` (ver runbook de bootstrap SSH) |
| `agy` instalado | Alienware | Se não tiver: `curl -fsSL https://antigravity.google/cli/install.sh \| bash` |
| `hermes` instalado | Alienware | Ver runbook `hermes-agent-alienware.md` |

---

## 🔴 PARTE A — Servidor RAG (workstation, uma vez)

**A.1 — Transporte HTTP no `mcp_server.py`** (já versionado no repo `archimedes-rag`):

```bash
# args disponíveis: --transport stdio|streamable-http --host --port --path
/home/brn/projetos/archimedes-rag/.venv/bin/python \
  /home/brn/projetos/archimedes-rag/src/mcp_server.py \
  --transport streamable-http --host 0.0.0.0 --port 8765 --path /mcp
```

**A.2 — Serviço systemd de usuário** (`~/.config/systemd/user/archimedes-rag-mcp.service`):

```ini
[Unit]
Description=Archimedes RAG MCP server — streamable-http LAN (porta 8765, bind 0.0.0.0)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/home/brn/projetos/archimedes-rag
ExecStart=/home/brn/projetos/archimedes-rag/.venv/bin/python /home/brn/projetos/archimedes-rag/src/mcp_server.py --transport streamable-http --host 0.0.0.0 --port 8765 --path /mcp
Restart=on-failure
RestartSec=3
Environment=PYTHONUNBUFFERED=1
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=default.target
```

Ativar e verificar:

```bash
systemctl --user daemon-reload
systemctl --user enable --now archimedes-rag-mcp
systemctl --user status archimedes-rag-mcp --no-pager
ss -tlnp | grep 8765   # deve mostrar LISTEN 0.0.0.0:8765
```

> 💡 Para o serviço sobreviver após logout (headless): `sudo loginctl enable-linger brn`.

---

## 🟢 PARTE B — Deploy do bundle no Alienware

```bash
ssh alienware

# 1) Clonar o repositório (repo público, HTTPS)
git clone --depth 1 https://github.com/brcesarms/linux-toolbox-tui.git ~/linux-toolbox-tui

# 2) Conferir o bundle
ls ~/linux-toolbox-tui/plugins/archimedes-agent/
#   skills/  agents/  rules/  plugin.json  mcp_config.json
```

> ⚠️ No SSH não-interativo o PATH não carrega `~/.local/bin`. Use `bash -lc "..."` ou prefixe os comandos com `export PATH="$HOME/.local/bin:$PATH"`.

---

## 🟣 PARTE C — `agy` (Antigravity CLI)

**C.1 — Instalar (se ainda não existir) e conferir:**

```bash
bash -lc 'command -v agy || curl -fsSL https://antigravity.google/cli/install.sh | bash'
bash -lc 'agy --version'   # ex.: 1.2.5
```

**C.2 — Validar e instalar o plugin:**

```bash
bash -lc 'agy plugin validate ~/linux-toolbox-tui/plugins/archimedes-agent'
# Skills: 4 processed · Agents: 3 processed · mcpServers: 1 processed

bash -lc 'agy plugin install ~/linux-toolbox-tui/plugins/archimedes-agent'
bash -lc 'agy plugin list'
```

**C.3 — Registrar o MCP do RAG** (o import do plugin NÃO registra o MCP no config global):

```bash
bash -lc 'agy mcp add archimedes-rag http://10.0.0.10:8765/mcp'
bash -lc 'agy mcp list'
# NAME            TYPE  STATUS   COMMAND/URL
# archimedes-rag  http  enabled  http://10.0.0.10:8765/mcp
```

**C.4 — Autenticação (interativa, somente você):**

```bash
agy          # keyring do sistema ou Google Sign-In no browser
```

> ⚠️ Em SSH headless o `agy --print` retorna `authentication required`. Faça o login interativo **ou** exporte `GEMINI_API_KEY` no ambiente (ex.: `~/.bashrc`) conforme a doc oficial.

---

## 🔵 PARTE D — Hermes Agent

Editar `~/.hermes/config.yaml` e acrescentar os blocos `skills` e `mcp_servers` (preserve `model` e `tools`):

```yaml
skills:
  external_dirs:
    - ~/linux-toolbox-tui/plugins/archimedes-agent/skills
mcp_servers:
  archimedes_rag:
    url: "http://10.0.0.10:8765/mcp"
    timeout: 120
```

> 💡 As skills em `external_dirs` são **read-only**; a criação de skills novas continua indo para `~/.hermes/skills/`.

---

## ✅ Validação (o que deve aparecer)

```bash
# Alienware — skills do Archimedes no hermes
bash -lc 'hermes skills list' | grep -E 'consultar-rag|notas-atomicas|script-linux|planning-with-files'
# todas: source=local · enabled

# Alienware — agy: skills/agents/mcp estagiados
bash -lc 'ls ~/.gemini/config/plugins/archimedes-agent/agents/'   # estudante.md executor.md resumidor.md
bash -lc 'agy mcp list'                                            # archimedes-rag http enabled

# Alienware — hermes chama o RAG remoto (E2E)
bash -lc 'cd ~ && hermes --cli -z "Use a ferramenta MCP archimedes_rag (search_codebase_rag). Argumentos: query=servidor mcp streamable http, project_dir=/home/brn/projetos/archimedes-rag, top_k=1. Mostre o nome da fonte retornada."'
# esperado: uma fonte real, ex.: src/mcp_server.py
```

Teste cru do endpoint (de qualquer máquina da LAN):

```bash
curl -s -X POST http://10.0.0.10:8765/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}}}'
# esperado: 200 + header mcp-session-id + result com capabilities.tools
```

---

## 🧠 Regra de ouro: `project_dir` é o path DA WORKSTATION

O índice LanceDB vive na **workstation**. Clientes remotos (agy/hermes) devem passar `project_dir` com caminhos que **existem na workstation** — não no Alienware.

| ❌ Errado (path do Alienware) | ✅ Certo (path da workstation) |
| :--- | :--- |
| `/home/brn/linux-toolbox-tui` | `/home/brn/projetos/linux-toolbox-tui` |
| `/home/brn/archimedes-v2` local | `/home/brn/archimedes-v2` (se existir na workstation) |

> 🔎 Se um projeto ainda não foi indexado, o servidor faz **auto-indexação JIT** na primeira busca — só que do ponto de vista da workstation.

---

## 🔧 Troubleshooting

| Sintoma | Causa provável | Solução |
| :--- | :--- | :--- |
| `agy: command not found` no SSH | PATH não carregado (shell não-login) | `bash -lc 'agy ...'` ou `export PATH="$HOME/.local/bin:$PATH"` |
| `agy mcp list` → "No MCP servers configured" | import do plugin não registra MCP global | `agy mcp add archimedes-rag http://10.0.0.10:8765/mcp` |
| `agy --print` → "authentication required" | sem login/keyring/key no host headless | login interativo (`agy`) ou `GEMINI_API_KEY` |
| RAG retorna "não contém índice vetorial" | `project_dir` aponta para path inexistente na workstation | usar `/home/brn/projetos/<proj>` |
| Porta 8765 recusa conexão da LAN | serviço parado ou firewall | `systemctl --user status archimedes-rag-mcp` + liberar 8765 |
| Serviço morre no logout | sem linger | `sudo loginctl enable-linger brn` |

---

## 🔒 Segurança

- O RAG fica exposto **somente na LAN** (`10.0.0.0/24`), sem autenticação — **não** publique a porta 8765 para a internet.
- `agy` instala sem sudo em `~/.local/bin` (não toca em `/usr`), checksum verificado pelo instalador oficial.
- **Nunca** commite tokens/credenciais: `~/.gemini/` (keyring/sessão), `GEMINI_API_KEY`, `~/.hermes/config.yaml` com segredos.
- Skills em `external_dirs` são **read-only** (bom para auditoria do bundle).
