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
    C_RESET=$'\e[0m'
    C_CYAN=$'\e[96m'          # Cyan brilhante (bordas BIOS)
    C_DARKCYAN=$'\e[36m'      # DarkCyan (divisores do Item Help)
    C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'
    C_RED=$'\e[31m'
    C_GRAY=$'\e[37m'
    C_WHITE=$'\e[1;37m'
    C_DARKGRAY=$'\e[90m'
    C_BOLD=$'\e[1m'
    C_BLOCK=$'\e[30;42m'      # texto preto sobre bloco verde (cursor BIOS)
    C_TAB=$'\e[30;43m'        # texto preto sobre bloco amarelo (aba ativa)
fi
export C_RESET C_CYAN C_DARKCYAN C_GREEN C_YELLOW C_RED C_GRAY C_WHITE C_DARKGRAY C_BOLD C_BLOCK C_TAB

# Dimensões da tela estilo Setup Utility (120 x 30 — padronizada igual win-toolbox.ps1)
LARGURA=120
ALTURA=30
W_LISTA=68                    # colunas da lista de itens (esquerda)
W_HELP=45                     # colunas do painel Item Help (direita)
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
declare -g MENU_RES=""         # resultado da seleção do menu (sem subshell)
declare -g IS_HEADLESS=0       # 1 = modo headless direto (sem prompts interativos)

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
        printf '\n%s[!] Privilégios de root são necessários.%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s[*] Use: sudo %s%s\n\n' "$C_CYAN" "$0" "$C_RESET"
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
        printf '%s' "${C_CYAN}╚$(rep_char '═' $((LARGURA - 2)))╝${C_RESET}"
    fi
}

# Divisor horizontal que separa lista (esquerda) do painel Item Help (direita)
# Split: 70 chars esquerda + 47 chars direita (1 + 70 + 1 + 47 + 1 = 120 colunas)
linha_split() {
    printf '%s\n' "${C_CYAN}╠$(rep_char '═' 70)╦$(rep_char '═' 47)╣${C_RESET}"
}

# Divisor horizontal inferior (╠═╩═╣) antes do rodapé de dicas
linha_split_footer() {
    printf '%s\n' "${C_CYAN}╠$(rep_char '═' 70)╩$(rep_char '═' 47)╣${C_RESET}"
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

    local h
    h="$(home_usuario)"
    local result=1
    case "$key" in
        sshd)
            systemctl is-active "$SSH_SERVICE" >/dev/null 2>&1 && result=0
            ;;
        avahi)
            systemctl is-active avahi-daemon >/dev/null 2>&1 && result=0
            ;;
        brave)
            command -v brave-browser >/dev/null 2>&1 && result=0
            command -v flatpak >/dev/null 2>&1 && flatpak info com.brave.Browser >/dev/null 2>&1 && result=0
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
            { [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ] || [ -x "${h}/.linuxbrew/bin/brew" ] || command -v brew >/dev/null 2>&1; } && result=0
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
            { command -v opencode >/dev/null 2>&1 || [ -x "${h}/.local/bin/opencode" ] || [ -x "${h}/.opencode/bin/opencode" ] || [ -x "/usr/local/bin/opencode" ]; } && result=0
            ;;
        antigravity)
            { command -v agy >/dev/null 2>&1 || command -v antigravity >/dev/null 2>&1 || [ -x "${h}/.local/bin/agy" ] || [ -x "${h}/.local/bin/antigravity" ] || [ -x "/usr/local/bin/agy" ] || [ -x "/usr/local/bin/antigravity" ]; } && result=0
            ;;
        nerdfont)
            { fc-list 2>/dev/null | grep -qi "JetBrainsMono" || [ -d "/usr/local/share/fonts/NerdFonts" ] || [ -d "${h}/.local/share/fonts/NerdFonts" ]; } && result=0
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
# 5. LOGGING AUXILIAR SEGURO (conformidade estrita com ShellCheck)
# ==============================================================================
log_header() {
    printf '\n%s========================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s[*] %s%s\n' "$C_CYAN" "$1" "$C_RESET"
    printf '%s========================================================%s\n' "$C_CYAN" "$C_RESET"
}

log_header_success() {
    printf '\n%s========================================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s[*] %s%s\n' "$C_GREEN" "$1" "$C_RESET"
    printf '%s========================================================%s\n' "$C_GREEN" "$C_RESET"
}

log_step() {
    printf '%s%s%s\n' "$C_GRAY" "$1" "$C_RESET"
}

log_ok() {
    printf '%s%s%s\n' "$C_GREEN" "$1" "$C_RESET"
}

log_warn() {
    printf '%s%s%s\n' "$C_YELLOW" "$1" "$C_RESET"
}

log_err() {
    printf '%s%s%s\n' "$C_RED" "$1" "$C_RESET"
}

log_info() {
    printf '%s%s%s\n' "$C_CYAN" "$1" "$C_RESET"
}

# ==============================================================================
# 6. HELPER MULTI-DISTRO DE INSTALAÇÃO DE PACOTES
# ==============================================================================
# Uso: instalar_pacotes "pacotes_apt" "pacotes_dnf" "pacotes_pacman"
instalar_pacotes() {
    local lista=""
    case "$PKG_MGR" in
        apt)    lista="$1" ;;
        dnf)    lista="$2" ;;
        pacman) lista="$3" ;;
        *)
            log_err "[!] Gerenciador de pacotes desconhecido (${PKG_MGR})."
            return 1
            ;;
    esac

    [ -z "$lista" ] && return 0

    log_warn "[+] Instalando via ${PKG_MGR}: ${lista}"
    # shellcheck disable=SC2086 # intencional: expansão de lista de pacotes em word splitting
    case "$PKG_MGR" in
        apt)
            apt-get update -y >/dev/null 2>&1 || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y $lista >/dev/null 2>&1 \
                || log_err "[!] Falha ao instalar pacotes (apt): ${lista}"
            ;;
        dnf)
            dnf install -y $lista >/dev/null 2>&1 \
                || log_err "[!] Falha ao instalar pacotes (dnf): ${lista}"
            ;;
        pacman)
            pacman -Sy --noconfirm $lista >/dev/null 2>&1 \
                || log_err "[!] Falha ao instalar pacotes (pacman): ${lista}"
            ;;
    esac
}

# ==============================================================================
# 7. FUNÇÕES DE FERRAMENTAS (migradas do ubuntu-autoinstall)
# ==============================================================================

# ---------- 0. ATUALIZAÇÃO GERAL ----------
atualizacao_geral() {
    log_header "ATUALIZANDO O SISTEMA (${PKG_MGR})"

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
            log_err "[!] Gerenciador de pacotes desconhecido."
            return 1
            ;;
    esac

    log_ok "[✓] Atualização geral concluída!"
}

