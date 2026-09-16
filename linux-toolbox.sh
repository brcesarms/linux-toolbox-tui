#!/bin/bash
#
# ==============================================================================
# LINUX-TOOLBOX-TUI V3.0 — Caixa de Ferramentas & Pós-Instalação para Linux
# ==============================================================================
# Interface de terminal estilo BIOS / Setup Utility — espelhando o
# win-toolbox-tui (win-toolbox.ps1 V2.0): bordas duplas ╔═╗, abas superiores,
# cursor de seleção em bloco verde, painel lateral "Item Help" dinâmico,
# navegação por setas ↑↓, Espaço marca [✓], Enter executa e Q sai.
#
# DIFERENCIAL LINUX (mais bonito que o original):
#   • Tela alternativa (tput smcup) — o TUI "sobe" como um app fullscreen e
#     restaura o terminal ao sair, sem sujar o histórico.
#   • Cursor de seleção em bloco verde 256 cores (estilo firmware real).
#   • Aba ativa em bloco amarelo, item instalado [INSTALADO] verde.
#   • Paginação automática (21 linhas por página, como o Setup Utility).
#   • Modo headless: ./linux-toolbox.sh D1,D4,P1 executa o lote sem abrir menu.
#   • --preview renderiza a tela sem exigir root (para desenvolvimento).
#
# Distribuições suportadas:
#   - Debian / Ubuntu (apt)      → serviço: ssh
#   - Fedora (dnf)               → serviço: sshd
#   - Arch / Omarchy (pacman)    → serviço: sshd
#
# Ferramentas (migradas do ubuntu-autoinstall — workstation dev):
#   Atualização Geral, Servidor SSH, Brave, btop, Base Dev, Docker+Compose,
#   Distrobox, Homebrew, VS Code, Obsidian, OpenCode CLI, Antigravity CLI,
#   Nerd Font, Flatpak/Flathub, GNOME Tweaks + Restricted Extras, Perfil Dev.
#
# AUTOR: Bruno César Medeiros Siqueira <bruno.cesar@outlook.it>
# VERSÃO: 3.0.0 — Setup Utility estilo BIOS (setas ↑↓ + Espaço + Enter)
#
# NOTA: propositalmente SEM `set -e`: o motor TUI lê teclas continuamente e as
# falhas são tratadas com `||` e verificações explícitas (idempotência).
# ==============================================================================

set -uo pipefail

# ==============================================================================
# 1. CORES ANSI, DIMENSÕES & VARIÁVEIS GLOBAIS
# ==============================================================================
# Cores fiéis ao PowerShell (win-toolbox.ps1): Cyan brilhante p/ bordas,
# DarkCyan p/ divisores do painel, bloco verde p/ cursor e bloco amarelo p/ aba.
if [ ! -t 1 ]; then
    C_RESET='' C_CYAN='' C_DARKCYAN='' C_GREEN='' C_YELLOW='' C_RED=''
    C_GRAY='' C_WHITE='' C_DARKGRAY='' C_BOLD='' C_BLOCK='' C_TAB=''
else
    C_RESET='\033[0m'
    C_CYAN='\033[96m'          # Cyan (equivalente ao Cyan do PowerShell)
    C_DARKCYAN='\033[36m'      # DarkCyan (divisores do Item Help)
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
    C_GRAY='\033[37m'
    C_WHITE='\033[1;37m'
    C_DARKGRAY='\033[90m'
    C_BOLD='\033[1m'
    C_BLOCK='\033[30;42m'      # texto preto sobre bloco verde (cursor BIOS)
    C_TAB='\033[30;43m'        # texto preto sobre bloco amarelo (aba ativa)
fi
export C_RESET C_CYAN C_DARKCYAN C_GREEN C_YELLOW C_RED C_GRAY C_WHITE C_DARKGRAY C_BOLD C_BLOCK C_TAB

# Dimensões da "tela" estilo Setup Utility (100 x 30 — bordas incluídas)
LARGURA=100
ALTURA=30
W_LISTA=55                    # colunas da lista de itens (esquerda)
W_HELP=38                     # colunas do painel Item Help (direita)
PAGE_SIZE=21                  # itens visíveis por página (21 linhas de conteúdo)

declare -g -A INSTALLED_CACHE=()
declare -g -A MARKS=()        # códigos marcados com Espaço (array associativo)
declare -g DISTRO_ID=""
declare -g PKG_MGR=""
declare -g SSH_SERVICE="ssh"
declare -g REAL_USER=""
declare -g MENU_ATUAL="SISTEMA"
declare -g SEL=0              # item selecionado (índice global)
declare -g PAGE=0             # página atual
declare -g PAGINAS=1
declare -g TELA_SUJA=1        # 1 = precisa limpar a tela antes de renderizar
declare -g TECLA=0            # última tecla lida pelo motor

