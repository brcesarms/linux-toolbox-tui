# 🐧 linux-toolbox-tui — Caixa de Ferramentas & Pós-Instalação para Linux

> **Suporta:** Debian/Ubuntu (`apt`) · Fedora (`dnf`) · Arch/Omarchy (`pacman`)  
> Interface **TUI estilo Setup Utility (BIOS)** no padrão do `win-toolbox-tui`: bordas duplas `╔═╗`, cursor em **bloco verde**, painel lateral **Item Help**, abas com atalhos, paginação (21 itens), **status dinâmico** (`[✓]` Verde = instalado) e execução em lote — o mesmo visual, agora em bash puro.

---

## ⚡ Execução Rápida (One-Liner)

No terminal do Linux, como **root ou com sudo**:

```bash
bash <(curl -s https://raw.githubusercontent.com/brcesarms/linux-toolbox-tui/main/linux-toolbox.sh)
```

Ou execute localmente clonando o repositório:

```bash
git clone https://github.com/brcesarms/linux-toolbox-tui.git
cd linux-toolbox-tui
chmod +x linux-toolbox.sh
sudo ./linux-toolbox.sh
```

**Sem sudo / apenas visualizar:**

```bash
./linux-toolbox.sh --preview    # renderiza a tela sem instalar nada
./linux-toolbox.sh D1,D4,P1     # modo headless: executa códigos direto
```

---

## 💎 Destaques Visuais & Experiência TUI (V3.0)

* 🖥️ **Tela Alternativa:** usa `tput smcup`/`rmcup` — o prompt do shell não suja o terminal ao sair.
* 🟩 **Cursor em Bloco Verde:** a linha selecionada ganha fundo verde estilo Setup (igual ao `win-toolbox.ps1`).
* 📋 **Painel Item Help (direita):** descrição, método/pacote, categoria e status de cada item — atualizado conforme você navega.
* 🟡 **Aba Ativa em Fundo Âmbar:** `[ SISTEMA ] [ REDE ] ...` com a aba atual destacada.
* 📑 **6 Abas com Atalhos:** `S`istema · `R`ede · `A`pps · `D`ev · `C`onfig · `P`erfis (ou `1..6`).
* 🟢 **Status Dinâmico em Tempo Real:** `[✓]` Verde = instalado/ativo; `[ ]` = pendente — com cache de verificação para renderização instantânea.
* 📐 **Grid de 100 Colunas:** bordas duplas Unicode `╔═╗ ║ ╠ ╣` e paginação com 21 linhas/aba.
* 🔄 **Detecção Automática de Distro:** identifica `apt`, `dnf` ou `pacman` e o serviço correto (`ssh` vs `sshd`).
* 🧩 **Execução em Lote:** marca com `Espaço` ou digita códigos separados por vírgula (ex: `D1,D4,C1,P1`).
* ⏭️ **Modo Headless:** `./linux-toolbox.sh S,R1,D1,D4` executa direto, sem remontar a tela (espelha o `-ExecutarLote` do win).
* 👤 **Usuário Real Respeitado:** Homebrew e grupo `docker` são configurados para `SUDO_USER`, não para root.

### 🕹️ Teclas de Navegação

| Tecla | Ação |
| :--- | :--- |
| `↑` / `↓` | Mover seleção (com rolagem por página) |
| `←` / `→` | Trocar aba |
| `Espaço` | Marcar/desmarcar item para a fila `[✓]` |
| `Enter` | Executar item(s) selecionado(s) |
| `Q` / `Esc` | Sair |

---

## 🎯 Estrutura Modular dos Menus (Abas estilo BIOS)

### 1️⃣ [ SISTEMA ]
* **`0`**: 🚀 **Atualização Geral** — atualiza todos os pacotes (`apt upgrade` / `dnf upgrade` / `pacman -Syu`)

### 2️⃣ [ REDE & ACESSO REMOTO ]
* **`R1`**: 🚀 **Habilitar Servidor SSH** — instala `openssh-server`, habilita no boot, libera porta 22 no firewall (UFW/firewalld) e exibe o comando de conexão (`ssh usuario@IP`)

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