# ---------- R1. SERVIDOR SSH ----------
habilitar_servidor_ssh() {
    log_header "HABILITANDO SERVIDOR SSH NO LINUX"

    # ---------- Passo 1/4: Instalar OpenSSH Server ----------
    log_step "[1/4] Verificando OpenSSH Server..."
    log_step "[+] Distribuição detectada: ${DISTRO_ID} (gerenciador: ${PKG_MGR})"

    if command -v sshd >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -qE "^(ssh|sshd)\.service"; then
        log_ok "[✓] OpenSSH Server já está instalado."
    else
        instalar_pacotes "openssh-server" "openssh-server" "openssh"
    fi

    # ---------- Passo 2/4: Habilitar e iniciar o serviço ----------
    log_step "[2/4] Habilitando e iniciando o serviço ${SSH_SERVICE}..."
    systemctl enable "$SSH_SERVICE" >/dev/null 2>&1 || true
    systemctl start "$SSH_SERVICE" >/dev/null 2>&1 || true

    # Healthcheck com timeout (máx. 10 tentativas)
    local j=0
    while ! systemctl is-active "$SSH_SERVICE" >/dev/null 2>&1 && [ $j -lt 10 ]; do
        sleep 1
        j=$((j + 1))
    done

    if systemctl is-active "$SSH_SERVICE" >/dev/null 2>&1; then
        log_ok "[✓] Serviço ${SSH_SERVICE} ativo e configurado para iniciar no boot!"
        INSTALLED_CACHE[sshd]=1
    else
        log_err "[!] Serviço ${SSH_SERVICE} não está ativo. Verifique: systemctl status ${SSH_SERVICE}"
    fi

    # ---------- Passo 3/4: Firewall ----------
    log_step "[3/4] Configurando firewall para permitir SSH (porta 22 TCP)..."
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "Status: active"; then
        ufw allow ssh >/dev/null 2>&1
        log_ok "[✓] UFW: regra para SSH adicionada."
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        log_ok "[✓] firewalld: regra para SSH adicionada."
    else
        log_step "[i] Nenhum firewall ativo detectado (UFW/firewalld) — nada a liberar."
    fi

    # ---------- Passo 4/4: Resumo e credenciais de conexão ----------
    log_step "[4/4] Coletando informações de conexão..."
    local ip
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="N/A"

    log_header_success "SERVIDOR SSH CONFIGURADO E PRONTO PARA CONEXÃO!"
    printf '     Comando para conectar de outro computador:\n'
    printf '%s     ssh %s@%s%s\n' "$C_YELLOW" "$REAL_USER" "$ip" "$C_RESET"
    printf '%s========================================================%s\n' "$C_GREEN" "$C_RESET"
}

# ---------- R2. mDNS / AVAHI — ACESSO POR NOME (.local) ----------
habilitar_mdns_avahi() {
    log_header "HABILITANDO mDNS/AVAHI (ACESSO POR NOME .local)"

    # ---------- Passo 1/3: Instalar Avahi ----------
    log_step "[1/3] Verificando Avahi (mDNS)..."
    log_step "[+] Distribuição detectada: ${DISTRO_ID} (gerenciador: ${PKG_MGR})"

    if command -v avahi-daemon >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -q "avahi-daemon.service"; then
        log_ok "[✓] Avahi já está instalado."
    else
        instalar_pacotes "avahi-daemon avahi-utils" "avahi-daemon avahi-tools" "avahi avahi-tools"
    fi

    # ---------- Passo 2/3: Habilitar e iniciar o serviço ----------
    log_step "[2/3] Habilitando e iniciando o serviço avahi-daemon..."
    systemctl enable avahi-daemon >/dev/null 2>&1 || true
    systemctl start avahi-daemon >/dev/null 2>&1 || true

    # Healthcheck com timeout (máx. 10 tentativas)
    local j=0
    while ! systemctl is-active avahi-daemon >/dev/null 2>&1 && [ $j -lt 10 ]; do
        sleep 1
        j=$((j + 1))
    done

    if systemctl is-active avahi-daemon >/dev/null 2>&1; then
        log_ok "[✓] Serviço avahi-daemon ativo e configurado para iniciar no boot!"
        INSTALLED_CACHE[avahi]=1
    else
        log_err "[!] Serviço avahi-daemon não está ativo. Verifique: systemctl status avahi-daemon"
    fi

    # ---------- Passo 3/3: Resumo e credenciais de conexão por nome ----------
    log_step "[3/3] Coletando hostname para acesso via .local..."
    local host ip
    host="$(hostname -s 2>/dev/null)"
    [ -z "$host" ] && host="$(hostname)"
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="N/A"

    log_header_success "mDNS/AVAHI CONFIGURADO — ACESSO POR NOME (NÃO DEPENDE DO IP)!"
    printf '     Nome desta máquina na rede: %s\n' "${host}.local"
    printf '     Teste de resolução (nesta máquina): %s\n' "avahi-resolve -n ${host}.local"
    printf '     Conectar de outro computador: %s\n' "ssh ${REAL_USER}@${host}.local"
    printf '     IP atual (fallback se mDNS indisponível): %s\n' "$ip"
    printf '%s========================================================%s\n' "$C_GREEN" "$C_RESET"
}

# ---------- A1. BRAVE BROWSER ----------
instalar_brave() {
    log_header "INSTALANDO BRAVE BROWSER (script oficial)"
    if testa_status brave; then
        log_ok "[✓] Brave Browser já está instalado."
        return
    fi

    log_step "[1/2] Baixando e executando instalador oficial..."
    if sh -c 'curl -fsS https://dl.brave.com/install.sh | sh' >/dev/null 2>&1; then
        INSTALLED_CACHE[brave]=1
        log_ok "[✓] Brave Browser instalado com sucesso!"
    else
        log_warn "[!] Falha na instalação automática. Instale manualmente: https://brave.com/linux/"
    fi
}

# ---------- A2. BTOP ----------
instalar_btop() {
    log_header "INSTALANDO BTOP (monitor do sistema)"
    if testa_status btop; then
        log_ok "[✓] btop já está instalado."
        return
    fi

    instalar_pacotes "btop" "btop" "btop"
    if command -v btop >/dev/null 2>&1; then
        INSTALLED_CACHE[btop]=1
        log_ok "[✓] btop instalado com sucesso!"
    else
        log_warn "[!] Não foi possível confirmar a instalação do btop."
    fi
}

