# 🏛️ Archimedes no Alienware — Deploy Docker (Zero Poluição)

> **Objetivo:** rodar o **Archimedes V2** (agente de IA) no Alienware **Ubuntu 24.04** inteiramente dentro de **Docker** — sem instalar nada no sistema além do Docker Engine + drivers NVIDIA. O serviço se chama **`archimedes`**.

---

## 📋 Passo 0 — Ativar Homebrew + btop no terminal novo

Se você acabou de instalar o Homebrew e `btop` diz "comando não encontrado", feche o terminal e abra **outro novo** — ou rode no terminal atual:

```bash
eval "$(~/.linuxbrew/bin/brew shellenv)"
btop
```

> 💡 O `btop` fica em `~/.linuxbrew/bin/btop`. Abrir um terminal novo carrega o `.bashrc` (onde o Homebrew já foi adicionado) e o comando passa a funcionar sempre.

---

## 📋 Passo 1 — Liberar sudo sem senha (1 comando, só uma vez)

Cole no terminal do Alienware:

```bash
echo "brn ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/brn-nopasswd >/dev/null && sudo chmod 440 /etc/sudoers.d/brn-nopasswd && echo '✅ sudo NOPASSWD habilitado!'
```

| Comando | Efeito |
| :--- | :--- |
| `tee /etc/sudoers.d/brn-nopasswd` | cria regra de sudo sem senha para o usuário `brn` |
| `chmod 440` | permissão obrigatória do sudoers |

> 🔒 **Segurança:** esta liberação é para o workflow Archimedes (lab pessoal). A máquina só é acessível via SSH por chave ed25519 e está na rede local — restrinja se a máquina for para fora da rede.

---

## ✅ Passo 2 — Avisar o Archimedes

Depois de rodar o Passo 1, avise o Archimedes no chat. Ele fará **automaticamente via SSH**:

1. Instalar Docker Engine + Compose plugin (script oficial)
2. Instalar NVIDIA Container Toolkit (GPU RTX 5060)
3. Clonar `archimedes-v2` em `~/archimedes-v2`
4. Subir a stack: `ollama` (GPU) + `open-webui` + **`archimedes`** (opencode containerizado)
5. Publicar este runbook atualizado com o resultado

---

## ✅ Status Validado (17/09/2026)

| Serviço | Container | Status | Detalhe |
| :--- | :--- | :--- | :--- |
| **archimedes** | `archimedes` | ✅ Up | `opencode serve` na `4096`, modelo cloud `big-pickle` testado com sucesso |
| **ollama** | `archimedes-ollama` | ✅ Up (healthy) | GPU **RTX 5060** detectada (CUDA 12.0, 7.3 GiB VRAM) |
| **open-webui** | `archimedes-open-webui` | ✅ Up | Interface web `http://ip:3000` |

### 🎯 Arquitetura de modelos (decisão do Bruno)

| Agente | Modelo | Onde roda |
| :--- | :--- | :--- |
| 🏛️ **Archimedes** (container) | Cloud (`big-pickle`) | API cloud (raciocínio profundo) |
| 🤖 **Hermes** (estagiário) | Local (`qwen3-nothink` via Ollama) | GPU RTX 5060 — R$ 0 |

> 💡 O **Hermes Agent** já está instalado e validado no Alienware — ver [runbook do Hermes](./hermes-agent-alienware.md).

### 🩺 Comandos de verificação (dentro do Alienware)

```bash
cd ~/archimedes-v2/docker && sudo docker compose ps
sudo docker logs archimedes            # opencode serve na 4096
curl -s http://127.0.0.1:11434/api/tags # modelos locais do Ollama
sudo docker exec -w /work archimedes /root/.opencode/bin/opencode run "teste"
```

### 📝 Observações de implementação

- Healthcheck do Ollama usa TCP `/dev/tcp` (a imagem **não tem `curl`** — usar `curl` no healthcheck trava o compose).
- Credencial do opencode (provider cloud) é copiada do workstation para o volume do container (`docker cp auth.json archimedes:/root/.local/share/opencode/`).
- `.env` local com `WEBUI_SECRET_KEY` gerada (`openssl rand -hex 32`).

---

## 🏗️ Arquitetura Final (o que será criado)

| Serviço | Container | Porta | Função |
| :--- | :--- | :--- | :--- |
| **archimedes** | `archimedes` | — | Agente opencode (CLI interativo) |
| **ollama** | `archimedes-ollama` | `11434` | Runtime de LLM local com GPU RTX 5060 |
| **open-webui** | `archimedes-open-webui` | `3000` | Interface web de chat (opcional) |

**Nada roda fora dos containers** — o sistema Ubuntu fica limpo. ✅

---

## 🔒 Segurança

- Nenhuma chave API é versionada; segredos entram via `.env` local (ignorado pelo git).
- O container `archimedes` roda como usuário não-root.
- Acesso SSH por chave ed25519 (sem senha, já configurado).