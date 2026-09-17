# 🤖 Hermes Agent no Alienware — Estagiário Local (R$ 0)

> **Objetivo:** instalar o **Hermes Agent** (Nous Research) no **Alienware Ubuntu 24.04** usando **modelo 100% local** (`qwen3-nothink` via Ollama na GPU RTX 5060). Custo de tokens: **R$ 0**. O Hermes é o **estagiário operacional local** — executa comandos, lê/escreve arquivos e roda diagnósticos por conta própria.

---

## 🎯 Arquitetura

| Camada | Componente | Modelo | Custo |
| :--- | :--- | :--- | :--- |
| 🏛️ **Archimedes** (cloud) | container `archimedes` (opencode serve) | `big-pickle` (cloud) | tokens |
| 🤖 **Hermes** (local) | CLI `hermes` no host | `qwen3-nothink` (Ollama/GPU) | **R$ 0** |

> ⚠️ O Hermes **roda no host** (não em container) porque é o agente operacional — precisa de acesso a `docker`, `systemctl`, arquivos etc. Ele mora em `~/.hermes/` (sem poluir o sistema).

---

## 📋 Pré-requisitos

- Ubuntu 24.04 com `sudo` configurado (ver [runbook de bootstrap SSH](./ssh-bootstrap-ubuntu.md)).
- Ollama rodando (container `archimedes-ollama`, porta `11434`) — ver [runbook do Archimedes](./archimedes-alienware-docker.md).

---

## 🧠 Passo 1 — Preparar o modelo local (com benchmark comparativo)

O Hermes exige **≥64K de contexto** para trabalho agêntico com tools (o padrão do Ollama é curto demais).

```bash
# 1. Baixar o Qwen3 8B (5.2 GB)
docker exec archimedes-ollama ollama pull qwen3:8b
```

### 1.1 — Criar a variante `qwen3-nothink` (RECOMENDADA)

O Qwen3 é um modelo **"thinking"**: gera cadeia de raciocínio antes de agir, o que o deixa **~5x mais lento** (1m+ por tarefa). Injetando `/no_think` no template, ele fica rápido **sem perder confiabilidade**:

```bash
# Gera Modelfile com template que sempre injeta /no_think
python3 - << "PYEOF"
import json, urllib.request
req = urllib.request.Request("http://127.0.0.1:11434/api/show",
    data=json.dumps({"model":"qwen3:8b"}).encode(),
    headers={"Content-Type":"application/json"})
t = json.load(urllib.request.urlopen(req))["template"]
old = """{{- if and $.IsThinkSet (eq $i $lastUserIdx) }}
   {{- if $.Think -}}
      {{- " "}}/think
   {{- else -}}
      {{- " "}}/no_think
   {{- end -}}
{{- end }}"""
t2 = t.replace(old, "{{- \" \"}}/no_think")
mf = "FROM qwen3:8b\nPARAMETER num_ctx 64000\nTEMPLATE \"\"\"" + t2 + "\"\"\"\n"
open("/tmp/Modelfile-nothink","w").write(mf)
print("OK: Modelfile gerado")
PYEOF

# Cria o modelo no Ollama
sudo docker cp /tmp/Modelfile-nothink archimedes-ollama:/tmp/Modelfile-nothink
sudo docker exec archimedes-ollama ollama create qwen3-nothink -f /tmp/Modelfile-nothink
```

### 1.2 — Benchmark real (por que `qwen3-nothink` venceu)

Testes idênticos executados no Hermes Agent (RTX 5060, 8 GB VRAM):

| Teste | `hermes3-64k` | `qwen3-64k` (thinking) | ⭐ `qwen3-nothink` |
| :--- | :--- | :--- | :--- |
| `write_file` (criar arquivo) | ✅ ~30s | ✅ 31s | ✅ **8,8s** |
| 1 comando exato (`df -h /`) | ✅ 8,9s | ✅ 1m16s | ✅ **1,4s** |
| Multi-passo (disco + RAM container) | ❌ **alucinou** (20s) | ✅ 1m5s | ✅ **13,6s** |
| Complexo 3 passos (containers+Ollama+GPU) | ⚠️ vago (11,5s) | ✅ 1m4s | ✅ **23,7s** |

**Conclusão:** o Qwen3 com thinking é o mais confiável, mas lentíssimo. Com `/no_think` ele mantém a **confiabilidade** e ganha **velocidade** — virando o melhor modelo que cabe na GPU.

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
  default: "qwen3-nothink"
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
| `model.default` | modelo local (`qwen3-nothink`) |
| `model.provider` | `custom` = endpoint OpenAI-compatible |
| `model.base_url` | API do Ollama local |
| `tools.tool_search.enabled: "off"` | pass-through, **sem** bridges |
| `tools.tool_search.defer: []` | nenhuma tool adiada (tudo eager) |