# ---------- D1. PACOTE BASE DEV ----------
instalar_base_dev() {
    log_header "INSTALANDO PACOTE BASE DEV (git, curl, build...)"
    if testa_status base; then
        log_ok "[✓] Pacote base dev já está instalado."
        return
    fi

    instalar_pacotes \
        "git wget curl unzip build-essential procps file" \
        "git wget curl unzip @development-tools procps-ng file" \
        "git wget curl unzip base-devel procps-ng file"

    if command -v git >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
        INSTALLED_CACHE[base]=1
        log_ok "[✓] Pacote base dev instalado com sucesso!"
    else
        log_warn "[!] Não foi possível confirmar a instalação da base dev."
    fi
}

# ---------- D2. DOCKER + DOCKER COMPOSE V2 ----------
instalar_docker() {
    log_header "INSTALANDO DOCKER + DOCKER COMPOSE V2"
    if testa_status docker; then
        log_ok "[✓] Docker já está instalado."
    else
        instalar_pacotes \
            "docker.io docker-compose-v2" \
            "moby-engine docker-compose" \
            "docker docker-compose docker-buildx"

        if command -v docker >/dev/null 2>&1; then
            INSTALLED_CACHE[docker]=1
            log_ok "[✓] Docker instalado com sucesso!"
        else
            log_warn "[!] Não foi possível confirmar a instalação do Docker."
        fi
    fi

    # Habilitar e iniciar o serviço
    log_step "[+] Habilitando e iniciando o serviço docker..."
    systemctl enable docker >/dev/null 2>&1 || true
    systemctl start docker >/dev/null 2>&1 || true

    # Grupo docker para o usuário real (idempotente)
    log_step "[+] Adicionando '${REAL_USER}' ao grupo docker..."
    groupadd -f docker >/dev/null 2>&1 || true
    if [ "$REAL_USER" != "root" ]; then
        usermod -aG docker "$REAL_USER" 2>/dev/null || true
        log_warn "[i] Refaça o login (ou execute 'newgrp docker') para usar docker sem sudo."
    fi
}

# ---------- D3. DISTROBOX ----------
instalar_distrobox() {
    log_header "INSTALANDO DISTROBOX (contêineres estilo toolbox)"
    if testa_status distrobox; then
        log_ok "[✓] Distrobox já está instalado."
        return
    fi

    instalar_pacotes "distrobox" "distrobox" "distrobox"
    if command -v distrobox >/dev/null 2>&1; then
        INSTALLED_CACHE[distrobox]=1
        log_ok "[✓] Distrobox instalado com sucesso!"
    else
        log_warn "[!] Não foi possível confirmar a instalação do Distrobox."
    fi
}

# ---------- D4. HOMEBREW (LINUXBREW) ----------
instalar_homebrew() {
    log_header "INSTALANDO HOMEBREW (Linuxbrew)"
    if testa_status brew; then
        log_ok "[✓] Homebrew já está instalado."
        return
    fi

    local h
    h="$(home_usuario)"
    local grupo
    grupo="$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")"
    log_step "[1/3] Preparando diretório /home/linuxbrew para o usuário ${REAL_USER}..."
    mkdir -p /home/linuxbrew/.linuxbrew
    chown -R "$REAL_USER":"$grupo" /home/linuxbrew 2>/dev/null || true

    log_step "[2/3] Executando instalador oficial (não-interativo)..."
    # shellcheck disable=SC2016 # intencional: $() deve expandir no subshell do usuário
    local cmd_brew='NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    if su - "$REAL_USER" -c "$cmd_brew" >/dev/null 2>&1; then
        # Configura o shell do usuário (idempotente — não duplica linha)
        log_step "[3/3] Configurando .bashrc do usuário ${REAL_USER}..."
        local bashrc="${h}/.bashrc"
        # shellcheck disable=SC2016 # intencional: $() deve expandir quando o .bashrc rodar
        if ! grep -qF 'brew shellenv' "$bashrc" 2>/dev/null; then
            printf 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' >> "$bashrc"
        fi
        INSTALLED_CACHE[brew]=1
        log_ok "[✓] Homebrew instalado e configurado no ${bashrc}!"
    else
        log_warn "[!] Falha na instalação do Homebrew. Verifique a conexão e a base dev."
    fi
}

# ---------- D5. VS CODE (FLATPAK UNIVERSAL) ----------
instalar_vscode() {
    log_header "INSTALANDO VISUAL STUDIO CODE (Flatpak)"
    if testa_status vscode; then
        log_ok "[✓] VS Code já está instalado."
        return
    fi

    garantindo_flatpak
    log_step "[+] Instalando com.visualstudio.code via Flatpak..."
    if flatpak install -y flathub com.visualstudio.code >/dev/null 2>&1; then
        INSTALLED_CACHE[vscode]=1
        log_ok "[✓] VS Code instalado com sucesso! (flatpak run com.visualstudio.code)"
    else
        log_warn "[!] Falha na instalação do VS Code via Flatpak."
    fi
}

# ---------- D6. OBSIDIAN (FLATPAK UNIVERSAL) ----------
instalar_obsidian() {
    log_header "INSTALANDO OBSIDIAN (Flatpak)"
    if testa_status obsidian; then
        log_ok "[✓] Obsidian já está instalado."
        return
    fi

    garantindo_flatpak
    log_step "[+] Instalando md.obsidian.Obsidian via Flatpak..."
    if flatpak install -y flathub md.obsidian.Obsidian >/dev/null 2>&1; then
        INSTALLED_CACHE[obsidian]=1
        log_ok "[✓] Obsidian instalado com sucesso! (flatpak run md.obsidian.Obsidian)"
    else
        log_warn "[!] Falha na instalação do Obsidian via Flatpak."
    fi
}

# ---------- D7. OPENCODE CLI ----------
instalar_opencode() {
    log_header "INSTALANDO OPENCODE CLI"
    if testa_status opencode; then
        log_ok "[✓] OpenCode CLI já está instalado."
        return
    fi

    log_step "[+] Executando instalador oficial (opencode.ai)..."
    local h
    h="$(home_usuario)"
    local sucesso=0
    if [ "$REAL_USER" != "root" ]; then
        if su - "$REAL_USER" -c 'curl -fsSL https://opencode.ai/install | bash' >/dev/null 2>&1; then
            sucesso=1
            if [ -x "${h}/.opencode/bin/opencode" ]; then
                ln -sf "${h}/.opencode/bin/opencode" /usr/local/bin/opencode 2>/dev/null || true
            elif [ -x "${h}/.local/bin/opencode" ]; then
                ln -sf "${h}/.local/bin/opencode" /usr/local/bin/opencode 2>/dev/null || true
            fi
        fi
    else
        if curl -fsSL https://opencode.ai/install | bash >/dev/null 2>&1; then
            sucesso=1
            [ -x "/root/.opencode/bin/opencode" ] && ln -sf "/root/.opencode/bin/opencode" /usr/local/bin/opencode 2>/dev/null || true
        fi
    fi

    if (( sucesso )) || testa_status opencode; then
        INSTALLED_CACHE[opencode]=1
        log_ok "[✓] OpenCode CLI instalado com sucesso! (opencode)"
    else
        log_warn "[!] Falha na instalação do OpenCode CLI."
    fi
}

