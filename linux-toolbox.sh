#!/bin/bash
#
# ==============================================================================
# LINUX-TOOLBOX-TUI V2.0 — Caixa de Ferramentas & Pós-Instalação para Linux
# ==============================================================================
# Script interativo com interface TUI (Unicode Box Drawing) no padrão visual
# do win-toolbox-tui: abas organizadas (Apps / Dev / Config / Perfis), status
# dinâmico de tarefas ([✓] Verde = instalado / [ ] Branco = pendente), títulos
# em negrito ANSI e detecção automática de distribuição.
#
# Distribuições suportadas:
#   - Debian / Ubuntu (apt)      → serviço: ssh
#   - Fedora (dnf)               → serviço: sshd
#   - Arch / Omarchy (pacman)    → serviço: sshd
#
# Ferramentas migradas do ubuntu-autoinstall (workstation dev):
#   Brave, btop, Base Dev, Docker+Compose, Distrobox, Homebrew, VS Code,
#   Obsidian, OpenCode CLI, Antigravity CLI, Nerd Font, Flatpak/Flathub,
#   GNOME Tweaks + Restricted Extras.
#
# AUTOR: Bruno César Medeiros Siqueira <bruno.cesar@outlook.it>
# VERSÃO: 2.0.0
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 1. CORES ANSI & VARIÁVEIS GLOBAIS
# ==============================================================================
# Sem cor se não for terminal
if [ ! -t 1 ]; then
    C_RESET=''
    C_CYAN=''
    C_DARKCYAN=''
    C_GREEN=''
    C_YELLOW=''
    C_RED=''
    C_GRAY=''
    C_BOLD=''
    C_NORM=''
else
    C_RESET='\033[0m'
    C_CYAN='\033[36m'
    C_DARKCYAN='\033[36m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
    C_GRAY='\033[37m'
    C_BOLD='\033[1;93m'
    C_NORM='\033[22m'
fi
export C_RESET C_CYAN C_DARKCYAN C_GREEN C_YELLOW C_RED C_GRAY C_BOLD C_NORM

declare -g -A INSTALLED_CACHE=()
declare -g DISTRO_ID=""
declare -g PKG_MGR=""
declare -g SSH_SERVICE="ssh"
declare -g REAL_USER=""
declare -g MENU_ATUAL="MAIN"

# ==============================================================================
# 2. DETECÇÃO DE DISTRIBUIÇÃO, PRIVILÉGIOS E USUÁRIO REAL
# ==============================================================================
detectar_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091 # fonte segura: /etc/os-release padrão do sistema
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
    else
        DISTRO_ID="unknown"
    fi

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop)
            PKG_MGR="apt"
            SSH_SERVICE="ssh"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            PKG_MGR="dnf"
            SSH_SERVICE="sshd"
            ;;
        arch|manjaro|omarchy|endeavouros)
            PKG_MGR="pacman"
            SSH_SERVICE="sshd"
            ;;
        *)
            PKG_MGR="unknown"
            SSH_SERVICE="sshd"
            ;;
    esac
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf "\n${C_YELLOW}[!] Privilégios de root são necessários.${C_RESET}\n"
        printf "${C_CYAN}[*] Use: sudo %s${C_RESET}\n\n" "$0"
        exit 1
    fi
}

# Detectar o usuário "real" (SUDO_USER quando rodar com sudo) para ações
# que pertencem à conta do usuário (Homebrew, grupo docker)
detectar_usuario_real() {
    if [ -n "${SUDO_USER:-}" ]; then
        REAL_USER="$SUDO_USER"
    else
        REAL_USER="$(id -un)"
    fi
}

# Helper: home directory do usuário real
home_usuario() {
    if [ "$REAL_USER" = "root" ]; then
        printf '/root'
    else
        getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6
    fi
}

# ==============================================================================
# 3. RENDERIZADORES TUI
# ==============================================================================
# Largura interna da caixa: 88 caracteres (bordas │ + conteúdo = 90 colunas)
W_INTERNO=88

printf_linha() {
    local text="$1"
    local color="${2:-$C_GRAY}"
    local clean
    clean="$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')"
    local len
    len="$(printf '%s' "$clean" | wc -m)"
    printf "${C_CYAN}│${C_RESET}${C_NORM}${color}${clean}${C_RESET}"
    printf '%*s' $((W_INTERNO - len)) ''
    printf "${C_CYAN}│${C_RESET}\n"
}