# Arrays paralelos dos itens do menu atual (populados por preparar_menu_*)
declare -g -a IT_CODES=() IT_TEXTS=() IT_DESCS=() IT_PKGS=() IT_CATS=() IT_KEYS=() IT_SPECIAL=()
# Painel Item Help (21 linhas por frame)
declare -g -a HELP_TEXTS=() HELP_COLORS=()

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
# 3. HELPERS DE RENDERIZAÇÃO (bordas, padding, quebra de linha)
# ==============================================================================
# Remove códigos ANSI de uma string (para calcular largura real na tela)
clean_str() {
    printf '%s' "$1" | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g'
}

# Repete um caractere N vezes
rep_char() {
    local ch="$1" n="$2" i s=""
    for ((i = 0; i < n; i++)); do s+="$ch"; done
    printf '%s' "$s"
}

# Trunca uma string para no máximo $max caracteres, adicionando "…" se cortar
truncar() {
    local s="$1" max="$2"
    if (( ${#s} > max )); then
        printf '%s' "${s:0:$((max - 1))}…"
    else
        printf '%s' "$s"
    fi
}

# Quebra texto em linhas de no máximo $max caracteres (por espaços)
word_wrap() {
    local text="$1" max="$2"
    local -a words
    # shellcheck disable=SC2206 # intencional: split por espaços
    read -r -a words <<< "$text"
    local line="" w
    for w in "${words[@]}"; do
        if [[ -z "$line" ]]; then
            line="$w"
        elif (( ${#line} + 1 + ${#w} <= max )); then
            line="$line $w"
        else
            printf '%s\n' "$line"
            line="$w"
        fi
    done
    [[ -n "$line" ]] && printf '%s\n' "$line"
}

# Linha com conteúdo entre bordas: "║ <texto> ║" (com padding automático)
# $1 = texto (pode conter cores ANSI) | $2 = cor base (vazia = não colorir)
linha_conteudo() {
    local text="$1" color="${2:-}"
    local inner=$((LARGURA - 4))
    local clean len pad
    clean="$(clean_str "$text")"
    len="${#clean}"
    pad="$(rep_char ' ' $((inner > len ? inner - len : 0)))"
    printf '%s%s%s%s%s%s%s\n' \
        "$C_CYAN" "║ " "$C_RESET" "$color" "$text" "$pad" "$C_RESET${C_CYAN} ║${C_RESET}"
}

# Borda superior (1) ou inferior (0) da tela: ╔═╗ / ╚═╝
linha_borda() {
    local top="$1"
    if [ "$top" = "1" ]; then
        printf '%s\n' "${C_CYAN}╔$(rep_char '═' $((LARGURA - 2)))╗${C_RESET}"
    else
        printf '%s\n' "${C_CYAN}╚$(rep_char '═' $((LARGURA - 2)))╝${C_RESET}"
    fi
}

# Divisor horizontal que separa lista (esquerda) do painel Item Help (direita)
linha_split() {
    printf '%s\n' "${C_CYAN}╠$(rep_char '═' $((W_LISTA + 2)))╦$(rep_char '═' $((W_HELP + 2)))╣${C_RESET}"
}

# Divisor horizontal inferior (╠═╩═╣) antes do rodapé de dicas
linha_split_footer() {
    printf '%s\n' "${C_CYAN}╠$(rep_char '═' $((W_LISTA + 2)))╩$(rep_char '═' $((W_HELP + 2)))╣${C_RESET}"
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
# 7. MOTOR DE INTERFACE ESTILO BIOS (SETUP UTILITY)
# ==============================================================================
# Fiel ao win-toolbox.ps1: bordas duplas, abas superiores, cursor em bloco verde,
# painel lateral "Item Help" dinâmico, Espaço marca [✓], Enter executa, Q sai.
# 100% nativo bash (read -s) — sem dependências externas.

# Registra um item nos arrays globais do menu atual
adicionar_item() {
    IT_CODES+=("$1"); IT_TEXTS+=("$2"); IT_DESCS+=("$3")
    IT_PKGS+=("$4");  IT_CATS+=("$5");  IT_KEYS+=("$6")
    IT_SPECIAL+=("${7:-0}")
}

# Retorna 0 (instalado) se o item do índice $1 já estiver presente/ativo
item_instalado() {
    local idx="$1"
    [[ "${IT_SPECIAL[$idx]}" == "1" ]] && return 1
    local key="${IT_KEYS[$idx]}"
    [[ -z "$key" ]] && return 1
    testa_status "$key"
}

# Helper global do painel Item Help (evita função aninhada sombreada por `local`)
help_add() {
    HELP_TEXTS+=("$1")
    HELP_COLORS+=("$2")
}

# Monta as 21 linhas do painel lateral "Item Help" do item selecionado
# (idx < 0 = nenhum item → painel vazio)
montar_help_lines() {
    local idx="$1"
    HELP_TEXTS=(); HELP_COLORS=()

    help_add " Informações do Item" "$C_YELLOW"
    help_add "$(rep_char '─' 38)" "$C_DARKCYAN"

    if (( idx < 0 )); then
        while (( ${#HELP_TEXTS[@]} < 21 )); do help_add "" "$C_DARKGRAY"; done
        return
    fi

    local nome cat desc pkg special
    nome=$(truncar "${IT_TEXTS[$idx]}" 36)
    help_add " $nome" "$C_WHITE"

    cat=$(truncar " Categoria: ${IT_CATS[$idx]}" 37)
    help_add "$cat" "$C_DARKGRAY"

    desc="${IT_DESCS[$idx]:-Sem descrição adicional para este item.}"
    help_add "" "$C_DARKGRAY"
    help_add " Descrição:" "$C_CYAN"

    # Word-wrap da descrição em até 3 linhas de 35 colunas
    local -a wrapped=()
    mapfile -t wrapped < <(word_wrap "$desc" 35)
    local k
    for ((k = 0; k < 3; k++)); do
        if (( k < ${#wrapped[@]} )); then
            help_add " ${wrapped[$k]}" "$C_GRAY"
        else
            help_add "" "$C_GRAY"
        fi
    done

    help_add "" "$C_DARKGRAY"
    help_add " Método / Pacote:" "$C_CYAN"
    pkg=$(truncar "   ${IT_PKGS[$idx]:-N/A}" 37)
    help_add "$pkg" "$C_WHITE"

    help_add "" "$C_DARKGRAY"
    help_add " Status no Linux:" "$C_CYAN"

    special=0
    [[ "${IT_SPECIAL[$idx]}" == "1" ]] && special=1
    if (( special )); then
        help_add "   [*] Rotina em Lote / Especial" "$C_YELLOW"
    elif item_instalado "$idx"; then
        help_add "   [✓] Já instalado no sistema" "$C_GREEN"
    else
        help_add "   [ ] Não instalado / Pendente" "$C_DARKGRAY"
    fi

    help_add "" "$C_DARKGRAY"
    help_add "$(rep_char '─' 38)" "$C_DARKCYAN"
    help_add " Atalhos do Setup:" "$C_DARKGRAY"
    help_add "   [Espaço]  Marca p/ fila" "$C_GRAY"
    help_add "   [Enter]   Executa seleção" "$C_GRAY"
    help_add "   [Q]       Fecha o terminal" "$C_GRAY"

    while (( ${#HELP_TEXTS[@]} < 21 )); do help_add "" "$C_DARKGRAY"; done
}

# Barra de menus estilo BIOS (abas sempre visíveis no topo)
mostrar_barra_abas() {
    local aba="$1"
    local -a abas=(SISTEMA REDE APPS DEV CONFIG PERFIS)
    local s="" a
    for a in "${abas[@]}"; do
        if [[ "$a" == "$aba" ]]; then
            s+="${C_TAB}[ $a ]${C_RESET}  "
        else
            s+="${C_DARKGRAY}[ $a ]${C_RESET}  "
        fi
    done
    linha_conteudo "$s" ""
}

# Cabeçalho da tela: título + badge + linha de informações do sistema
mostrar_cabecalho() {
    local aba="$1"
    local titulo=" LINUX-TOOLBOX TUI · Setup Utility"
    local badge="[ LINUX ] "
    local inner=$((LARGURA - 4))
    local esp=$((inner - ${#titulo} - ${#badge}))
    (( esp < 0 )) && esp=0
    linha_conteudo "${C_BOLD}${C_CYAN}${titulo}${C_RESET}$(rep_char ' ' "$esp")${C_CYAN}${badge}${C_RESET}" ""

    local data host user ip info
    data="$(date +%d/%m/%Y)"
    host="$(hostname)"
    user="${REAL_USER:-$(id -un)}"
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="N/A"
    info=" TELA: $aba | Data: $data | Computador: $host | Usuário: $user | IP: $ip"
    linha_conteudo "$info" "$C_DARKGRAY"
}

# Renderiza a tela inteira (30 linhas estilo Setup Utility)
show_bios_screen() {
    local aba="$1"
    if (( TELA_SUJA )); then
        printf '\e[2J'
        TELA_SUJA=0
    fi
    printf '\e[H'

    linha_borda 1
    mostrar_cabecalho "$aba"
    printf '%s\n' "${C_CYAN}╠$(rep_char '═' $((LARGURA - 2)))╣${C_RESET}"
    mostrar_barra_abas "$aba"
    linha_split

    local start=$((PAGE * PAGE_SIZE))
    local total=${#IT_CODES[@]}
    local j i

    for ((j = 0; j < PAGE_SIZE; j++)); do
        i=$((start + j))

        # O painel Item Help (direita) é renderizado em TODAS as 21 linhas,
        # mesmo quando a lista (esquerda) está vazia — fiel ao Setup Utility.
        local rtext="${HELP_TEXTS[$j]}"
        rtext="$(truncar "$rtext" "$W_HELP")"
        rtext="$(printf '%-*s' "$W_HELP" "$rtext")"
        local right="$C_RESET${HELP_COLORS[$j]}$rtext$C_RESET"

        if (( i < total )); then
            local code="${IT_CODES[$i]}"
            local inst=0 special=0 mark=" " cursor="  "

            item_instalado "$i" && inst=1
            [[ "${IT_SPECIAL[$i]}" == "1" ]] && special=1

            if (( inst )) || [[ -n "${MARKS[$code]+x}" ]]; then mark="✓"; fi
            (( i == SEL )) && cursor="► "

            local prefix="[$mark] $(printf '%-4s' "$code") "
            local sufixo=""
            (( inst && ! special )) && sufixo="[INSTALADO]"

            local suf_len=0
            [[ -n "$sufixo" ]] && suf_len=$(( ${#sufixo} + 1 ))

            local nome
            nome="$(truncar "${IT_TEXTS[$i]}" $(( W_LISTA - ${#cursor} - ${#prefix} - suf_len )))"

            local texto="${cursor}${prefix}${nome}"
            [[ -n "$sufixo" ]] && texto="${texto} $sufixo"
            texto="$(printf '%-*s' "$W_LISTA" "$texto")"

            local cor="$C_WHITE"
            if (( i == SEL )); then
                cor="$C_BLOCK"
            elif (( special )); then
                cor="$C_YELLOW"
            elif (( inst )); then
                cor="$C_GREEN"
            elif [[ -n "${MARKS[$code]+x}" ]]; then
                cor="$C_CYAN"
            fi

            printf '%s\n' "$C_CYAN║ $C_RESET${cor}${texto}${C_RESET}$C_CYAN ║ $C_RESET${right}$C_CYAN ║$C_RESET"
        else
            printf '%s\n' "$C_CYAN║ $C_RESET$(rep_char ' ' "$W_LISTA")$C_CYAN ║ $C_RESET${right}$C_CYAN ║$C_RESET"
        fi
    done

    linha_split_footer
    montar_dicas_footer
    linha_borda 0
}

# Rodapé com dicas de navegação distribuídas proporcionalmente (igual win)
montar_dicas_footer() {
    local -a nav=("←→ Aba" "↑↓ Mover" "Espaço Marcar" "Enter Executa")
    if (( ${#MARKS[@]} > 0 )); then nav+=("Marcados: ${#MARKS[@]}"); fi
    if (( PAGINAS > 1 )); then nav+=("Pg $((PAGE + 1))/$PAGINAS"); fi
    nav+=("Q Sair")

    local total_len=0 t
    for t in "${nav[@]}"; do total_len=$((total_len + ${#t})); done

    local total_spaces=$(( (LARGURA - 4) - total_len ))
    (( total_spaces < 0 )) && total_spaces=0

    local gaps=$(( ${#nav[@]} + 1 ))
    local base=$(( total_spaces / gaps )) extra=$(( total_spaces % gaps ))
    local linha="" g gap
    for ((g = 0; g < gaps; g++)); do
        gap=$base
        (( g < extra )) && gap=$((gap + 1))
        linha+="$(rep_char ' ' "$gap")"
        (( g < ${#nav[@]} )) && linha+="${nav[$g]}"
    done

    linha_conteudo "$linha" "$C_CYAN"
}

# -----------------------------------------------------------------------------
# LEITURA DE TECLAS (100% nativa — sem gum, sem instalação)
# Códigos: 1↑ 2↓ 3→ 4← 5Espaço 6Enter 7PgUp 8PgDn 9Esc 10Q 11A 12R 13D 14C
#          15S 16P | 21..26 = teclas 1..6 (atalhos diretos para cada aba)
# -----------------------------------------------------------------------------
ler_tecla() {
    local key ch1 ch2
    TECLA=0

    if ! IFS= read -rsn1 key; then
        TECLA=10   # EOF (stdin fechado) → encerra o TUI com segurança
        return
    fi

    if [[ "$key" == $'\e' ]]; then
        if IFS= read -rsn1 ch1 -t 0.05; then
            if [[ "$ch1" == '[' ]]; then
                if IFS= read -rsn1 ch2 -t 0.05; then
                    case "$ch2" in
                        A) TECLA=1 ;; B) TECLA=2 ;;
                        C) TECLA=3 ;; D) TECLA=4 ;;
                        5) TECLA=7 ;; 6) TECLA=8 ;;
                        *) TECLA=9 ;;
                    esac
                else TECLA=9; fi
            else TECLA=9; fi
        else TECLA=9; fi
        return
    fi

    case "$key" in
        ' ')                 TECLA=5 ;;
        $'\n'|$'\r')         TECLA=6 ;;
        $'\t')               TECLA=3 ;;
        [qQ])                TECLA=10 ;;
        [sS])                TECLA=15 ;;
        [aA])                TECLA=11 ;;
        [rR])                TECLA=12 ;;
        [dD])                TECLA=13 ;;
        [cC])                TECLA=14 ;;
        [pP])                TECLA=16 ;;
        1) TECLA=21 ;; 2) TECLA=22 ;; 3) TECLA=23 ;;
        4) TECLA=24 ;; 5) TECLA=25 ;; 6) TECLA=26 ;;
        *)                   TECLA=0 ;;
    esac
}

# -----------------------------------------------------------------------------
# Motor principal: renderiza a tela, lê teclas, gerencia seleção/marcação/página
# Retorna: "TAB_<ABA>", "Q" ou um lote separado por vírgula (ex: "D1,D4,P1")
# -----------------------------------------------------------------------------
read_bios_menu() {
    local aba="$1"
    SEL=0; PAGE=0; MARKS=()
    local total=${#IT_CODES[@]}
    PAGINAS=$(( (total + PAGE_SIZE - 1) / PAGE_SIZE ))
    (( PAGINAS < 1 )) && PAGINAS=1

    while true; do
        montar_help_lines "$SEL"
        show_bios_screen "$aba"
        ler_tecla

        local fim_pagina code special lote c

        case "$TECLA" in
            1)  # ↑
                if (( SEL > PAGE * PAGE_SIZE )); then
                    SEL=$((SEL - 1))
                elif (( PAGE > 0 )); then
                    PAGE=$((PAGE - 1))
                    SEL=$(( PAGE * PAGE_SIZE + PAGE_SIZE - 1 ))
                    (( SEL >= total )) && SEL=$((total - 1))
                else
                    SEL=0
                fi
                ;;
            2)  # ↓
                fim_pagina=$(( (PAGE + 1) * PAGE_SIZE - 1 ))
                (( fim_pagina > total - 1 )) && fim_pagina=$((total - 1))
                if (( SEL < fim_pagina )); then
                    SEL=$((SEL + 1))
                elif (( PAGE < PAGINAS - 1 )); then
                    PAGE=$((PAGE + 1)); SEL=$(( PAGE * PAGE_SIZE ))
                else
                    SEL=$fim_pagina
                fi
                ;;
            3)  # → / Tab
                case "$aba" in
                    SISTEMA) printf '%s' "TAB_REDE";  return ;;
                    REDE)    printf '%s' "TAB_APPS";  return ;;
                    APPS)    printf '%s' "TAB_DEV";   return ;;
                    DEV)     printf '%s' "TAB_CONFIG"; return ;;
                    CONFIG)  printf '%s' "TAB_PERFIS"; return ;;
                    PERFIS)  printf '%s' "TAB_SISTEMA"; return ;;
                esac
                ;;
            4)  # ←
                case "$aba" in
                    SISTEMA) printf '%s' "TAB_PERFIS"; return ;;
                    REDE)    printf '%s' "TAB_SISTEMA"; return ;;
                    APPS)    printf '%s' "TAB_REDE";  return ;;
                    DEV)     printf '%s' "TAB_APPS";  return ;;
                    CONFIG)  printf '%s' "TAB_DEV";   return ;;
                    PERFIS)  printf '%s' "TAB_CONFIG"; return ;;
                esac
                ;;
            7)  # PageUp
                if (( PAGE > 0 )); then PAGE=$((PAGE - 1)); SEL=$(( PAGE * PAGE_SIZE )); fi
                ;;
            8)  # PageDown
                if (( PAGE < PAGINAS - 1 )); then PAGE=$((PAGE + 1)); SEL=$(( PAGE * PAGE_SIZE )); fi
                ;;
            11) printf '%s' "TAB_APPS"; return ;;   # A
            12) printf '%s' "TAB_REDE"; return ;;   # R
            13) printf '%s' "TAB_DEV"; return ;;    # D
            14) printf '%s' "TAB_CONFIG"; return ;; # C
            15) printf '%s' "TAB_SISTEMA"; return ;; # S
            16) printf '%s' "TAB_PERFIS"; return ;; # P
            21) printf '%s' "TAB_SISTEMA"; return ;; # 1
            22) printf '%s' "TAB_REDE"; return ;;    # 2
            23) printf '%s' "TAB_APPS"; return ;;    # 3
            24) printf '%s' "TAB_DEV"; return ;;     # 4
            25) printf '%s' "TAB_CONFIG"; return ;;  # 5
            26) printf '%s' "TAB_PERFIS"; return ;;  # 6
            5)  # Espaço → marca/desmarca
                code="${IT_CODES[$SEL]}"
                special=0
                [[ "${IT_SPECIAL[$SEL]}" == "1" ]] && special=1
                if (( ! special )) && ! item_instalado "$SEL"; then
                    if [[ -n "${MARKS[$code]+x}" ]]; then
                        unset 'MARKS["$code"]'
                    else
                        MARKS["$code"]=1
                    fi
                fi
                ;;
            6)  # Enter → executa marcados (ou o selecionado)
                lote=""
                for ((c = 0; c < total; c++)); do
                    code="${IT_CODES[$c]}"
                    if [[ -n "${MARKS[$code]+x}" ]]; then
                        [[ -n "$lote" ]] && lote+=","
                        lote+="$code"
                    fi
                done
                [[ -z "$lote" ]] && lote="${IT_CODES[$SEL]}"
                printf '%s' "$lote"
                return
                ;;
            9|10)  # Esc / Q → sai
                printf '%s' "Q"
                return
                ;;
            0) : ;;  # tecla desconhecida — ignora
        esac
    done
}

