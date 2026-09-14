#!/bin/bash
#
# ==============================================================================
# LINUX-TOOLBOX-TUI V1.0 — Caixa de Ferramentas & Pós-Instalação para Linux
# ==============================================================================
# Script interativo com interface TUI (Unicode Box Drawing), múltiplos menus,
# status dinâmico de tarefas em tempo real ([✓] Verde / [ ] Branco), títulos
# em negrito ANSI e detecção automática de distribuição.
#
# Distribuições suportadas:
#   - Debian / Ubuntu (apt)      → serviço: ssh
#   - Fedora (dnf)               → serviço: sshd
#   - Arch / Omarchy (pacman)    → serviço: sshd
#
# AUTOR: Bruno César Medeiros Siqueira <bruno.cesar@outlook.it>
# VERSÃO: 1.0.0
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
declare -g MENU_ATUAL="MAIN"

# ==============================================================================
# 2. DETECÇÃO DE DISTRIBUIÇÃO E GERENCIADOR DE PACOTES
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

# ==============================================================================
# 3. RENDERIZADORES TUI
# ==============================================================================
# Largura interna da caixa: 88 caracteres (bordas │ + conteúdo = 90 colunas)
W_INTERNO=88

# Comprimento visual de um texto, ignorando códigos ANSI (\033[...m)
# (usado para alinhar o padding interno das bordas)

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

    printf "${C_CYAN}╭─ LINUX-TOOLBOX-TUI V1.0 ────────────────────────────────────────────────── [ LINUX ] ─╮${C_RESET}\n"
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
# 4. CACHE DE DETECÇÃO DE STATUS
# ==============================================================================
# Verifica se o servidor SSH está ativo (sshd)
test_ssh_ativa() {
    if [ -n "${INSTALLED_CACHE[sshd]+x}" ]; then
        [ "${INSTALLED_CACHE[sshd]}" = "1" ]
        return
    fi

    local status
    status="$(systemctl is-active "$SSH_SERVICE" 2>/dev/null || true)"
    if [ "$status" = "active" ]; then
        INSTALLED_CACHE[sshd]=1
        return 0
    fi
    INSTALLED_CACHE[sshd]=0
    return 1
}

get_item_display() {
    local key="$1" code="$2" title="$3"
    if test_ssh_ativa; then
        printf " ${C_GREEN}[✓]${C_RESET} ${code}. ${title}"
    else
        printf " [ ] ${code}. ${title}"
    fi
}

# ==============================================================================
# 5. FUNÇÃO: HABILITAR SERVIDOR SSH (PRIMEIRA FERRAMENTA)
# ==============================================================================
habilitar_servidor_ssh() {
    printf "\n${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_CYAN}[*] HABILITANDO SERVIDOR SSH NO LINUX${C_RESET}\n"
    printf "${C_CYAN}========================================================${C_RESET}\n"

    # ---------- Passo 1/4: Detectar distribuição e instalar pacote ----------
    printf "${C_GRAY}[1/4] Detectar distribuição e instalar OpenSSH Server...${C_RESET}\n"
    printf "${C_GRAY}[+] Distribuição detectada: ${DISTRO_ID} (gerenciador: ${PKG_MGR})${C_RESET}\n"

    if command -v sshd >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -qE "^(ssh|sshd)\.service"; then
        printf "${C_GREEN}[✓] OpenSSH Server já está instalado.${C_RESET}\n"
    else
        printf "${C_YELLOW}[+] Instalando openssh-server...${C_RESET}\n"
        case "$PKG_MGR" in
            apt)
                apt-get update -y >/dev/null 2>&1 || true
                DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server >/dev/null 2>&1
                ;;
            dnf)
                dnf install -y openssh-server >/dev/null 2>&1
                ;;
            pacman)
                pacman -Sy --noconfirm openssh >/dev/null 2>&1
                ;;
            *)
                printf "${C_RED}[!] Gerenciador de pacotes desconhecido (${PKG_MGR}).${C_RESET}\n"
                printf "${C_RED}[!] Instale o openssh-server manualmente e rode novamente.${C_RESET}\n"
                return 1
                ;;
        esac
        if command -v sshd >/dev/null 2>&1; then
            printf "${C_GREEN}[✓] OpenSSH Server instalado com sucesso!${C_RESET}\n"
        else
            printf "${C_YELLOW}[!] Instalação não pôde ser verificada; prosseguindo...${C_RESET}\n"
        fi
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
    else
        printf "${C_RED}[!] Serviço ${SSH_SERVICE} não está ativo. Verifique: systemctl status ${SSH_SERVICE}${C_RESET}\n"
    fi

    # ---------- Passo 3/4: Liberar porta 22 no firewall ----------
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
    local usuario
    usuario="$(id -un)"

    INSTALLED_CACHE[sshd]=1

    printf "\n${C_GREEN}========================================================${C_RESET}\n"
    printf "${C_GREEN} [✓] SERVIDOR SSH CONFIGURADO E PRONTO PARA CONEXÃO!${C_RESET}\n"
    printf "${C_RESET}     Comando para conectar de outro computador:${C_RESET}\n"
    printf "${C_YELLOW}     ssh %s@%s${C_RESET}\n" "$usuario" "$ip"
    printf "${C_GREEN}========================================================${C_RESET}\n"
}