show_header() {
    local subtitulo="${1:-MENU PRINCIPAL}"
    clear

    local data
    data="$(date +%d/%m/%Y)"
    local host
    host="$(hostname)"
    local user
    user="$(id -un)"
    local ip
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="N/A"

    local clean_data=" Data: $data  |  Computador: $host  |  Usuário: $user  |  IP: $ip"
    local len_data
    len_data="$(printf '%s' "$clean_data" | wc -m)"
    local clean_tela=" TELA: $subtitulo"
    local len_tela
    len_tela="$(printf '%s' "$clean_tela" | wc -m)"

    printf "${C_CYAN}╭─ LINUX-TOOLBOX-TUI V2.0 ───────────────────────────────────────────────── [ LINUX ] ─╮${C_RESET}\n"
    printf "${C_CYAN}│${C_RESET}${C_NORM}${C_GRAY} TELA: %s" "$subtitulo"
    printf '%*s' $((W_INTERNO - len_tela)) ''
    printf "${C_CYAN}│${C_RESET}\n"
    printf "${C_CYAN}│${C_RESET}${C_GRAY} Data: %s  |  Computador: %s  |  Usuário: %s  |  IP: %s" "$data" "$host" "$user" "$ip"
    printf '%*s' $((W_INTERNO - len_data)) ''
    printf "${C_CYAN}│${C_RESET}\n"
    printf "${C_CYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"
}

wait_user() {
    printf "\n${C_GRAY}[Pressione ENTER para continuar...]${C_RESET}\n"
    read -r _
}

# ==============================================================================
# 4. CACHE DE DETECÇÃO DE STATUS ([✓] instalado / [ ] pendente)
# ==============================================================================
testa_status() {
    local key="$1"
    if [ -n "${INSTALLED_CACHE[$key]+x}" ]; then
        [ "${INSTALLED_CACHE[$key]}" = "1" ]
        return $?
    fi

    local result=1
    case "$key" in
        sshd)
            systemctl is-active "$SSH_SERVICE" >/dev/null 2>&1 && result=0
            ;;
        brave)
            command -v brave-browser >/dev/null 2>&1 && result=0
            ;;
        btop)
            command -v btop >/dev/null 2>&1 && result=0
            ;;
        base)
            command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 \
                && command -v wget >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1 \
                && command -v make >/dev/null 2>&1 && result=0
            ;;
        docker)
            command -v docker >/dev/null 2>&1 && result=0
            ;;
        distrobox)
            command -v distrobox >/dev/null 2>&1 && result=0
            ;;
        brew)
            local h
            h="$(home_usuario)"
            { [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ] || [ -x "${h}/.linuxbrew/bin/brew" ]; } && result=0
            ;;
        vscode)
            command -v code >/dev/null 2>&1 && result=0
            command -v flatpak >/dev/null 2>&1 && flatpak info com.visualstudio.code >/dev/null 2>&1 && result=0
            ;;
        obsidian)
            command -v obsidian >/dev/null 2>&1 && result=0
            command -v flatpak >/dev/null 2>&1 && flatpak info md.obsidian.Obsidian >/dev/null 2>&1 && result=0
            ;;
        opencode)
            command -v opencode >/dev/null 2>&1 && result=0
            ;;
        antigravity)
            command -v antigravity >/dev/null 2>&1 && result=0
            ;;
        nerdfont)
            fc-list 2>/dev/null | grep -qi "JetBrainsMono" && result=0
            ;;
        flatpak)
            command -v flatpak >/dev/null 2>&1 && flatpak remotes 2>/dev/null | grep -qi "flathub" && result=0
            ;;
        tweaks)
            command -v gnome-tweaks >/dev/null 2>&1 && result=0
            ;;
        *)
            result=1
            ;;
    esac

    if [ "$result" -eq 0 ]; then
        INSTALLED_CACHE[$key]=1
    else
        INSTALLED_CACHE[$key]=0
    fi
    return "$result"
}

get_item_display() {
    local code="$1" title="$2" key="$3"
    if testa_status "$key"; then
        printf " ${C_GREEN}[✓]${C_RESET} ${code}. ${title}"
    else
        printf " [ ] ${code}. ${title}"
    fi
}

