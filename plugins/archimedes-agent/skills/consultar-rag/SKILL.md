---
name: consultar-rag
description: Busca semântica local com chunking AST e LanceDB via archimedes-rag. Use quando o usuário pedir "buscar código", "achar função", "onde está implementado", "consultar rag" ou quando precisar de contexto cirúrgico de um projeto sem ler arquivos inteiros.
compatibility: opencode
metadata:
  audience: ia-local
  workflow: rag
---

# 🔍 Skill: consultar-rag

## Memória Semântica Local com Chunking AST e LanceDB

O Archimedes V2 utiliza o [`archimedes-rag`](https://github.com/brcesarms/archimedes-rag) para indexar projetos de código via AST e executar buscas semânticas vetoriais ultra-rápidas no LanceDB local, economizando até 95% de tokens de contexto.

## 📂 Localização do Motor

| Item | Caminho |
| :--- | :--- |
| CLI Global | `~/.local/bin/rag` ou `~/.local/bin/opencode-rag` |
| Indexador | `~/.local/bin/opencode-index` |
| Repositório | `~/projetos/archimedes-rag` |
| Cache Vetorial | `~/.cache/opencode_rag/projects/` |

## 📋 Como usar

1. **Consultar Contexto Cirúrgico de um Projeto:**
   ```bash
   rag search "Como está implementado o backup do restic?"
   ```

2. **Listar Todos os Projetos Indexados:**
   ```bash
   rag list-projects
   ```

3. **Reindexar Manualmente um Projeto:**
   ```bash
   rag index /home/brn/archimedes-v2
   ```

4. **Verificar Status e Chunks do Projeto Atual:**
   ```bash
   rag info
   ```

## 🛡️ Diretrizes de Funcionamento
- 🧠 **AST Chunker:** Código Python, shell e markdown são fatiados de forma estruturada, mantendo integridade conceitual.
- 🪝 **Zero-Overhead:** Git Hooks (`post-commit` e `post-merge`) mantêm o índice atualizado automaticamente após modificações no repositório.
- ⚡ **Economia Extrema:** Recupera apenas os trechos estritamente relevantes, evitando poluir o contexto com leituras de arquivos inteiros.

---

## 🔗 Fontes
- [Repositório archimedes-rag](https://github.com/brcesarms/archimedes-rag)
- [Persona Archimedes](../../rules/AGENTS.md)
