# 🐧 linux-toolbox-tui — Caixa de Ferramentas & Pós-Instalação para Linux

> **Suporta:** Debian/Ubuntu (`apt`) · Fedora (`dnf`) · Arch/Omarchy (`pacman`)  
> Interface **TUI estilo Setup Utility (BIOS)** no padrão do `win-toolbox-tui`: bordas duplas `╔═╗`, cursor em **bloco verde**, painel lateral **Item Help**, abas com atalhos, paginação (21 itens), **status dinâmico** (`[✓]` Verde = instalado) e execução em lote — o mesmo visual, agora em bash puro.

---

## ⚡ Execução Rápida (One-Liner)

No terminal do Linux — **com sudo** (o script exige root):

```bash
curl -sL https://raw.githubusercontent.com/brcesarms/linux-toolbox-tui/main/linux-toolbox.sh | sudo bash
```

Ou execute localmente clonando o repositório:

```bash
git clone https://github.com/brcesarms/linux-toolbox-tui.git
cd linux-toolbox-tui
chmod +x linux-toolbox.sh
sudo ./linux-toolbox.sh
```

**Execução headless (sem abrir a TUI) — recomendado para automação:**

```bash
curl -sL https://raw.githubusercontent.com/brcesarms/linux-toolbox-tui/main/linux-toolbox.sh | sudo bash -s R1,R2
sudo ./linux-toolbox.sh D1,D4,P1   # com o clone local
```

**Sem sudo / apenas visualizar:**

```bash
./linux-toolbox.sh --preview    # renderiza a tela sem instalar nada
```

> ⚠️ **Atenção:** NÃO use `bash <(curl -s ...)` (process substitution): sem sudo o script aborta por exigir root e, com `sudo`, o `/dev/fd` do substitution não é herdado (erro `Arquivo ou diretório inexistente`). Use SEMPRE o pipe `curl -sL ... | sudo bash`.

---

## 💎 Destaques Visuais & Experiência TUI (V3.0)

* 🖥️ **Interface estilo BIOS / Setup Utility (120x30):** bordas duplas `╔ ║ ╝`, ocupando perfeitamente a resolução padrão da janela (120 colunas x 30 linhas), abas superiores sempre visíveis e cursor de seleção em bloco verde — fiel ao firmware e espelhando o `win-toolbox-tui`.
* 💡 **Painel Lateral "Item Help" Dinâmico:** ao navegar com `↑` e `↓` pela lista à esquerda (68 colunas), o painel à direita (45 colunas) exibe instantaneamente nome, categoria, descrição com quebra de linha, pacote e status.
* ⌨️ **Navegação 100% nativa:** `← / →` ou `Tab` alternam abas · `↑ / ↓` movem · `Home / End` vão ao início/fim · `PgUp / PgDn` rolam páginas · Espaço marca `[✓]` · Enter executa · Esc ou Q sai.
* 🟢 **Detecção de instalados:** cada item aparece marcado com `[✓]` e `[INSTALADO]` em verde quando já presente no sistema; itens instalados não são remarcáveis.
* 📑 **Atalhos diretos entre abas:** `1` ou `S` (Sistema) · `2` ou `R` (Rede) · `3` ou `A` (Apps) · `4` ou `D` (Dev) · `5` ou `C` (Config) · `6` ou `P` (Perfis).
* 🔄 **Detecção Automática de Distro:** identifica `apt`, `dnf` ou `pacman` e o serviço correto (`ssh` vs `sshd`).
* 🧩 **Execução em Lote:** marca com `Espaço` ou digita códigos separados por vírgula (ex: `D1,D4,C1,P1`).
* ⏭️ **Modo Headless:** `./linux-toolbox.sh S,R1,D1,D4` executa direto, sem abrir a TUI.
* 👤 **Usuário Real Respeitado:** Homebrew e grupo `docker` são configurados para `SUDO_USER`, não para root.

### 🕹️ Teclas de Navegação