# ==============================================================================
# 5. HELPER MULTI-DISTRO DE INSTALAÇÃO DE PACOTES
# ==============================================================================
# Uso: instalar_pacotes "pacotes_apt" "pacotes_dnf" "pacotes_pacman"
instalar_pacotes() {
    local lista=""
    case "$PKG_MGR" in
        apt)    lista="$1" ;;
        dnf)    lista="$2" ;;
        pacman) lista="$3" ;;
        *)
            printf "${C_RED}[!] Gerenciador de pacotes desconhecido (${PKG_MGR}).${C_RESET}\n"
            return 1
            ;;
    esac

    [ -z "$lista" ] && return 0

    printf "${C_YELLOW}[+] Instalando via ${PKG_MGR}: ${lista}${C_RESET}\n"
    # shellcheck disable=SC2086 # intencional: expansão de lista de pacotes em word splitting
    case "$PKG_MGR" in
        apt)
            apt-get update -y >/dev/null 2>&1 || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y $lista >/dev/null 2>&1 \
                || printf "${C_RED}[!] Falha ao instalar pacotes (apt): ${lista}${C_RESET}\n"
            ;;
        dnf)
            dnf install -y $lista >/dev/null 2>&1 \
                || printf "${C_RED}[!] Falha ao instalar pacotes (dnf): ${lista}${C_RESET}\n"
            ;;
        pacman)
            pacman -Sy --noconfirm $lista >/dev/null 2>&1 \
                || printf "${C_RED}[!] Falha ao instalar pacotes (pacman): ${lista}${C_RESET}\n"
            ;;
    esac
}

# ==============================================================================
# 6. FUNÇÕES DE FERRAMENTAS (migradas do ubuntu-autoinstall)
# ==============================================================================

# ---------- 0. ATUALIZAÇÃO GERAL ----------
atualizacao_geral() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] ATUALIZANDO O SISTEMA (${PKG_MGR})${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"

    case "$PKG_MGR" in
        apt)
            apt-get update -y >/dev/null 2>&1 || true
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
            ;;
        dnf)
            dnf upgrade -y
            ;;
        pacman)
            pacman -Syu --noconfirm
            ;;
        *)
            printf "${C_RED}[!] Gerenciador de pacotes desconhecido.${C_RESET}\n"
            return 1
            ;;
    esac

    printf "${C_GREEN}[✓] Atualização geral concluída!${C_RESET}\n"
}

# ---------- R1. SERVIDOR SSH ----------
habilitar_servidor_ssh() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] HABILITANDO SERVIDOR SSH NO LINUX${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"

    # ---------- Passo 1/4: Instalar OpenSSH Server ----------
    printf "${C_GRAY}[1/4] Verificando OpenSSH Server...${C_RESET}\n"
    printf "${C_GRAY}[+] Distribuição detectada: ${DISTRO_ID} (gerenciador: ${PKG_MGR})${C_RESET}\n"

    if command -v sshd >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -qE "^(ssh|sshd)\.service"; then
        printf "${C_GREEN}[✓] OpenSSH Server já está instalado.${C_RESET}\n"
    else
        instalar_pacotes "openssh-server" "openssh-server" "openssh"
    fi

    # ---------- Passo 2/4: Habilitar e iniciar o serviço ----------
    printf "${C_GRAY}[2/4] Habilitando e iniciando o serviço ${SSH_SERVICE}...${C_RESET}\n"
    systemctl enable "$SSH_SERVICE" >/dev/null 2>&1 || true
    systemctl start "$SSH_SERVICE" >/dev/null 2>&1 || true

    # Healthcheck com timeout (máx. 10 tentativas)
    local j=0
    while ! systemctl is-active "$SSH_SERVICE" >/dev/null 2>&1 && [ $j -lt 10 ]; do
        sleep 1
        j=$((j + 1))
    done

    if systemctl is-active "$SSH_SERVICE" >/dev/null 2>&1; then
        printf "${C_GREEN}[✓] Serviço ${SSH_SERVICE} ativo e configurado para iniciar no boot!${C_RESET}\n"
        INSTALLED_CACHE[sshd]=1
    else
        printf "${C_RED}[!] Serviço ${SSH_SERVICE} não está ativo. Verifique: systemctl status ${SSH_SERVICE}${C_RESET}\n"
    fi

    # ---------- Passo 3/4: Firewall ----------
    printf "${C_GRAY}[3/4] Configurando firewall para permitir SSH (porta 22 TCP)...${C_RESET}\n"
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "Status: active"; then
        ufw allow ssh >/dev/null 2>&1
        printf "${C_GREEN}[✓] UFW: regra para SSH adicionada.${C_RESET}\n"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        printf "${C_GREEN}[✓] firewalld: regra para SSH adicionada.${C_RESET}\n"
    else
        printf "${C_GRAY}[i] Nenhum firewall ativo detectado (UFW/firewalld) — nada a liberar.${C_RESET}\n"
    fi

    # ---------- Passo 4/4: Resumo e credenciais de conexão ----------
    printf "${C_GRAY}[4/4] Coletando informações de conexão...${C_RESET}\n"
    local ip
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="N/A"

    printf "\n${C_GREEN}========================================================${C_RESET}\n"
    printf "${C_GREEN} [✓] SERVIDOR SSH CONFIGURADO E PRONTO PARA CONEXÃO!${C_RESET}\n"
    printf "${C_RESET}     Comando para conectar de outro computador:${C_RESET}\n"
    printf "${C_YELLOW}     ssh %s@%s${C_RESET}\n" "$REAL_USER" "$ip"
    printf "${C_GREEN}========================================================${C_RESET}\n"
}

