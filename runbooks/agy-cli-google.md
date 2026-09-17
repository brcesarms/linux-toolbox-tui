# 🤖 Google Antigravity CLI (`agy`) no Ubuntu

> **Objetivo:** instalar o CLI oficial do Google Antigravity (`agy`) em uma máquina Ubuntu 24.04 (Alienware) e fazer o primeiro login. Binário instalado em `~/.local/bin/agy` — custo R$ 0, sem sudo, sem poluição do sistema.

---

## 📋 Passo 1 — Instalar (1 comando)

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

O que acontece:
| Etapa | Efeito |
| :--- | :--- |
| `Detecting system environment` | detecta `linux_amd64` / `linux_arm64` (glibc ou musl) |
| `Querying release repository` | consulta o manifest via Google Cloud Run e pega a versão mais recente |
| `Downloading + checksum verify` | baixa e valida o checksum do binário |
| `Configuring shell environment` | adiciona `export PATH="/home/brn/.local/bin:$PATH"` ao `~/.profile` |

> 💡 Se já estiver instalado, o script avisa e sai — o `agy` faz **self-update automático** em segundo plano nas execuções normais.

---

## ✅ Passo 2 — Garantir PATH no shell interativo

O instalador edita o `~/.profile` (só vale em login shell). Para o terminal interativo comum, garanta no `~/.bashrc`:

```bash
echo 'export PATH="/home/brn/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

Verifique a instalação:

```bash
agy --version
```

---

## 🔐 Passo 3 — Primeiro login (interativo, somente você)

O `agy` autentica via **keyring seguro do sistema** (Secret Service/DBus no Linux) com fallback para **Google Sign-In no browser**:

```bash
agy
```

Na primeira execução:
1. Se o keyring tiver credencial válida, autentica em silêncio.
2. Caso contrário, abre navegador para login com a conta Google — autorize o Antigravity.

> ⚠️ Esse passo é **interativo e manual** — não tente automatizar com token por SSH/scripts.

---

## ⚡ Uso rápido

| Comando | Função |
| :--- | :--- |
| `agy` | abre a sessão interativa do agente |
| `agy --conversation=<id>` | retoma uma conversa específica |
| `agy --dangerously-skip-permissions` | modo headless/automação (use com critério) |
| `agy --version` | versão instalada |

---

## 🔒 Segurança

- O instalador roda **sem sudo** e instala apenas em `~/.local/bin` (não toca em `/usr`).
- A origem é o endpoint oficial do Google (`antigravity-cli-auto-updater` em Cloud Run), com checksum verificado.
- **Nunca** compartilhe/commite tokens ou credenciais geradas pelo login (`~/.gemini/`, keyring).
- Para remover, basta apagar o binário: `rm ~/.local/bin/agy`.