# ==============================================================================
# 8. TELAS DE MENU (populam os itens de cada aba estilo BIOS)
# ==============================================================================
preparar_menu_sistema() {
    IT_CODES=(); IT_TEXTS=(); IT_DESCS=(); IT_PKGS=(); IT_CATS=(); IT_KEYS=(); IT_SPECIAL=()
    adicionar_item "0" "ATUALIZAÇÃO GERAL (apt/dnf/pacman)" \
        "Atualiza todos os pacotes do sistema pelo gerenciador nativo, trazendo a versão mais recente dos repositórios." \
        "upgrade geral (${PKG_MGR})" "Manutenção Geral" "" 1
}

preparar_menu_rede() {
    IT_CODES=(); IT_TEXTS=(); IT_DESCS=(); IT_PKGS=(); IT_CATS=(); IT_KEYS=(); IT_SPECIAL=()
    adicionar_item "R1" "Habilitar Servidor SSH (Porta 22)" \
        "Instala openssh-server, habilita o serviço no boot, libera a porta 22 no firewall (UFW/firewalld) e exibe o comando de conexão." \
        "apt/dnf/pacman: openssh-server" "Acesso Remoto / SSH" "sshd"
}

preparar_menu_apps() {
    IT_CODES=(); IT_TEXTS=(); IT_DESCS=(); IT_PKGS=(); IT_CATS=(); IT_KEYS=(); IT_SPECIAL=()
    adicionar_item "A1" "Brave Browser" \
        "Navegador web veloz focado em privacidade, com bloqueador nativo de anúncios e rastreadores." \
        "script oficial: dl.brave.com" "Internet / Navegador" "brave"
    adicionar_item "A2" "btop (Monitor do Sistema)" \
        "Monitor avançado em tempo real com uso de CPU, memória, discos e rede diretamente no terminal." \
        "apt/dnf/pacman: btop" "Monitor / Sistema" "btop"
}

