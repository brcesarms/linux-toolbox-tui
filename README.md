# 🐧 linux-toolbox-tui — Caixa de Ferramentas & Pós-Instalação para Linux

> **Suporta:** Debian/Ubuntu (`apt`) · Fedora (`dnf`) · Arch/Omarchy (`pacman`)  
> Interface interativa de terminal (TUI) no **padrão visual do win-toolbox-tui**: abas organizadas (Sistema / Rede / Apps / Dev / Config / Perfis), bordas Unicode, **status dinâmico em tempo real** (`[✓]` Verde = instalado / `[ ]` Branco = pendente), detecção automática de distribuição e execução em lote — sem digitar comandos.

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

---

## 💎 Destaques Visuais & Experiência TUI

* 🟢 **Status Dinâmico em Tempo Real:** cada item exibe `[✓]` em Verde se já estiver instalado/ativo no sistema, ou `[ ]` em Branco se pendente — com cache de verificação para renderização instantânea.
* 📑 **Abas Organizadas estilo BIOS:** SISTEMA · REDE · APPS · DEV · CONFIG · PERFIS, com códigos por seção (R1, A1…, D1…, C1…, P1) — espelhando o `win-toolbox-tui`.
* 🟡 **Títulos em Negrito e Alto Contraste:** seções formatadas em negrito ANSI para leitura imediata.
* 📐 **Alinhamento de 90 Colunas:** grid calibrado com bordas Unicode arredondadas (`╭─`, `│`, `╰─`).
* 🔄 **Detecção Automática de Distro:** identifica `apt`, `dnf` ou `pacman` sozinho e usa o nome correto do serviço (`ssh` no Debian/Ubuntu, `sshd` no Fedora/Arch).
* 🧩 **Execução em Lote:** selecione várias opções separadas por vírgula (ex: `D1,D4,C1,P1`).
* 👤 **Usuário Real Respeitado:** Homebrew e grupo `docker` são configurados para o usuário `SUDO_USER`, não para root.

---

## 🎯 Estrutura Modular dos Menus (Abas estilo BIOS)

### 1️⃣ [ SISTEMA ]
* **`0`**: 🚀 **Atualização Geral** — atualiza todos os pacotes do sistema (`apt upgrade` / `dnf upgrade` / `pacman -Syu`)

### 2️⃣ [ REDE & ACESSO REMOTO ]
* **`R1`**: 🚀 **Habilitar Servidor SSH** — instala `openssh-server`, habilita o serviço no boot, libera a porta 22 no firewall (UFW/firewalld) e exibe o comando de conexão (`ssh usuario@IP`)

### 3️⃣ [ APPS ]
* **`A1`**: **Brave Browser** — instalado via script oficial do fornecedor
* **`A2`**: **btop** — monitor avançado do sistema

### 4️⃣ [ DEV ] — Workstation Dev Completa
* **`D1`**: **Pacote Base Dev** — `git`, `curl`, `wget`, `unzip`, `build-essential`/`@development-tools`/`base-devel`, `procps`, `file`
* **`D2`**: **Docker + Docker Compose v2** — `docker.io`/`moby-engine`/`docker` + compose v2, serviço habilitado no boot e usuário real adicionado ao grupo `docker`
* **`D3`**: **Distrobox** — contêineres estilo toolbox
* **`D4`**: **Homebrew (Linuxbrew)** — instalado de forma não-interativa em `/home/linuxbrew`, configurado no `.bashrc` do usuário real (inspirado no Bluefin Linux)
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

Selecione várias opções separadas por vírgula em qualquer menu:
```text
╭─ Selecione as opções separadas por vírgula (ex: D1,D4,C1,P1)
╰─❯ D1,D4,C1,P1
```

---

## 🔒 Boas Práticas & Segurança

- Requer privilégios de **root** (executar com `sudo`) — verificado automaticamente pelo script.
- Suporta os **3 principais gerenciadores de pacotes** (`apt`, `dnf`, `pacman`) com o serviço correto para cada distro (`ssh` vs `sshd`) e healthcheck com timeout no serviço SSH.
- **Idempotência:** Homebrew não duplica linha no `.bashrc` (`grep -qF` antes de `>>`) e apps já instalados não são reinstalados.
- **Firewall tratado com UFW e firewalld** (os dois mais comuns); se nenhum estiver ativo, avisa em vez de falhar.
- **Falhas de instalação são reportadas, nunca silenciosas** — o lote continua e mostra o que não foi confirmado.
- Nenhuma credencial trafega ou é registrada em log em texto plano.
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