| Tecla | Ação |
| :--- | :--- |
| `↑` / `↓` | Mover seleção (com rolagem automática de página) |
| `←` / `→` ou `Tab` | Trocar menu / abas (navegação circular) |
| `Home` / `End` | Ir para o topo ou final da lista |
| `PgUp` / `PgDn` | Avançar ou recuar página inteira |
| `Espaço` | Marcar/desmarcar item para a fila em lote `[✓]` |
| `Enter` | Executar seleção atual (ou todos os marcados) |
| `1..6` ou `S/R/A/D/C/P` | Atalho direto para cada aba |
| `Q` / `Esc` | Sair / fechar o terminal |

---

## 🎯 Estrutura Modular dos Menus (Abas estilo BIOS)

### 1️⃣ [ SISTEMA ]
* **`0`**: 🚀 **Atualização Geral** — atualiza todos os pacotes (`apt upgrade` / `dnf upgrade` / `pacman -Syu`)

### 2️⃣ [ REDE & ACESSO REMOTO ]
* **`R1`**: 🚀 **Habilitar Servidor SSH** — instala `openssh-server`, habilita no boot, libera porta 22 no firewall (UFW/firewalld) e exibe o comando de conexão (`ssh usuario@IP`)
* **`R2`**: 🌐 **Habilitar mDNS/Avahi (Acesso por Nome `.local`)** — instala `avahi-daemon`, habilita no boot e permite conectar via `ssh usuario@NOME.local` sem depender do IP — ideal quando o DHCP troca o IP com frequência

### 3️⃣ [ APPS ]
* **`A1`**: **Brave Browser** — instalado via script oficial do fornecedor
* **`A2`**: **btop** — monitor avançado do sistema

### 4️⃣ [ DEV ] — Workstation Dev Completa
* **`D1`**: **Pacote Base Dev** — `git`, `curl`, `wget`, `unzip`, `build-essential`/`@development-tools`/`base-devel`, `procps`, `file`
* **`D2`**: **Docker + Docker Compose v2** — `docker.io`/`moby-engine`/`docker` + compose v2, serviço no boot e usuário real no grupo `docker`
* **`D3`**: **Distrobox** — contêineres estilo toolbox
* **`D4`**: **Homebrew (Linuxbrew)** — não-interativo em `/home/linuxbrew`, configurado no `.bashrc` do usuário real (inspirado no Bluefin Linux)
* **`D5`**: **Visual Studio Code** — via **Flatpak** universal (`com.visualstudio.code`)
* **`D6`**: **Obsidian** — via **Flatpak** universal (`md.obsidian.Obsidian`)
* **`D7`**: **OpenCode CLI** — instalador oficial (`opencode.ai`)
* **`D8`**: **Antigravity CLI** — instalador oficial (`antigravity.google`)

### 5️⃣ [ CONFIG ]
* **`C1`**: **JetBrainsMono Nerd Font** — fonte oficial com todos os glifos (estilo Omarchy) em `/usr/local/share/fonts/NerdFonts`
* **`C2`**: **Flatpak + Repositório Flathub** — base para apps flatpak
* **`C3`**: **GNOME Tweaks + Restricted Extras** — codecs multimídia e ajustes do GNOME (varia por distro)

### 6️⃣ [ PERFIS AUTOMATIZADOS ]
* **`P1`**: 🚀 **MODO BRNCZZR** — Workstation Dev Completa (base + apps + dev + config + atualização geral, executado em sequência)

---

## 🧩 Execuções em Lote

Na TUI, marque com `Espaço` e pressione `Enter`, ou digite os códigos separados por vírgula:

```text
║ ► [✓] 0    ATUALIZAÇÃO GERAL (apt/dnf/pacman)       ║
║   [ ] R1   HABILITAR SERVIDOR SSH                   ║
║   [✓] D1   PACOTE BASE DEV (build-essential)        ║
```

No modo headless:

```bash
sudo ./linux-toolbox.sh D1,D4,C1,P1
```

---