preparar_menu_dev() {
    IT_CODES=(); IT_TEXTS=(); IT_DESCS=(); IT_PKGS=(); IT_CATS=(); IT_KEYS=(); IT_SPECIAL=()
    adicionar_item "D1" "Pacote Base Dev (git, curl, build...)" \
        "Conjunto essencial: git, curl, wget, unzip, build-essential/@development-tools/base-devel, procps e file." \
        "apt: build-essential | dnf: @development-tools | pacman: base-devel" \
        "Ferramentas / Dev Base" "base"
    adicionar_item "D2" "Docker + Docker Compose v2" \
        "Contêineres Docker com Compose v2, serviço habilitado no boot e usuário real adicionado ao grupo docker." \
        "apt: docker.io | dnf: moby-engine | pacman: docker" \
        "Contêineres / Dev" "docker"
    adicionar_item "D3" "Distrobox" \
        "Contêineres estilo toolbox para criar ambientes Linux isolados e integrá-los ao sistema host." \
        "apt/dnf/pacman: distrobox" "Contêineres / Dev" "distrobox"
    adicionar_item "D4" "Homebrew (Linuxbrew)" \
        "Gestor de pacotes secundário instalado de forma não-interativa em /home/linuxbrew e configurado no .bashrc do usuário." \
        "script oficial: Homebrew/install" "Gestor de Pacotes" "brew"
    adicionar_item "D5" "Visual Studio Code" \
        "Editor de código moderno e modular com depuração, Git e ecossistema de extensões. Instalado via Flatpak universal." \
        "flatpak: com.visualstudio.code" "Editor de Código" "vscode"
    adicionar_item "D6" "Obsidian" \
        "Base de conhecimento em Markdown com gráfico de conexões, plugins e backup em arquivos locais. Instalado via Flatpak." \
        "flatpak: md.obsidian.Obsidian" "Produtividade / Notas" "obsidian"
    adicionar_item "D7" "OpenCode CLI" \
        "Cliente de terminal com Inteligência Artificial para automação e assistência de código, via instalador oficial." \
        "script oficial: opencode.ai/install" "IA / CLI" "opencode"
    adicionar_item "D8" "Antigravity CLI" \
        "Ferramenta de Inteligência Artificial do Google para tarefas de código no terminal, via instalador oficial." \
        "script oficial: antigravity.google" "IA / CLI" "antigravity"
}

