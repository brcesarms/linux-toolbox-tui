# 🤖 Hermes Agent no Alienware — Estagiário Local (R$ 0)

> **Objetivo:** instalar o **Hermes Agent** (Nous Research) no **Alienware Ubuntu 24.04** usando **modelo 100% local** (`hermes3-64k` via Ollama na GPU RTX 5060). Custo de tokens: **R$ 0**. O Hermes é o **estagiário operacional local** — executa comandos, lê/escreve arquivos e roda diagnósticos por conta própria.

---

## 🎯 Arquitetura

| Camada | Componente | Modelo | Custo |
| :--- | :--- | :--- | :--- |
| 🏛️ **Archimedes** (cloud) | container `archimedes` (opencode serve) | `big-pickle` (cloud) | tokens |
| 🤖 **Hermes** (local) | CLI `hermes` no host | `hermes3-64k` (Ollama/GPU) | **R$ 0** |

> ⚠️ O Hermes **roda no host** (não em container) porque é o agente operacional — precisa de acesso a `docker`, `systemctl`, arquivos etc. Ele mora em `~/.hermes/` (sem poluir o sistema).

---

## 📋 Pré-requisitos

- Ubuntu 24.04 com `sudo` configurado (ver [runbook de bootstrap SSH](./ssh-bootstrap-ubuntu.md)).
- Ollama rodando (container `archimedes-ollama`, porta `11434`) — ver [runbook do Archimedes](./archimedes-alienware-docker.md).

---

## 📥 Passo 1 — Baixar o modelo Hermes 3 (64K de contexto)

O Hermes exige **≥64K de contexto** para trabalho agêntico com tools (o padrão do Ollama é curto demais).

```bash
# Baixa o modelo oficial (4.7 GB)
docker exec archimedes-ollama ollama pull hermes3:8b

# Cria variante com 64K de contexto (requisito do Hermes Agent)
docker exec -i archimedes-ollama sh -c 'cat > /tmp/Modelfile << "EOF"
FROM hermes3:8b
PARAMETER num_ctx 64000
EOF
ollama create hermes3-64k -f /tmp/Modelfile'
```

**Por que `hermes3:8b`?** É a escolha ideal: mesma casa do Hermes Agent (Nous Research), tool calling nativo e 128K de contexto nativo.

---

## 📦 Passo 2 — Instalar o Hermes Agent

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

O instalador:
1. Instala dependências do sistema (`ripgrep`, `ffmpeg`) via apt;
2. Instala `uv` em `~/.hermes/bin/`;
3. Clona o repositório em `~/.hermes/hermes-agent/`;
4. Cria o wrapper em `~/.local/bin/hermes`.

---

## 🐛 Passo 3 — Correções obrigatórias (2 bugs conhecidos)

### 3.1 — Venv com nome errado (bug do instalador)

O wrapper aponta para `venv/`, mas o `uv` cria `.venv/`. Sem isso o `hermes` falha com `ModuleNotFoundError: No module named 'dotenv'`:

```bash
cd ~/.hermes/hermes-agent
export PATH="$HOME/.hermes/bin:$PATH"
uv sync --frozen        # instala as dependências Python (~154 MB)
ln -sfn .venv venv      # corrige o caminho esperado pelo wrapper
```

### 3.2 — Desligar o "tool_search" (crítico para modelos 8B)

O Hermes troca as tools por bridges (`tool_search`/`tool_describe`/`tool_call`) quando há muitas. Um modelo 8B **se perde** nesse mecanismo e passa a "simular" ações em texto em vez de executá-las.

```bash
cat > ~/.hermes/config.yaml << "EOF"
model:
  default: "hermes3-64k"
  provider: "custom"
  base_url: "http://127.0.0.1:11434/v1"
tools:
  tool_search:
    enabled: "off"
    defer: []
EOF
```

| Chave | Efeito |
| :--- | :--- |
| `model.default` | modelo local (variante 64K) |
| `model.provider` | `custom` = endpoint OpenAI-compatible |
| `model.base_url` | API do Ollama local |
| `tools.tool_search.enabled: "off"` | pass-through, **sem** bridges |
| `tools.tool_search.defer: []` | nenhuma tool adiada (tudo eager) |

---

## ✅ Passo 4 — Validar

```bash
export PATH="$HOME/.local/bin:$PATH"
hermes status          # deve mostrar: Model: hermes3-64k · Provider: Custom endpoint
```

**Teste 1 — escrever arquivo (tool calling real):**

```bash
hermes -z "Use write_file para criar /tmp/hermes-test.txt com o conteudo: OK" -t file --yolo
cat /tmp/hermes-test.txt   # deve existir de verdade
```

**Teste 2 — diagnóstico de infra via terminal:**

```bash
hermes -z "Rode docker ps --format \"{{.Names}} -> {{.Status}}\" e liste os containers" -t terminal --yolo
```

---

## 🚀 Como o Archimedes delega ao Hermes (headless via SSH)

```bash
ssh alienware 'export PATH="$HOME/.local/bin:$PATH"; hermes -z "TAREFA AQUI" --yolo'
```

| Flag | Função |
| :--- | :--- |
| `-z "prompt"` | executa um prompt único (não-interativo) |
| `--yolo` | auto-aprova ações (sem confirmação) |
| `-t file,terminal` | opcional: restringe toolsets (mais rápido/confiável no 8B) |

---

## ✅ Status Validado (17/09/2026)

| Item | Valor |
| :--- | :--- |
| Hermes Agent | ✅ v0.21.3 (2026.9.14) |
| Modelo | ✅ `hermes3-64k` (Ollama, RTX 5060) |
| Tool calling | ✅ validado (`write_file` + `docker ps` reais) |
| Tempo de tarefa | ✅ ~18s (tarefa com tool call) |
| Chaves cloud | ✅ zero (100% local) |
| VRAM em uso | ~6.6 GB / 8.1 GB |

---

## 🩺 Troubleshooting

| Sintoma | Causa | Solução |
| :--- | :--- | :--- |
| `No module named 'dotenv'` | venv com nome errado | `ln -sfn .venv venv` + `uv sync --frozen` |
| Hermes "descreve" ação mas não executa | tool_search bridge confundindo o 8B | `tools.tool_search.enabled: "off"` + `defer: []` |
| Resposta vazia / timeout | contexto curto do Ollama | usar `hermes3-64k` (num_ctx 64000) |
| `hermes tools` não abre | exige terminal interativo | use `-t <toolset>` direto no comando |

---

## 🔒 Segurança

- Zero chaves de API em disco (inferência local).
- `--yolo` auto-aprova ações — use apenas em máquina de lab confiável com acesso SSH por chave.
- O modelo e o agente rodam offline; nada sai da rede local.