---

## ✅ Passo 4 — Validar

```bash
export PATH="$HOME/.local/bin:$PATH"
hermes status          # deve mostrar: Model: qwen3-nothink · Provider: Custom endpoint
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
ssh alienware 'export PATH="$HOME/.local/bin:$PATH"; hermes -z "TAREFA AQUI" -t terminal --yolo'
```

| Flag | Função |
| :--- | :--- |
| `-z "prompt"` | executa um prompt único (não-interativo) |
| `--yolo` | auto-aprova ações (sem confirmação) |
| `-t file` | restringe ao toolset de arquivos (read/write/patch/search) |
| `-t terminal` | restringe ao toolset de terminal (comandos/processos) |
| `-m <modelo>` | troca o modelo só naquela chamada |

### 🎯 Regras de uso (evidência do benchmark)

1. **SEMPRE restringir o toolset** (`-t file` ou `-t terminal`) — com dezenas de tools o 8B se perde e alucina.
2. **1 tarefa atômica por invocação, com comando explícito** → confiável (~9–14s).
3. **Multi-step/ambíguo → delegar ao Archimedes cloud** — o 8B alucina comandos e dados.
4. Sempre `--yolo` para execução headless.

---

## 🧑‍💻 Wrapper de delegação (`estagiario-alienware`)

Para não repetir as flags e as regras anti-alucinação a cada chamada, existe o wrapper `estagiario-alienware` (no repo `archimedes-v2`, pasta `scripts/`). Ele já aplica **toolset restrito + prompt anti-alucinação + --yolo**.

```bash
# Instalação (uma vez, no workstation)
ln -sfn "$HOME/archimedes-v2/scripts/estagiario-alienware.sh" "$HOME/.local/bin/estagiario-alienware"

# Uso
estagiario-alienware "rode docker ps e liste os containers"
estagiario-alienware -t file "crie /tmp/nota.txt com o conteudo: oi"
echo "quanta RAM livre? use free -h" | estagiario-alienware -
```

| Flag / variável | Padrão | Função |
| :--- | :--- | :--- |
| `-t, --toolset` | `terminal` | `terminal` (comandos) ou `file` (arquivos) |
| `-m, --model` | `qwen3-nothink` | modelo Ollama |
| `-` (argumento) | — | lê a tarefa do **stdin** |
| `ESTAGIARIO_HOST` | `alienware` | host SSH |
| `ESTAGIARIO_TIMEOUT` | `300` | timeout em segundos |

O wrapper usa **base64** para transportar o prompt entre bash → SSH → Hermes, eliminando problemas de escaping com aspas e caracteres especiais.

**Resultado dos testes (17/09/2026):**

| Teste | Tempo | Resultado |
| :--- | :--- | :--- |
| `-t terminal` (docker ps) | 10,2s | ✅ correto |
| `-t file` (criar arquivo) | 8,1s | ✅ arquivo real criado |
| stdin/pipe (`free -h`) | 7,5s | ✅ correto |

---

## ✅ Status Validado (17/09/2026)

| Item | Valor |
| :--- | :--- |
| Hermes Agent | ✅ v0.21.3 (2026.9.14) |
| Modelo padrão | ✅ `qwen3-nothink` (Ollama, RTX 5060) |
| Tool calling | ✅ validado (`write_file`, `docker ps`, `df`, `nvidia-smi` reais) |
| Tempo (tarefa 1 passo) | ✅ ~1,4–9s |
| Tempo (3 passos) | ✅ ~24s |
| Chaves cloud | ✅ zero (100% local) |
| VRAM em uso | ~6.6 GB / 8.1 GB |

---

## 🩺 Troubleshooting

| Sintoma | Causa | Solução |
| :--- | :--- | :--- |
| `No module named 'dotenv'` | venv com nome errado | `ln -sfn .venv venv` + `uv sync --frozen` |
| Hermes "descreve" ação mas não executa | tool_search bridge confundindo o 8B | `tools.tool_search.enabled: "off"` + `defer: []` |
| Tarefas demorando 1min+ | thinking do Qwen3 | usar variante `qwen3-nothink` (template com `/no_think`) |
| Alucina comando/dado em tarefa multi-passo | modelo 8B + ambiguidade | restringir `-t` e/ou delegar ao Archimedes cloud |
| `hermes tools` não abre | exige terminal interativo | use `-t <toolset>` direto no comando |
| Erro `unknown parameter 'think'` no Modelfile | Ollama não aceita `PARAMETER think` | injetar `/no_think` via **TEMPLATE** (Passo 1.1) |

---

## 🔒 Segurança

- Zero chaves de API em disco (inferência local).
- `--yolo` auto-aprova ações — use apenas em máquina de lab confiável com acesso SSH por chave.
- O modelo e o agente rodam offline; nada sai da rede local.