preparar_menu_config() {
    IT_CODES=(); IT_TEXTS=(); IT_DESCS=(); IT_PKGS=(); IT_CATS=(); IT_KEYS=(); IT_SPECIAL=()
    adicionar_item "C1" "JetBrainsMono Nerd Font" \
        "Fonte com todos os glifos (estilo Omarchy/Bluefin) para um terminal bonito, instalada em /usr/local/share/fonts/NerdFonts." \
        "release oficial: nerd-fonts (Zip)" "Interface / Fonte" "nerdfont"
    adicionar_item "C2" "Flatpak + Repositório Flathub" \
        "Base para aplicações Flatpak com o repositório Flathub ativado — necessário para VS Code e Obsidian." \
        "apt/dnf/pacman: flatpak + flathub" "Sistema / Apps" "flatpak"
    adicionar_item "C3" "GNOME Tweaks + Restricted Extras" \
        "Ajustes do GNOME e codecs multimídia restritos (Ubuntu Restricted Extras; Fedora/Arch: instruções manuais)." \
        "apt/dnf/pacman: gnome-tweaks" "Interface / Codecs" "tweaks"
}

preparar_menu_perfis() {
    IT_CODES=(); IT_TEXTS=(); IT_DESCS=(); IT_PKGS=(); IT_CATS=(); IT_KEYS=(); IT_SPECIAL=()
    adicionar_item "P1" "MODO BRNCZZR — Workstation Dev Completa" \
        "Perfil automatizado: base + apps + dev + config + atualização geral, executado em sequência sem intervenção." \
        "Perfil Automatizado Dev" "Perfil de Estação" "" 1
}