## 🔒 Boas Práticas & Segurança

- Requer privilégios de **root** na TUI (verificado automaticamente); `--preview` dispensa sudo.
- Suporta os **3 principais gerenciadores** (`apt`, `dnf`, `pacman`) com serviço correto (`ssh` vs `sshd`) e healthcheck com timeout no SSH.
- **Idempotência:** Homebrew não duplica linha no `.bashrc` (`grep -qF` antes de `>>`) e apps já instalados não são reinstalados.
- **Firewall tratado com UFW e firewalld**; se nenhum estiver ativo, avisa em vez de falhar.
- **Falhas de instalação são reportadas, nunca silenciosas** — o lote continua e mostra o que não confirmou.
- Nenhuma credencial trafega ou é registrada em texto plano.
- Estrutura modular extensível: novas ferramentas entram como novas opções no dispatcher.

---

## 📖 Runbooks (passos para copiar e colar)

* 🔑 **[Bootstrap SSH — Ubuntu recém-instalado](./runbooks/ssh-bootstrap-ubuntu.md)** — autoriza a chave pública do seu workstation e ativa o servidor SSH em máquinas formatadas, para acesso por nome (`ssh alienware`) em vez de IP.
* 🏛️ **[Archimedes no Alienware — Deploy Docker](./runbooks/archimedes-alienware-docker.md)** — instala o agente Archimedes V2 no Alienware inteiramente em containers (zero poluição do sistema), com GPU NVIDIA e serviço chamado `archimedes`.
* 🤖 **[Hermes Agent no Alienware — Estagiário Local](./runbooks/hermes-agent-alienware.md)** — instala o Hermes Agent (Nous Research) com modelo local `hermes3-64k` (Ollama/GPU RTX 5060), tool calling validado e custo R$ 0. Inclui os 2 fixes obrigatórios (venv + tool_search).
* 🤖 **[Google Antigravity CLI `agy` — Ubuntu](./runbooks/agy-cli-google.md)** — instala o CLI oficial do Google Antigravity em `~/.local/bin/agy` (sem sudo, checksum verificado, self-update) e guia o primeiro login via keyring/browser.
* 🏛️ **[Força do Archimedes no `agy` + Hermes Agent](./runbooks/agy-hermes-forca-opencode.md)** — leva as 4 skills, 3 subagentes, persona e o RAG semântico (MCP via streamable-http em `10.0.0.10:8765`) para o `agy` e o Hermes no Alienware, a partir do bundle portátil `plugins/archimedes-agent`.
* 🚚 **[Migração GEEKOM → Alienware (Archimedes V2 completo)](./runbooks/migracao-geekom-alienware.md)** — move cofre, RAG (+índice LanceDB), projetos, vault, notas e backups do workstation para o Alienware via `rsync`/git, e reaponta hermes/agy/opencode para o RAG local (`127.0.0.1:8765`).
* 🖥️ **[Atualização Proxmox & Repositório Comunidade](./runbooks/proxmox-update-no-subscription.md)** — ativa o repositório `pve-no-subscription`, remove aviso de licença pago e atualiza o Proxmox VE via SSH.

---

## 🗺️ Roadmap (próximas ferramentas)

* ⚡ **zRAM** — swap compactada em RAM (migração do ubuntu-autoinstall)
* 🛡️ **Snapshots & Resiliência** — Timeshift/Snapper + integração grub-btrfs no menu de boot
* 🧹 **Manutenção** — limpeza de cache, logs e pacotes órfãos
* 🎨 **Perfis adicionais** — estilo MODO PMA corporativo (espelhando o win-toolbox-tui)
* 🌐 **Suporte a Flatpak "restrito"** — instalação offline/air-gapped

---

## 👤 Autor

Desenvolvido por **Bruno César Medeiros Siqueira**  
*Analista de T.I. Pleno — Ariquemes/RO*  
GitHub: [@brcesarms](https://github.com/brcesarms)

## 📄 Licença

Distribuído sob licença [MIT](LICENSE).