# ---------- D8. ANTIGRAVITY CLI ----------
instalar_antigravity() {
    log_header "INSTALANDO ANTIGRAVITY CLI"
    if testa_status antigravity; then
        log_ok "[✓] Antigravity CLI já está instalado."
        return
    fi

    log_step "[+] Executando instalador oficial (antigravity.google)..."
    local h
    h="$(home_usuario)"
    if curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir /usr/local/bin >/dev/null 2>&1; then
        [ -x /usr/local/bin/agy ] && ln -sf /usr/local/bin/agy /usr/local/bin/antigravity 2>/dev/null || true
        if [ "$REAL_USER" != "root" ] && [ -d "${h}" ]; then
            mkdir -p "${h}/.local/bin"
            ln -sf /usr/local/bin/agy "${h}/.local/bin/agy" 2>/dev/null || true
            ln -sf /usr/local/bin/agy "${h}/.local/bin/antigravity" 2>/dev/null || true
            chown -h "$REAL_USER" "${h}/.local/bin/agy" "${h}/.local/bin/antigravity" 2>/dev/null || true
        fi
        INSTALLED_CACHE[antigravity]=1
        log_ok "[✓] Antigravity CLI instalado com sucesso! (agy / antigravity)"
    else
        log_warn "[!] Falha na instalação do Antigravity CLI."
    fi
}

# ---------- C1. JETBRAINSMONO NERD FONT ----------
instalar_nerdfont() {
    log_header "INSTALANDO JETBRAINSMONO NERD FONT (estilo Omarchy)"
    if testa_status nerdfont; then
        log_ok "[✓] JetBrainsMono Nerd Font já está instalada."
        return
    fi

    instalar_pacotes "fontconfig unzip curl" "fontconfig unzip curl" "fontconfig unzip curl"

    log_step "[1/3] Criando diretório de fontes..."
    mkdir -p /usr/local/share/fonts/NerdFonts

    log_step "[2/3] Baixando JetBrainsMono.zip (release oficial)..."
    if curl -fLo /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip >/dev/null 2>&1; then
        unzip -o /tmp/JetBrainsMono.zip -d /usr/local/share/fonts/NerdFonts >/dev/null 2>&1
        rm -f /tmp/JetBrainsMono.zip
    else
        log_warn "[!] Falha no download da Nerd Font."
        return
    fi

    log_step "[3/3] Atualizando cache de fontes..."
    fc-cache -fv >/dev/null 2>&1

    if fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
        INSTALLED_CACHE[nerdfont]=1
        log_ok "[✓] JetBrainsMono Nerd Font instalada e ativa!"
    else
        log_warn "[!] Fonte instalada em /usr/local/share/fonts/NerdFonts, mas não listada no fc-list."
    fi
}

# ---------- C2. FLATPAK + FLATHUB ----------
garantindo_flatpak() {
    # Helper: garante flatpak + flathub antes de instalar apps flatpak
    if ! command -v flatpak >/dev/null 2>&1; then
        log_step "[+] Instalando Flatpak..."
        instalar_pacotes "flatpak" "flatpak" "flatpak"
    fi
    if ! flatpak remotes 2>/dev/null | grep -qi "flathub"; then
        log_step "[+] Ativando repositório Flathub..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    fi
    INSTALLED_CACHE[flatpak]=1
}

instalar_flatpak() {
    log_header "INSTALANDO FLATPAK + REPOSITÓRIO FLATHUB"
    if testa_status flatpak; then
        log_ok "[✓] Flatpak + Flathub já estão configurados."
        return
    fi

    garantindo_flatpak
    if flatpak remotes 2>/dev/null | grep -qi "flathub"; then
        log_ok "[✓] Flatpak + Flathub configurados com sucesso!"
    else
        log_warn "[!] Não foi possível confirmar o Flathub."
    fi
}

# ---------- C3. GNOME TWEAKS + RESTRICTED EXTRAS ----------
instalar_gnome_tweaks() {
    log_header "INSTALANDO GNOME TWEAKS (e codecs restritos onde aplicável)"
    if testa_status tweaks; then
        log_ok "[✓] GNOME Tweaks já está instalado."
        return
    fi

    case "$PKG_MGR" in
        apt)
            instalar_pacotes "gnome-tweaks ubuntu-restricted-extras" "" ""
            ;;
        dnf)
            instalar_pacotes "" "gnome-tweaks" ""
            log_step "[i] Fedora: codecs proprietários via RPM Fusion (manual)."
            ;;
        pacman)
            instalar_pacotes "" "" "gnome-tweaks"
            log_step "[i] Arch: codecs proprietários via AUR (ex: ttf-ms-fonts)."
            ;;
    esac

    if command -v gnome-tweaks >/dev/null 2>&1; then
        INSTALLED_CACHE[tweaks]=1
        log_ok "[✓] GNOME Tweaks instalado com sucesso!"
    else
        log_warn "[!] Não foi possível confirmar a instalação do GNOME Tweaks."
    fi
}

# ---------- P1. PERFIL DEV COMPLETO (MODO BRNCZZR) ----------
perfil_dev_completo() {
    log_header "PERFIL DEV COMPLETO (MODO BRNCZZR)"
    log_info "[*] Instalando workstation dev completa — pode demorar..."

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

    log_header_success "PERFIL DEV COMPLETO CONCLUÍDO!"
}

