# 🐧 linux-toolbox-tui — Caixa de Ferramentas & Pós-Instalação para Linux

> **Suporta:** Debian/Ubuntu (`apt`) · Fedora (`dnf`) · Arch/Omarchy (`pacman`)
> Interface interativa de terminal (TUI) com **bordas Unicode**, **indicadores dinâmicos de status (`[✓]` Verde / `[ ]` Branco)**, títulos em negrito ANSI e detecção automática de distribuição.

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

* 🟢 **Status Dinâmico em Tempo Real:** Cada tarefa exibe `[✓]` em Verde se já estiver concluída no sistema, ou `[ ]` em Branco se pendente.
* 🟡 **Títulos em Negrito e Alto Contraste:** Seções formatadas em negrito ANSI para leitura imediata.
* 📐 **Alinhamento de 90 Colunas:** Grid calibrado com bordas Unicode arredondadas (`╭─`, `│`, `╰─`).
* 🔄 **Detecção Automática de Distro:** Identifica `apt`, `dnf` ou `pacman` sozinho e usa o nome correto do serviço (`ssh` no Debian/Ubuntu, `sshd` no Fedora/Arch).

---

## 🎯 Estrutura Modular dos Menus

### 1️⃣ Menu Principal — Rede & Acesso
* **REDE & ACESSO REMOTO (`M1`)**:
  * `M1`: 🚀 **Habilitar Servidor SSH** — Instala `openssh-server`, habilita o serviço no boot, libera a porta 22 no firewall (UFW/firewalld) e exibe o comando de conexão (`ssh usuario@IP`)

* **Navegação**: `Q` Sair

---

## 🧩 Execuções em Lote

Selecione várias opções separadas por vírgula em qualquer menu:
```text
╭─ Selecione as opções separadas por vírgula (ex: M1)
╰─❯ M1
```

---

## 🔒 Boas Práticas & Segurança

- Requer privilégios de **root** (executar com `sudo`) — verificado automaticamente pelo script.
- Suporta os **3 principais gerenciadores de pacotes** (`apt`, `dnf`, `pacman`) com o serviço correto para cada distro (`ssh` vs `sshd`).
- **Healthcheck com timeout** na subida do serviço — não assume sucesso cegamente.
- Firewall tratado com **UFW** e **firewalld** (os dois mais comuns); se nenhum estiver ativo, avisa em vez de falhar.
- Estrutura modular extensível: novas ferramentas entram como novas opções no dispatcher.

---

## 🗺️ Roadmap (próximas ferramentas)

* 📦 Instalação em lote de apps essenciais (`apt`/`dnf`/`pacman`)
* 🔄 Atualização geral do sistema (espelho do `0` do win-toolbox-tui)
* 🧹 Manutenção: limpeza de cache, logs e pacotes órfãos
* 🎨 Perfis automatizados (estilo MODO PMA / MODO BRNCZZR)

---

## 👤 Autor

Desenvolvido por **Bruno César Medeiros Siqueira**  
*Analista de T.I. Pleno — Ariquemes/RO*  
GitHub: [@brcesarms](https://github.com/brcesarms)

## 📄 Licença

Distribuído sob licença [MIT](LICENSE).