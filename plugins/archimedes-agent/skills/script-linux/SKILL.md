---
name: script-linux
description: Criação de scripts bash para Linux no estilo das convenções do Archimedes V2. Use ao criar, editar ou revisar qualquer script .sh — aplica shebang, set flags, comentários descritivos, emojis nos logs, chmod +x e verificação de exit code. Dispara ao ouvir "criar script", "script bash", "automação", ".sh".
compatibility: opencode
metadata:
  audience: ia-local
  workflow: scripts
---

# 🐧 Scripts Linux do Archimedes V2

Ao criar ou editar scripts bash no cofre, adote sempre os padrões consagrados de engenharia e confiabilidade.

## 📍 Onde salvar os scripts

- **Scripts operacionais do cofre** → `scripts/` (ex: `scripts/backup.sh`, `scripts/lint.sh`)
- **Configurações de ambiente** → `dotfiles/` (gerenciadas via Chezmoi)
- **Playbooks de infraestrutura** → `playbooks/` ou orquestração via Pyinfra
- ⚠️ Evite scripts improvisados onde uma ferramenta consolidada de mercado (Restic, Lychee, Pyinfra, Chezmoi) já resolve o problema.

## 📜 Estrutura Obrigatória

Todo script bash deve começar rigorosamente com:

```bash
#!/bin/bash
set -euo pipefail
```

- `-e`: Encerra o script imediatamente se um comando falhar (exit code ≠ 0).
- `-u`: Trata variáveis não declaradas como erro fatal.
- `-o pipefail`: Garante que pipelines (`cmd1 | cmd2`) falhem caso qualquer comando do pipeline falhe.

## 💬 Documentação e Comentários

- Cabeçalho descritivo explicando objetivo, pré-requisitos e uso.
- Código autoexplicativo com variáveis em caixa alta ou snake_case clara.

## 🎨 Emojis nos Logs de Saída

Feedback visual no terminal para clareza imediata durante a execução:

```bash
echo "==> 🔍 [1/3] Verificando pré-requisitos..."
echo "==> 🚀 [2/3] Executando operação..."
echo "==> ✅ [3/3] Operação concluída com sucesso!"
```

## 🛡️ Linters e Formatadores Obrigatórios (Padrão de Indústria)

Antes de entregar qualquer script, execute o validador do cofre:

```bash
./scripts/lint.sh
```

O script deve passar 100% limpo em:
1. **ShellCheck**: Análise estática estrita para detecção de bugs, variáveis mal expandidas e armadilhas de shell.
2. **shfmt**: Formatação consistente de código (`shfmt -i 2 -ci -bn`).
3. **Gitleaks**: Zero vazamento de credenciais, chaves ou tokens.

---

## 🔗 Fontes
- [ShellCheck Manual](https://www.shellcheck.net/)
- [shfmt Repository](https://github.com/mvdan/sh)
- [Persona Archimedes](../../rules/AGENTS.md)