# ==============================================================================
# 8. MOTOR DE INTERFACE ESTILO BIOS (SETUP UTILITY)
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
    HELP_TEXTS=()
    HELP_COLORS=()

    # 0: Cabeçalho do Painel
    help_add " Informações do Item" "$C_YELLOW"
    
    # 1: Linha divisória horizontal
    help_add "$(rep_char '─' 45)" "$C_DARKCYAN"

    if (( idx < 0 || idx >= ${#IT_CODES[@]} )); then
        while (( ${#HELP_TEXTS[@]} < 21 )); do
            help_add "" "$C_DARKGRAY"
        done
        return
    fi

    # 2: Nome do Item
    local nome="${IT_TEXTS[$idx]:-Item}"
    if (( ${#nome} > 43 )); then
        nome="${nome:0:42}…"
    fi
    help_add " $nome" "$C_WHITE"

    # 3: Categoria
    local cat="${IT_CATS[$idx]:-}"
    if [[ -n "$cat" ]]; then
        cat=" Categoria: $cat"
        if (( ${#cat} > 44 )); then
            cat="${cat:0:43}…"
        fi
    fi
    help_add "$cat" "$C_DARKGRAY"

    # 4: Linha em branco
    help_add "" "$C_DARKGRAY"

    # 5: Rótulo Descrição
    help_add " Descrição:" "$C_CYAN"

    # 6..8: Word-wrap da descrição em até 3 linhas de 43 caracteres
    local desc="${IT_DESCS[$idx]:-Sem descrição adicional para este item.}"
    local -a desc_lines=()
    mapfile -t desc_lines < <(word_wrap "$desc" 43)
    local k
    for ((k = 0; k < 3; k++)); do
        if (( k < ${#desc_lines[@]} )); then
            local d="${desc_lines[$k]}"
            if (( ${#d} > 44 )); then
                d="${d:0:44}"
            fi
            help_add " $d" "$C_GRAY"
        else
            help_add "" "$C_GRAY"
        fi
    done

    # 9: Linha em branco
    help_add "" "$C_DARKGRAY"

    # 10: Rótulo Pacote
    help_add " Identificador / Pacote:" "$C_CYAN"

    # 11: ID do Pacote
    local pkg="   ${IT_PKGS[$idx]:-N/A}"
    if (( ${#pkg} > 45 )); then
        pkg="${pkg:0:44}…"
    fi
    help_add "$pkg" "$C_WHITE"

    # 12: Linha em branco
    help_add "" "$C_DARKGRAY"

    # 13: Rótulo Status
    help_add " Status no Linux:" "$C_CYAN"

    # 14: Valor Status
    local special=0
    [[ "${IT_SPECIAL[$idx]}" == "1" ]] && special=1
    if (( special )); then
        help_add "   [*] Rotina em Lote / Especial" "$C_YELLOW"
    elif item_instalado "$idx"; then
        help_add "   [✓] Já instalado no sistema" "$C_GREEN"
    else
        help_add "   [ ] Não instalado / Pendente" "$C_DARKGRAY"
    fi

    # 15: Linha em branco
    help_add "" "$C_DARKGRAY"

    # 16: Linha divisória inferior
    help_add "$(rep_char '─' 45)" "$C_DARKCYAN"

    # 17..20: Atalhos do Setup
    help_add " Atalhos do Setup:" "$C_DARKGRAY"
    help_add "   [Espaço]  Marca p/ fila em lote" "$C_GRAY"
    help_add "   [Enter]   Executa seleção" "$C_GRAY"
    help_add "   [Q]       Fecha o terminal" "$C_GRAY"

    while (( ${#HELP_TEXTS[@]} < 21 )); do
        help_add "" "$C_DARKGRAY"
    done
}

# Barra de menus estilo BIOS (abas sempre visíveis no topo, 120 colunas)
mostrar_barra_abas() {
    local aba="$1"
    local inner=$((LARGURA - 4))
    local -a tabs=("SISTEMA" "REDE" "APPS" "DEV" "CONFIG" "PERFIS")
    local -a labels_in=("  Sistema  " "  Rede  " "  Apps  " "  Dev  " "  Config  " "  Perfis  ")
    local -a labels_ac=("[ SISTEMA ]" "[ REDE ]" "[ APPS ]" "[ DEV ]" "[ CONFIG ]" "[ PERFIS ]")

    local total_tab_len=0 i
    for i in "${!tabs[@]}"; do
        total_tab_len=$((total_tab_len + ${#labels_in[$i]}))
    done
    local spaces=$((inner - total_tab_len))
    local num_gaps=$(( ${#tabs[@]} + 1 ))
    local base_gap=$(( spaces / num_gaps ))
    local extra=$(( spaces % num_gaps ))

    local tab_line="" g gap
    for ((g = 0; g < num_gaps; g++)); do
        gap=$base_gap
        (( g < extra )) && gap=$((gap + 1))
        tab_line+="$(rep_char ' ' "$gap")"
        if (( g < ${#tabs[@]} )); then
            if [[ "${tabs[$g]}" == "$aba" ]]; then
                tab_line+="${C_TAB}${labels_ac[$g]}${C_RESET}"
            else
                tab_line+="${C_DARKGRAY}${labels_in[$g]}${C_RESET}"
            fi
        fi
    done

    printf '%s\n' "${C_CYAN}║ ${tab_line}${C_CYAN} ║${C_RESET}"
}

# Cabeçalho da tela: título + badge + linha de informações do sistema (telemetria)
mostrar_cabecalho() {
    local aba="$1"
    local inner=$((LARGURA - 4))
    local titulo=" LINUX-TOOLBOX TUI · Setup Utility"
    local badge="[ LINUX ] "
    local esp=$((inner - ${#titulo} - ${#badge}))
    (( esp < 0 )) && esp=0
    printf '%s\n' "${C_CYAN}║ ${titulo}$(rep_char ' ' "$esp")${badge} ║${C_RESET}"

    local data host user ip info pad_info
    data="$(date +%d/%m/%Y)"
    host="$(hostname)"
    user="${REAL_USER:-$(id -un)}"
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="Sem Rede"
    info=" Data: $data | Computador: $host | Usuário: $user | IP: $ip"
    pad_info=$((inner - ${#info}))
    (( pad_info < 0 )) && pad_info=0
    printf '%s\n' "${C_CYAN}║ ${C_DARKGRAY}${info}$(rep_char ' ' "$pad_info")${C_CYAN} ║${C_RESET}"
}

# Renderiza a tela inteira (30 linhas estilo Setup Utility — 120x30)
show_bios_screen() {
    local aba="$1"
    if (( TELA_SUJA )); then
        clear 2>/dev/null || printf '\e[2J'
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

        # --- LADO ESQUERDO: LISTA DE ITENS (68 colunas) ---
        local left_full left_color is_selected=0
        (( i == SEL )) && is_selected=1

        if (( i < total )); then
            local code="${IT_CODES[$i]}"
            local inst=0 special=0 mark=" " cursor="  "
            item_instalado "$i" && inst=1
            [[ "${IT_SPECIAL[$i]}" == "1" ]] && special=1

            if (( inst )) || [[ -n "${MARKS[$code]+x}" ]]; then
                mark="✓"
            fi
            if (( is_selected )); then
                cursor="► "
            fi

            local prefix
            prefix="$(printf "%s[%s] %-4s " "$cursor" "$mark" "$code")"
            local sufixo=""
            left_color="$C_GRAY"
            if (( special )); then
                left_color="$C_YELLOW"
            elif (( inst )); then
                left_color="$C_GREEN"
                sufixo="[INSTALADO]"
            elif [[ -n "${MARKS[$code]+x}" ]]; then
                left_color="$C_CYAN"
            fi

            local max_nome=$(( W_LISTA - ${#prefix} - ${#sufixo} ))
            if [[ -n "$sufixo" ]]; then
                max_nome=$((max_nome - 1))
            fi

            local nome="${IT_TEXTS[$i]}"
            if (( ${#nome} > max_nome )); then
                local cut_len=$((max_nome - 1))
                (( cut_len < 0 )) && cut_len=0
                nome="${nome:0:$cut_len}…"
            fi

            local meio="${prefix}${nome}"
            if [[ -n "$sufixo" ]]; then
                local pad_len=$(( W_LISTA - ${#sufixo} - ${#meio} ))
                (( pad_len < 0 )) && pad_len=0
                left_full="${meio}$(rep_char ' ' "$pad_len")${sufixo}"
            else
                local pad_len=$(( W_LISTA - ${#meio} ))
                (( pad_len < 0 )) && pad_len=0
                left_full="${meio}$(rep_char ' ' "$pad_len")"
            fi
            if (( ${#left_full} > W_LISTA )); then
                left_full="${left_full:0:$W_LISTA}"
            fi
        else
            left_full="$(rep_char ' ' "$W_LISTA")"
            left_color="$C_GRAY"
        fi

        # --- LADO DIREITO: PAINEL DE AJUDA DO ITEM (45 colunas) ---
        local rtext="${HELP_TEXTS[$j]:-}"
        local rcolor="${HELP_COLORS[$j]:-$C_DARKGRAY}"
        if (( ${#rtext} > W_HELP )); then
            rtext="${rtext:0:$((W_HELP - 1))}…"
        fi
        local pad_r=$(( W_HELP - ${#rtext} ))
        (( pad_r < 0 )) && pad_r=0
        local rformatted
        rformatted="${rtext}$(rep_char ' ' "$pad_r")"

        # Linha montada: "║ " (2) + Left (68) + " ║ " (3) + Right (45) + " ║" (2) = 120 colunas
        if (( is_selected && i < total )); then
            printf '%s%s%s%s%s\n' \
                "${C_CYAN}║ ${C_RESET}" "${C_BLOCK}${left_full}${C_RESET}" "${C_CYAN} ║ ${C_RESET}" "${rcolor}${rformatted}${C_RESET}" "${C_CYAN} ║${C_RESET}"
        else
            printf '%s%s%s%s%s\n' \
                "${C_CYAN}║ ${C_RESET}" "${left_color}${left_full}${C_RESET}" "${C_CYAN} ║ ${C_RESET}" "${rcolor}${rformatted}${C_RESET}" "${C_CYAN} ║${C_RESET}"
        fi
    done

    # ---- rodapé: dicas de navegação espaçadas estilo BIOS ----
    linha_split_footer
    montar_dicas_footer
    linha_borda 0
}

# Rodapé com dicas de navegação distribuídas proporcionalmente (fiel ao win-toolbox.ps1)
montar_dicas_footer() {
    local inner=$((LARGURA - 4))
    local -a nav=("←→ Trocar Menu" "↑↓ Mover" "Espaço [✓] Marcar" "Enter Executar")
    if (( ${#MARKS[@]} > 0 )); then
        nav+=("Marcados: ${#MARKS[@]}")
    fi
    if (( PAGINAS > 1 )); then
        nav+=("Pg $((PAGE + 1))/$PAGINAS")
    fi
    nav+=("Q Sair")

    local total_len=0 t
    for t in "${nav[@]}"; do
        total_len=$((total_len + ${#t}))
    done

    local total_spaces=$(( inner - total_len ))
    (( total_spaces < 0 )) && total_spaces=0

    local num_gaps=$(( ${#nav[@]} + 1 ))
    local base_gap=$(( total_spaces / num_gaps ))
    local extra=$(( total_spaces % num_gaps ))

    local linha="" g gap
    for ((g = 0; g < num_gaps; g++)); do
        gap=$base_gap
        (( g < extra )) && gap=$((gap + 1))
        linha+="$(rep_char ' ' "$gap")"
        if (( g < ${#nav[@]} )); then
            linha+="${nav[$g]}"
        fi
    done
    if (( ${#linha} > inner )); then
        linha="${linha:0:$inner}"
    elif (( ${#linha} < inner )); then
        linha+="$(rep_char ' ' $((inner - ${#linha})))"
    fi

    printf '%s\n' "${C_CYAN}║ ${linha} ║${C_RESET}"
}

# -----------------------------------------------------------------------------
# LEITURA DE TECLAS (100% nativa — sem gum, sem instalação)
# Códigos: 1↑ 2↓ 3→ 4← 5Espaço 6Enter 7PgUp 8PgDn 9Esc 10Q 17Home 18End
#          21..26 = teclas 1..6 ou S/R/A/D/C/P (atalhos diretos para cada aba)
# -----------------------------------------------------------------------------
ler_tecla() {
    local key ch1 ch2
    TECLA=0

    if ! IFS= read -rsn1 key; then
        TECLA=10   # EOF (stdin fechado) → encerra o TUI com segurança
        return
    fi

    if [[ "$key" == $'\e' ]]; then
        if IFS= read -rsn1 -t 0.05 ch1; then
            if [[ "$ch1" == '[' ]]; then
                if IFS= read -rsn1 -t 0.05 ch2; then
                    case "$ch2" in
                        A) TECLA=1 ;; # Up
                        B) TECLA=2 ;; # Down
                        C) TECLA=3 ;; # Right
                        D) TECLA=4 ;; # Left
                        H) TECLA=17 ;; # Home
                        F) TECLA=18 ;; # End
                        1|7)
                            read -rsn1 -t 0.05 _ 2>/dev/null || true
                            TECLA=17 # Home
                            ;;
                        4|8)
                            read -rsn1 -t 0.05 _ 2>/dev/null || true
                            TECLA=18 # End
                            ;;
                        5)
                            read -rsn1 -t 0.05 _ 2>/dev/null || true
                            TECLA=7 # PageUp
                            ;;
                        6)
                            read -rsn1 -t 0.05 _ 2>/dev/null || true
                            TECLA=8 # PageDown
                            ;;
                        *) TECLA=9 ;; # Esc
                    esac
                else
                    TECLA=9
                fi
            elif [[ "$ch1" == 'O' ]]; then
                if IFS= read -rsn1 -t 0.05 ch2; then
                    case "$ch2" in
                        H) TECLA=17 ;; # Home
                        F) TECLA=18 ;; # End
                        *) TECLA=9 ;;
                    esac
                else
                    TECLA=9
                fi
            else
                TECLA=9
            fi
        else
            TECLA=9 # Tecla Esc pura
        fi
        return
    fi

    case "$key" in
        ' ')                 TECLA=5 ;;
        $'\n'|$'\r')         TECLA=6 ;;
        $'\t')               TECLA=3 ;; # Tab = Próxima aba (igual RightArrow)
        [qQ])                TECLA=10 ;;
        [sS]|1)              TECLA=21 ;;
        [rR]|2)              TECLA=22 ;;
        [aA]|3)              TECLA=23 ;;
        [dD]|4)              TECLA=24 ;;
        [cC]|5)              TECLA=25 ;;
        [pP]|6)              TECLA=26 ;;
        *)                   TECLA=0 ;;
    esac
}

# -----------------------------------------------------------------------------
# Motor principal: renderiza a tela, lê teclas, gerencia seleção/marcação/página
# Define o resultado em MENU_RES: "TAB_<ABA>", "Q" ou lote (ex: "D1,D4,P1")
# -----------------------------------------------------------------------------
read_bios_menu() {
    local aba="$1"
    SEL=0; PAGE=0
    MENU_RES=""
    local total=${#IT_CODES[@]}
    PAGINAS=$(( (total + PAGE_SIZE - 1) / PAGE_SIZE ))
    (( PAGINAS < 1 )) && PAGINAS=1

    while true; do
        montar_help_lines "$SEL"
        show_bios_screen "$aba"
        ler_tecla

        local fim_pagina code special lote

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
                    SISTEMA) MENU_RES="TAB_REDE";  return ;;
                    REDE)    MENU_RES="TAB_APPS";  return ;;
                    APPS)    MENU_RES="TAB_DEV";   return ;;
                    DEV)     MENU_RES="TAB_CONFIG"; return ;;
                    CONFIG)  MENU_RES="TAB_PERFIS"; return ;;
                    PERFIS)  MENU_RES="TAB_SISTEMA"; return ;;
                esac
                ;;
            4)  # ←
                case "$aba" in
                    SISTEMA) MENU_RES="TAB_PERFIS"; return ;;
                    REDE)    MENU_RES="TAB_SISTEMA"; return ;;
                    APPS)    MENU_RES="TAB_REDE";  return ;;
                    DEV)     MENU_RES="TAB_APPS";  return ;;
                    CONFIG)  MENU_RES="TAB_DEV";   return ;;
                    PERFIS)  MENU_RES="TAB_CONFIG"; return ;;
                esac
                ;;
            7)  # PageUp
                if (( PAGE > 0 )); then
                    PAGE=$((PAGE - 1))
                    SEL=$(( PAGE * PAGE_SIZE ))
                fi
                ;;
            8)  # PageDown
                if (( PAGE < PAGINAS - 1 )); then
                    PAGE=$((PAGE + 1))
                    SEL=$(( PAGE * PAGE_SIZE ))
                fi
                ;;
            17) # Home
                PAGE=0
                SEL=0
                ;;
            18) # End
                PAGE=$((PAGINAS - 1))
                SEL=$((total - 1))
                (( SEL < 0 )) && SEL=0
                ;;
            21) MENU_RES="TAB_SISTEMA"; return ;; # 1 / S
            22) MENU_RES="TAB_REDE"; return ;;    # 2 / R
            23) MENU_RES="TAB_APPS"; return ;;    # 3 / A
            24) MENU_RES="TAB_DEV"; return ;;     # 4 / D
            25) MENU_RES="TAB_CONFIG"; return ;;  # 5 / C
            26) MENU_RES="TAB_PERFIS"; return ;;  # 6 / P
            5)  # Espaço → marca/desmarca
                code="${IT_CODES[$SEL]}"
                special=0
                [[ "${IT_SPECIAL[$SEL]}" == "1" ]] && special=1
                if (( special )) || ! item_instalado "$SEL"; then
                    if [[ -n "${MARKS[$code]+x}" ]]; then
                        unset 'MARKS[$code]'
                    else
                        MARKS["$code"]=1
                    fi
                fi
                ;;
            6)  # Enter → executa marcados em lote ou o selecionado
                lote=""
                if (( ${#MARKS[@]} > 0 )); then
                    local all_known=("0" "R1" "R2" "A1" "A2" "D1" "D2" "D3" "D4" "D5" "D6" "D7" "D8" "C1" "C2" "C3" "P1")
                    local k
                    for k in "${all_known[@]}"; do
                        if [[ -n "${MARKS[$k]+x}" ]]; then
                            [[ -n "$lote" ]] && lote+=","
                            lote+="$k"
                        fi
                    done
                    for k in "${!MARKS[@]}"; do
                        if [[ ! " ${all_known[*]} " =~ [[:space:]]${k}[[:space:]] ]]; then
                            [[ -n "$lote" ]] && lote+=","
                            lote+="$k"
                        fi
                    done
                else
                    lote="${IT_CODES[$SEL]}"
                fi
                MENU_RES="$lote"
                return
                ;;
            9|10)  # Esc / Q → sai
                MENU_RES="Q"
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
    adicionar_item "R2" "Habilitar mDNS/Avahi (Acesso por Nome .local)" \
        "Instala avahi-daemon (mDNS), habilita no boot e permite conectar por NOME.local em vez do IP — ideal quando o DHCP troca o IP com frequência." \
        "apt: avahi-daemon | dnf: avahi-daemon | pacman: avahi" "Acesso Remoto / mDNS" "avahi"
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
    read_bios_menu SISTEMA
    case "$MENU_RES" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$MENU_RES" ]] && dispatch_execution "$MENU_RES" ;;
    esac
}

invocar_menu_rede() {
    preparar_menu_rede
    read_bios_menu REDE
    case "$MENU_RES" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE) ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$MENU_RES" ]] && dispatch_execution "$MENU_RES" ;;
    esac
}

invocar_menu_apps() {
    preparar_menu_apps
    read_bios_menu APPS
    case "$MENU_RES" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS) ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$MENU_RES" ]] && dispatch_execution "$MENU_RES" ;;
    esac
}

invocar_menu_dev() {
    preparar_menu_dev
    read_bios_menu DEV
    case "$MENU_RES" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV) ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$MENU_RES" ]] && dispatch_execution "$MENU_RES" ;;
    esac
}

invocar_menu_config() {
    preparar_menu_config
    read_bios_menu CONFIG
    case "$MENU_RES" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG) ;;
        TAB_PERFIS)  MENU_ATUAL=PERFIS ;;
        *) [[ -n "$MENU_RES" ]] && dispatch_execution "$MENU_RES" ;;
    esac
}

invocar_menu_perfis() {
    preparar_menu_perfis
    read_bios_menu PERFIS
    case "$MENU_RES" in
        Q) MENU_ATUAL=EXIT ;;
        TAB_SISTEMA) MENU_ATUAL=SISTEMA ;;
        TAB_REDE)    MENU_ATUAL=REDE ;;
        TAB_APPS)    MENU_ATUAL=APPS ;;
        TAB_DEV)     MENU_ATUAL=DEV ;;
        TAB_CONFIG)  MENU_ATUAL=CONFIG ;;
        TAB_PERFIS) ;;
        *) [[ -n "$MENU_RES" ]] && dispatch_execution "$MENU_RES" ;;
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
        "R2") habilitar_mdns_avahi ;;
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

    clear 2>/dev/null || printf '\e[2J\e[H'
    tput cnorm 2>/dev/null || true

    local inner=$((LARGURA - 4))
    printf '%s\n' "${C_CYAN}╭─ EXECUTANDO TAREFAS SELECIONADAS $(rep_char '─' 63) [ PROCESSO ATIVO ] ─╮${C_RESET}"
    local msg=" Lote em andamento: $escolha"
    if (( ${#msg} > inner )); then
        msg="${msg:0:$((inner - 3))}..."
    fi
    local pad_m=$(( inner - ${#msg} ))
    (( pad_m < 0 )) && pad_m=0
    printf '%s%s\n' "${C_CYAN}│ ${C_YELLOW}${msg}$(rep_char ' ' "$pad_m")" "${C_CYAN} │${C_RESET}"
    printf '%s\n\n' "${C_CYAN}╰$(rep_char '─' $((LARGURA - 2)))╯${C_RESET}"

    execute_batch_options "$escolha"

    printf '\n%s\n' "${C_GREEN}╭$(rep_char '─' $((LARGURA - 2)))╮${C_RESET}"
    local concl=" [✓] Todas as tarefas solicitadas foram concluídas!"
    local pad_c=$(( inner - ${#concl} ))
    (( pad_c < 0 )) && pad_c=0
    printf '%s%s\n' "${C_GREEN}│ ${concl}$(rep_char ' ' "$pad_c")" " │${C_RESET}"
    printf '%s\n' "${C_GREEN}╰$(rep_char '─' $((LARGURA - 2)))╯${C_RESET}"

    wait_user
    INSTALLED_CACHE=()
    MARKS=()
    TELA_SUJA=1
    tput civis 2>/dev/null || true
}

wait_user() {
    if (( IS_HEADLESS )); then
        return 0
    fi
    printf '\n%s[Pressione ENTER para continuar...]%s\n' "$C_GRAY" "$C_RESET"
    read -r _ 2>/dev/null || true
}

# ==============================================================================
# 11. VALIDAÇÃO DE TERMINAL, LIMPEZA E LOOP PRINCIPAL
# ==============================================================================
configurar_terminal() {
    # Tenta redimensionar a janela do terminal para 120x30 via ANSI escape sequence
    printf '\e[8;%d;%dt' "$ALTURA" "$LARGURA" 2>/dev/null || true

    local cols lines
    cols="$(tput cols 2>/dev/null || echo 0)"
    lines="$(tput lines 2>/dev/null || echo 0)"
    if (( cols > 0 && lines > 0 )) && (( cols < LARGURA || lines < ALTURA )); then
        printf '\n%s[!] Recomendado: janela em pelo menos %sx%s (atual: %sx%s).%s\n' \
            "$C_YELLOW" "$LARGURA" "$ALTURA" "$cols" "$lines" "$C_RESET"
        printf '%s[*] Dica: maximize a janela do terminal para exibir o layout BIOS perfeito.%s\n' \
            "$C_CYAN" "$C_RESET"
        printf '%s[*] Iniciando interface em 2 segundos...%s\n' \
            "$C_GRAY" "$C_RESET"
        sleep 2
    fi
}

restaurar_terminal() {
    tput rmcup 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

exibir_ajuda() {
    cat <<EOF
LINUX-TOOLBOX-TUI — Caixa de Ferramentas & Pós-Instalação para Linux
Interface estilo BIOS (Setup Utility) e automação de pós-instalação.

Uso:
  sudo ./linux-toolbox.sh [OPÇÕES | CÓDIGOS]

Opções:
  --preview [ABA]    Visualiza a interface sem instalar nada (dispensa root)
                     Abas válidas: SISTEMA, REDE, APPS, DEV, CONFIG, PERFIS
  -h, --help         Exibe esta mensagem de ajuda

Modo Headless (lote):
  sudo ./linux-toolbox.sh D1,D4,C1    Executa os itens especificados diretamente
  sudo ./linux-toolbox.sh P1          Executa perfil dev completo sem abrir a TUI

Atalhos na TUI:
  ↑/↓: Mover seleção          ←/→ ou Tab: Trocar menu
  Espaço: Marcar p/ lote [✓]  Enter: Executar seleção/marcados
  1..6 ou S/R/A/D/C/P: Abas   Q ou Esc: Sair
EOF
}

preview_tela() {
    # --preview [ABA]: renderiza a aba especificada sem exigir root (padrão: SISTEMA)
    local aba="${1:-SISTEMA}"
    aba="$(echo "$aba" | tr '[:lower:]' '[:upper:]')"
    detectar_distro
    detectar_usuario_real
    MARKS=()
    case "$aba" in
        REDE)   preparar_menu_rede ;;
        APPS)   preparar_menu_apps ;;
        DEV)    preparar_menu_dev ;;
        CONFIG) preparar_menu_config ;;
        PERFIS) preparar_menu_perfis ;;
        *)      aba="SISTEMA"; preparar_menu_sistema ;;
    esac
    montar_help_lines 0
    TELA_SUJA=1
    show_bios_screen "$aba"
    printf '%s\n' "$C_RESET"
    exit 0
}

main() {
    # Se stdin não for um terminal interativo (ex: curl ... | bash), reconecta ao terminal físico /dev/tty
    if [ ! -t 0 ] && [ -e /dev/tty ]; then
        exec 0</dev/tty
    fi

    case "${1:-}" in
        --preview)
            preview_tela "${2:-SISTEMA}"
            ;;
        -h|--help)
            exibir_ajuda
            exit 0
            ;;
        "")
            ;;
        *)
            # Modo headless (lote por argumento, ex: ./linux-toolbox.sh D1,D4,P1)
            IS_HEADLESS=1
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
    configurar_terminal

    tput smcup 2>/dev/null || true   # tela alternativa fullscreen
    tput civis 2>/dev/null || true   # esconde o cursor
    trap 'restaurar_terminal' EXIT

    MENU_ATUAL="SISTEMA"
    TELA_SUJA=1
    MARKS=()

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
    printf '\n%s[+] Encerrando linux-toolbox-tui. Até logo!%s\n\n' "$C_GREEN" "$C_RESET"
}

main "$@"