invocar_menu_sistema() {
    preparar_menu_sistema
    local res
    res="$(read_bios_menu SISTEMA)"
    case "$res" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$res" ]] && dispatch_execution "$res" ;;
    esac
}

invocar_menu_rede() {
    preparar_menu_rede
    local res
    res="$(read_bios_menu REDE)"
    case "$res" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE) ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$res" ]] && dispatch_execution "$res" ;;
    esac
}

invocar_menu_apps() {
    preparar_menu_apps
    local res
    res="$(read_bios_menu APPS)"
    case "$res" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS) ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$res" ]] && dispatch_execution "$res" ;;
    esac
}

invocar_menu_dev() {
    preparar_menu_dev
    local res
    res="$(read_bios_menu DEV)"
    case "$res" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV) ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$res" ]] && dispatch_execution "$res" ;;
    esac
}

invocar_menu_config() {
    preparar_menu_config
    local res
    res="$(read_bios_menu CONFIG)"
    case "$res" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG) ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$res" ]] && dispatch_execution "$res" ;;
    esac
}

invocar_menu_perfis() {
    preparar_menu_perfis
    local res
    res="$(read_bios_menu PERFIS)"
    case "$res" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS) ;;
        *) [[ -n "$res" ]] && dispatch_execution "$res" ;;
    esac
}