# ---------- A1. BRAVE BROWSER ----------
instalar_brave() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO BRAVE BROWSER (script oficial)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status brave; then
        printf "${C_GREEN}[✓] Brave Browser já está instalado.${C_RESET}\n"
        return
    fi

    printf "${C_GRAY}[1/2] Baixando e executando instalador oficial...${C_RESET}\n"
    if sh -c 'curl -fsS https://dl.brave.com/install.sh | sh' >/dev/null 2>&1; then
        INSTALLED_CACHE[brave]=1
        printf "${C_GREEN}[✓] Brave Browser instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Falha na instalação automática. Instale manualmente: https://brave.com/linux/${C_RESET}\n"
    fi
}

# ---------- A2. BTOP ----------
instalar_btop() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO BTOP (monitor do sistema)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status btop; then
        printf "${C_GREEN}[✓] btop já está instalado.${C_RESET}\n"
        return
    fi

    instalar_pacotes "btop" "btop" "btop"
    if command -v btop >/dev/null 2>&1; then
        INSTALLED_CACHE[btop]=1
        printf "${C_GREEN}[✓] btop instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Não foi possível confirmar a instalação do btop.${C_RESET}\n"
    fi
}

# ---------- D1. PACOTE BASE DEV ----------
instalar_base_dev() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO PACOTE BASE DEV (git, curl, build...)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status base; then
        printf "${C_GREEN}[✓] Pacote base dev já está instalado.${C_RESET}\n"
        return
    fi

    instalar_pacotes \
        "git wget curl unzip build-essential procps file" \
        "git wget curl unzip @development-tools procps-ng file" \
        "git wget curl unzip base-devel procps-ng file"

    if command -v git >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
        INSTALLED_CACHE[base]=1
        printf "${C_GREEN}[✓] Pacote base dev instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Não foi possível confirmar a instalação da base dev.${C_RESET}\n"
    fi
}

# ---------- D2. DOCKER + DOCKER COMPOSE V2 ----------
instalar_docker() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO DOCKER + DOCKER COMPOSE V2${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status docker; then
        printf "${C_GREEN}[✓] Docker já está instalado.${C_RESET}\n"
    else
        instalar_pacotes \
            "docker.io docker-compose-v2" \
            "moby-engine docker-compose" \
            "docker docker-compose docker-buildx"

        if command -v docker >/dev/null 2>&1; then
            INSTALLED_CACHE[docker]=1
            printf "${C_GREEN}[✓] Docker instalado com sucesso!${C_RESET}\n"
        else
            printf "${C_YELLOW}[!] Não foi possível confirmar a instalação do Docker.${C_RESET}\n"
        fi
    fi

    # Habilitar e iniciar o serviço
    printf "${C_GRAY}[+] Habilitando e iniciando o serviço docker...${C_RESET}\n"
    systemctl enable docker >/dev/null 2>&1 || true
    systemctl start docker >/dev/null 2>&1 || true

    # Grupo docker para o usuário real (idempotente)
    printf "${C_GRAY}[+] Adicionando '${REAL_USER}' ao grupo docker...${C_RESET}\n"
    if [ "$REAL_USER" != "root" ]; then
        usermod -aG docker "$REAL_USER" 2>/dev/null || true
        printf "${C_YELLOW}[i] Refaça o login (ou execute 'newgrp docker') para usar docker sem sudo.${C_RESET}\n"
    fi
}