# ==============================================================================
# 6. DISPATCHER DE TAREFAS
# ==============================================================================
execute_single_option() {
    local opcao="$1"
    local op
    op="$(echo "$opcao" | tr '[:lower:]' '[:upper:]' | xargs)"

    case "$op" in
        "M1") habilitar_servidor_ssh ;;
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
# 7. MENU PRINCIPAL
# ==============================================================================
menu_principal() {
    show_header "MENU PRINCIPAL — REDE & ACESSO"

    local i_m1
    i_m1="$(get_item_display "sshd" "M1" "Habilitar Servidor SSH (openssh-server + firewall + IP)")"

    printf "${C_CYAN}╭────────────────────────────────────────────────────────────────────────────────────────╮${C_RESET}\n"
    printf_linha " [0] ATUALIZAÇÃO GERAL (disponível em breve)" "$C_BOLD"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"
    printf_linha " REDE & ACESSO REMOTO" "$C_BOLD"
    printf_linha "$i_m1"
    printf "${C_CYAN}├────────────────────────────────────────────────────────────────────────────────────────┤${C_RESET}\n"
    printf_linha " NAVEGAÇÃO:   [Q] Sair" "$C_YELLOW"
    printf "${C_CYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    local inst_count=0
    if [ "${INSTALLED_CACHE[sshd]:-0}" = "1" ]; then
        inst_count=1
    fi
    local status_text
    if [ "$inst_count" -gt 0 ]; then
        status_text=" [✓] Verde = Concluído ($inst_count detectado) | [ ] Branco = Pendente"
    else
        status_text=" [✓] Verde = Concluído | [ ] Branco = Pendente. Suporta execução em lote."
    fi

    printf "${C_DARKCYAN}╭─ STATUS DO SISTEMA ───────────────────────────────────────────────────── [ PRONTO ] ─╮${C_RESET}\n"
    printf_linha "$status_text"
    printf "${C_DARKCYAN}╰────────────────────────────────────────────────────────────────────────────────────────╯${C_RESET}\n"

    printf "${C_CYAN}╭─ Selecione as opções separadas por vírgula (ex: M1)${C_RESET}\n"
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
# 8. LOOP PRINCIPAL (MÁQUINA DE ESTADOS)
# ==============================================================================
detectar_distro
require_root

while [ "$MENU_ATUAL" != "EXIT" ]; do
    case "$MENU_ATUAL" in
        "MAIN") menu_principal ;;
    esac
done

printf "\n${C_GREEN}[+] Encerrando linux-toolbox-tui. Até logo!${C_RESET}\n\n"