# ==============================================================================
# 9. DISPATCHER DE TAREFAS (execução em lote, headless e modo TUI)
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
        *)
            printf "${C_RED}[!] Opção '%s' não reconhecida.${C_RESET}\n" "$opcao"
            ;;
    esac
}

execute_batch_options() {
    local lote="$1"
    local IFS=',' item op

    # shellcheck disable=SC2034 # item é usado na expansão do loop
    for item in $lote; do
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

    TELA_SUJA=1
    printf "\n${C_CYAN}╭─ EXECUTANDO TAREFAS SELECIONADAS ${C_RESET}"
    printf '%*s' $((50 - ${#escolha})) ''
    printf "${C_CYAN}[ PROCESSO ATIVO ] ─╮${C_RESET}\n"
    linha_conteudo " Lote em andamento: $escolha" "$C_YELLOW"
    printf "${C_CYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    execute_batch_options "$escolha"
    INSTALLED_CACHE=()
    MARKS=()
    TELA_SUJA=1
    wait_user
}

wait_user() {
    printf "\n${C_GRAY}[Pressione ENTER para continuar...]${C_RESET}\n"
    read -r _
}

# ==============================================================================
# 10. VALIDAÇÃO DE TERMINAL, LIMPEZA E LOOP PRINCIPAL
# ==============================================================================
verificar_terminal() {
    local cols lines
    cols="$(tput cols 2>/dev/null || echo 0)"
    lines="$(tput lines 2>/dev/null || echo 0)"
    if (( cols < LARGURA || lines < ALTURA )); then
        printf "\n${C_YELLOW}[!] O terminal precisa ter pelo menos %sx%s (atual: %sx%s).${C_RESET}\n" \
            "$LARGURA" "$ALTURA" "$cols" "$lines"
        printf "${C_CYAN}[*] Maximize ou aumente a janela do terminal e tente novamente.${C_RESET}\n\n"
        exit 1
    fi
}

restaurar_terminal() {
    tput rmcup 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

preview_tela() {
    # --preview: renderiza a aba SISTEMA sem exigir root (para desenvolvimento)
    detectar_distro
    detectar_usuario_real
    preparar_menu_sistema
    montar_help_lines 0
    TELA_SUJA=1
    show_bios_screen SISTEMA
    printf '%s\n' "$C_RESET"
    exit 0
}

main() {
    case "${1:-}" in
        --preview)
            preview_tela
            ;;
        "")
            ;;
        *)
            # Modo headless (lote por argumento, ex: ./linux-toolbox.sh D1,D4,P1)
            detectar_distro
            require_root
            detectar_usuario_real
            dispatch_execution "$1"
            exit 0
            ;;
    esac

    # Modo TUI interativo (estilo BIOS / Setup Utility)
    detectar_distro
    require_root
    detectar_usuario_real
    verificar_terminal

    tput smcup 2>/dev/null || true   # tela alternativa fullscreen
    tput civis 2>/dev/null || true   # esconde o cursor
    trap 'restaurar_terminal' EXIT

    MENU_ATUAL="SISTEMA"
    TELA_SUJA=1

    while [ "$MENU_ATUAL" != "EXIT" ]; do
        case "$MENU_ATUAL" in
            "SISTEMA") invocar_menu_sistema ;;
            "REDE")    invocar_menu_rede ;;
            "APPS")    invocar_menu_apps ;;
            "DEV")     invocar_menu_dev ;;
            "CONFIG")  invocar_menu_config ;;
            "PERFIS")  invocar_menu_perfis ;;
        esac
    done

    restaurar_terminal
    printf "\n${C_GREEN}[+] Encerrando linux-toolbox-tui. Até logo!${C_RESET}\n\n"
}

main "$@"