# ---------- D3. DISTROBOX ----------
instalar_distrobox() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO DISTROBOX (contêineres estilo toolbox)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status distrobox; then
        printf "${C_GREEN}[✓] Distrobox já está instalado.${C_RESET}\n"
        return
    fi

    instalar_pacotes "distrobox" "distrobox" "distrobox"
    if command -v distrobox >/dev/null 2>&1; then
        INSTALLED_CACHE[distrobox]=1
        printf "${C_GREEN}[✓] Distrobox instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Não foi possível confirmar a instalação do Distrobox.${C_RESET}\n"
    fi
}

# ---------- D4. HOMEBREW (LINUXBREW) ----------
instalar_homebrew() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO HOMEBREW (Linuxbrew)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status brew; then
        printf "${C_GREEN}[✓] Homebrew já está instalado.${C_RESET}\n"
        return
    fi

    local h
    h="$(home_usuario)"
    local grupo
    grupo="$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")"
    printf "${C_GRAY}[1/3] Preparando diretório /home/linuxbrew para o usuário ${REAL_USER}...${C_RESET}\n"
    mkdir -p /home/linuxbrew/.linuxbrew
    chown -R "$REAL_USER":"$grupo" /home/linuxbrew 2>/dev/null || true

    printf "${C_GRAY}[2/3] Executando instalador oficial (não-interativo)...${C_RESET}\n"
    if su - "$REAL_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >/dev/null 2>&1; then
        # Configura o shell do usuário (idempotente — não duplica linha)
        printf "${C_GRAY}[3/3] Configurando .bashrc do usuário ${REAL_USER}...${C_RESET}\n"
        local bashrc="${h}/.bashrc"
        # shellcheck disable=SC2016 # intencional: $() deve expandir quando o .bashrc rodar
        if ! grep -qF 'brew shellenv' "$bashrc" 2>/dev/null; then
            printf 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' >> "$bashrc"
        fi
        INSTALLED_CACHE[brew]=1
        printf "${C_GREEN}[✓] Homebrew instalado e configurado no ${bashrc}!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Falha na instalação do Homebrew. Verifique a conexão e a base dev.${C_RESET}\n"
    fi
}

# ---------- D5. VS CODE (FLATPAK UNIVERSAL) ----------
instalar_vscode() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO VISUAL STUDIO CODE (Flatpak)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status vscode; then
        printf "${C_GREEN}[✓] VS Code já está instalado.${C_RESET}\n"
        return
    fi

    garantindo_flatpak
    printf "${C_GRAY}[+] Instalando com.visualstudio.code via Flatpak...${C_RESET}\n"
    if flatpak install -y flathub com.visualstudio.code >/dev/null 2>&1; then
        INSTALLED_CACHE[vscode]=1
        printf "${C_GREEN}[✓] VS Code instalado com sucesso! (flatpak run com.visualstudio.code)${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Falha na instalação do VS Code via Flatpak.${C_RESET}\n"
    fi
}

# ---------- D6. OBSIDIAN (FLATPAK UNIVERSAL) ----------
instalar_obsidian() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO OBSIDIAN (Flatpak)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status obsidian; then
        printf "${C_GREEN}[✓] Obsidian já está instalado.${C_RESET}\n"
        return
    fi

    garantindo_flatpak
    printf "${C_GRAY}[+] Instalando md.obsidian.Obsidian via Flatpak...${C_RESET}\n"
    if flatpak install -y flathub md.obsidian.Obsidian >/dev/null 2>&1; then
        INSTALLED_CACHE[obsidian]=1
        printf "${C_GREEN}[✓] Obsidian instalado com sucesso! (flatpak run md.obsidian.Obsidian)${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Falha na instalação do Obsidian via Flatpak.${C_RESET}\n"
    fi
}

# ---------- D7. OPENCODE CLI ----------
instalar_opencode() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO OPENCODE CLI${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status opencode; then
        printf "${C_GREEN}[✓] OpenCode CLI já está instalado.${C_RESET}\n"
        return
    fi

    printf "${C_GRAY}[+] Executando instalador oficial (opencode.ai)...${C_RESET}\n"
    if sh -c 'curl -fsSL https://opencode.ai/install | bash' >/dev/null 2>&1; then
        INSTALLED_CACHE[opencode]=1
        printf "${C_GREEN}[✓] OpenCode CLI instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Falha na instalação do OpenCode CLI.${C_RESET}\n"
    fi
}

# ---------- D8. ANTIGRAVITY CLI ----------
instalar_antigravity() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO ANTIGRAVITY CLI${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status antigravity; then
        printf "${C_GREEN}[✓] Antigravity CLI já está instalado.${C_RESET}\n"
        return
    fi

    printf "${C_GRAY}[+] Executando instalador oficial (antigravity.google)...${C_RESET}\n"
    if sh -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash' >/dev/null 2>&1; then
        INSTALLED_CACHE[antigravity]=1
        printf "${C_GREEN}[✓] Antigravity CLI instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Falha na instalação do Antigravity CLI.${C_RESET}\n"
    fi
}

# ---------- C1. JETBRAINSMONO NERD FONT ----------
instalar_nerdfont() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO JETBRAINSMONO NERD FONT (estilo Omarchy)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status nerdfont; then
        printf "${C_GREEN}[✓] JetBrainsMono Nerd Font já está instalada.${C_RESET}\n"
        return
    fi

    printf "${C_GRAY}[1/3] Criando diretório de fontes...${C_RESET}\n"
    mkdir -p /usr/local/share/fonts/NerdFonts

    printf "${C_GRAY}[2/3] Baixando JetBrainsMono.zip (release oficial)...${C_RESET}\n"
    if curl -fLo /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip >/dev/null 2>&1; then
        unzip -o /tmp/JetBrainsMono.zip -d /usr/local/share/fonts/NerdFonts >/dev/null 2>&1
        rm -f /tmp/JetBrainsMono.zip
    else
        printf "${C_YELLOW}[!] Falha no download da Nerd Font.${C_RESET}\n"
        return
    fi

    printf "${C_GRAY}[3/3] Atualizando cache de fontes...${C_RESET}\n"
    fc-cache -fv >/dev/null 2>&1

    if fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
        INSTALLED_CACHE[nerdfont]=1
        printf "${C_GREEN}[✓] JetBrainsMono Nerd Font instalada e ativa!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Fonte instalada, mas não detectada no fc-list.${C_RESET}\n"
    fi
}

# ---------- C2. FLATPAK + FLATHUB ----------
garantindo_flatpak() {
    # Helper: garante flatpak + flathub antes de instalar apps flatpak
    if ! command -v flatpak >/dev/null 2>&1; then
        printf "${C_GRAY}[+] Instalando Flatpak...${C_RESET}\n"
        instalar_pacotes "flatpak" "flatpak" "flatpak"
    fi
    if ! flatpak remotes 2>/dev/null | grep -qi "flathub"; then
        printf "${C_GRAY}[+] Ativando repositório Flathub...${C_RESET}\n"
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    fi
    INSTALLED_CACHE[flatpak]=1
}

instalar_flatpak() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO FLATPAK + REPOSITÓRIO FLATHUB${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status flatpak; then
        printf "${C_GREEN}[✓] Flatpak + Flathub já estão configurados.${C_RESET}\n"
        return
    fi

    garantindo_flatpak
    if flatpak remotes 2>/dev/null | grep -qi "flathub"; then
        printf "${C_GREEN}[✓] Flatpak + Flathub configurados com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Não foi possível confirmar o Flathub.${C_RESET}\n"
    fi
}

# ---------- C3. GNOME TWEAKS + RESTRICTED EXTRAS ----------
instalar_gnome_tweaks() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] INSTALANDO GNOME TWEAKS (e codecs restritos onde aplicável)${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"
    if testa_status tweaks; then
        printf "${C_GREEN}[✓] GNOME Tweaks já está instalado.${C_RESET}\n"
        return
    fi

    case "$PKG_MGR" in
        apt)
            instalar_pacotes "gnome-tweaks ubuntu-restricted-extras" "" ""
            ;;
        dnf)
            instalar_pacotes "" "gnome-tweaks" ""
            printf "${C_GRAY}[i] Fedora: codecs proprietários via RPM Fusion (manual).${C_RESET}\n"
            ;;
        pacman)
            instalar_pacotes "" "" "gnome-tweaks"
            printf "${C_GRAY}[i] Arch: codecs proprietários via AUR (ex: ttf-ms-fonts).${C_RESET}\n"
            ;;
    esac

    if command -v gnome-tweaks >/dev/null 2>&1; then
        INSTALLED_CACHE[tweaks]=1
        printf "${C_GREEN}[✓] GNOME Tweaks instalado com sucesso!${C_RESET}\n"
    else
        printf "${C_YELLOW}[!] Não foi possível confirmar a instalação do GNOME Tweaks.${C_RESET}\n"
    fi
}

# ---------- P1. PERFIL DEV COMPLETO (MODO BRNCZZR) ----------
perfil_dev_completo() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] PERFIL DEV COMPLETO (MODO BRNCZZR)${C_RESET}\n"
    printf "${C_CYAN}[*] Instalando workstation dev completa — pode demorar...${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"

    instalar_base_dev
    instalar_flatpak
    instalar_nerdfont
    instalar_brave
    instalar_btop
    instalar_docker
    instalar_distrobox
    instalar_homebrew
    instalar_vscode
    instalar_obsidian
    instalar_opencode
    instalar_antigravity
    instalar_gnome_tweaks
    atualizacao_geral

    printf "\n${C_GREEN}========================================================${C_RESET}\n"
    printf "${C_GREEN} [✓] PERFIL DEV COMPLETO CONCLUÍDO!${C_RESET}\n"
    printf "${C_GREEN}========================================================${C_RESET}\n"
}

# ==============================================================================
# 7. DISPATCHER DE TAREFAS
# ==============================================================================
execute_single_option() {
    local opcao="$1"
    local op
    op="$(echo "$opcao" | tr '[:lower:]' '[:upper:]' | xargs)"

    case "$op" in
        "0")  atualizacao_geral ;;
        "R1") habilitar_servidor_ssh ;;
        "A1") instalar_brave ;;
        "A2") instalar_btop ;;
        "D1") instalar_base_dev ;;
        "D2") instalar_docker ;;
        "D3") instalar_distrobox ;;
        "D4") instalar_homebrew ;;
        "D5") instalar_vscode ;;
        "D6") instalar_obsidian ;;
        "D7") instalar_opencode ;;
        "D8") instalar_antigravity ;;
        "C1") instalar_nerdfont ;;
        "C2") instalar_flatpak ;;
        "C3") instalar_gnome_tweaks ;;
        "P1") perfil_dev_completo ;;
        "Q")  MENU_ATUAL="EXIT" ;;
        "V")  MENU_ATUAL="MAIN" ;;
        *)
            printf "${C_RED}[!] Opção '%s' não reconhecida.${C_RESET}\n" "$opcao"
            ;;
    esac
}

execute_batch_options() {
    local lote="$1"
    local IFS=','

    for item in $lote; do
        local op
        op="$(echo "$item" | xargs)"
        if [ -n "$op" ]; then
            execute_single_option "$op"
        fi
    done
}

dispatch_execution() {
    local escolha="$1"
    if [ -z "$escolha" ]; then
        return
    fi

    # Em modo loop, executamos direto sem janela separada
    printf "\n${C_CYAN}╭─ EXECUTANDO TAREFAS SELECIONADAS ${C_RESET}"
    printf '%*s' $((50 - ${#escolha})) ''
    printf "${C_CYAN}[ PROCESSO ATIVO ] ─╮${C_RESET}\n"
    printf_linha " Lote em andamento: $escolha" "$C_YELLOW"
    printf "${C_CYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    execute_batch_options "$escolha"
    INSTALLED_CACHE=()
    wait_user
}

# ==============================================================================
# 8. MENU PRINCIPAL (ABAS ESTILO WIN-TOOLBOX-TUI)
# ==============================================================================
menu_principal() {
    show_header "MENU PRINCIPAL — PÓS-INSTALAÇÃO & WORKSTATION DEV"

    printf "${C_CYAN}╭────────────────────────────────────────────────────────────────────────────────────────╮${C_RESET}\n"

    # ----- Seção: SISTEMA -----
    printf_linha " SISTEMA" "$C_BOLD"
    printf_linha " [ ] 0. Atualização Geral (apt/dnf/pacman)" "$C_NORM"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"

    # ----- Seção: REDE & ACESSO -----
    printf_linha " REDE & ACESSO REMOTO" "$C_BOLD"
    printf_linha "$(get_item_display "R1" "Habilitar Servidor SSH (openssh-server + firewall + IP)" "sshd")"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"

    # ----- Seção: APPS -----
    printf_linha " APPS [APPS]" "$C_BOLD"
    printf_linha "$(get_item_display "A1" "Brave Browser (script oficial)" "brave")"
    printf_linha "$(get_item_display "A2" "btop (monitor do sistema)" "btop")"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"

    # ----- Seção: DEV -----
    printf_linha " DEV [DESENVOLVIMENTO]" "$C_BOLD"
    printf_linha "$(get_item_display "D1" "Pacote Base Dev (git, curl, wget, unzip, build-essential)" "base")"
    printf_linha "$(get_item_display "D2" "Docker + Docker Compose v2 (grupo docker)" "docker")"
    printf_linha "$(get_item_display "D3" "Distrobox (contêineres estilo toolbox)" "distrobox")"
    printf_linha "$(get_item_display "D4" "Homebrew / Linuxbrew (gestor de pacotes secundário)" "brew")"
    printf_linha "$(get_item_display "D5" "Visual Studio Code (Flatpak)" "vscode")"
    printf_linha "$(get_item_display "D6" "Obsidian (Flatpak)" "obsidian")"
    printf_linha "$(get_item_display "D7" "OpenCode CLI (oficial)" "opencode")"
    printf_linha "$(get_item_display "D8" "Antigravity CLI (oficial)" "antigravity")"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"

    # ----- Seção: CONFIG -----
    printf_linha " CONFIG [CONFIGURAÇÕES]" "$C_BOLD"
    printf_linha "$(get_item_display "C1" "JetBrainsMono Nerd Font (estilo Omarchy)" "nerdfont")"
    printf_linha "$(get_item_display "C2" "Flatpak + Repositório Flathub" "flatpak")"
    printf_linha "$(get_item_display "C3" "GNOME Tweaks + Restricted Extras (codecs)" "tweaks")"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"

    # ----- Seção: PERFIS -----
    printf_linha " PERFIS AUTOMATIZADOS" "$C_BOLD"
    printf_linha " P1. 🚀 MODO BRNCZZR — Workstation Dev Completa (tudo acima)" "$C_YELLOW"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"

    # ----- Navegação -----
    printf_linha " NAVEGAÇÃO:   [Q] Sair   |   Lote: vírgula (ex: D1,D4,C1,P1)" "$C_YELLOW"
    printf "${C_CYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    # ----- Status do sistema -----
    local inst_count=0
    for k in sshd brave btop base docker distrobox brew vscode obsidian opencode antigravity nerdfont flatpak tweaks; do
        if [ "${INSTALLED_CACHE[$k]:-0}" = "1" ]; then
            inst_count=$((inst_count + 1))
        fi
    done

    local status_text
    if [ "$inst_count" -gt 0 ]; then
        status_text=" [✓] Verde = Instalado ($inst_count detectado) | [ ] Branco = Pendente"
    else
        status_text=" [✓] Verde = Instalado | [ ] Branco = Pendente. Suporta execução em lote."
    fi

    printf "${C_DARKCYAN}╭─ STATUS DO SISTEMA ───────────────────────────────────────────────────── [ PRONTO ] ─╮${C_RESET}\n"
    printf_linha "$status_text"
    printf "${C_DARKCYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    printf "${C_CYAN}╭─ Selecione as opções separadas por vírgula (ex: D1,D4,C1,P1)${C_RESET}\n"
    printf "${C_CYAN}╰─❯ ${C_RESET}"
    read -r escolha

    [ -z "$escolha" ] && return
    local escolha_upper
    escolha_upper="$(echo "$escolha" | tr '[:lower:]' '[:upper:]' | xargs)"

    if [ "$escolha_upper" = "Q" ]; then
        MENU_ATUAL="EXIT"
        return
    fi

    dispatch_execution "$escolha_upper"
}

# ==============================================================================
# 9. LOOP PRINCIPAL (MÁQUINA DE ESTADOS)
# ==============================================================================
detectar_distro
require_root
detectar_usuario_real

while [ "$MENU_ATUAL" != "EXIT" ]; do
    case "$MENU_ATUAL" in
        "MAIN") menu_principal ;;
    esac
done

printf "\n${C_GREEN}[+] Encerrando linux-toolbox-tui. Até logo!${C_RESET}\n\n"