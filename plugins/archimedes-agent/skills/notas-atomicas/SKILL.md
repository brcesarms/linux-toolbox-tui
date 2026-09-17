---
name: notas-atomicas
description: Criação e edição de notas no estilo do Archimedes. Use quando for criar, editar ou organizar notas markdown — aplica notas atômicas, emojis, links markdown relativos e seção de fontes. Dispara ao ouvir "criar nota", "anotar", "resumo", "to-do notes" e nomes como "nota atômica".
metadata:
  audience: ia-local
  workflow: notas
---

# 🗒️ Notas Atômicas do Archimedes V2

Este cofre segue regras estritas de clareza, modularidade e rastreabilidade na escrita de notas técnicas.

## 📍 Onde salvar cada nota

- **Documentação do sistema e runbooks** → `docs/` (`docs/runbooks/`, `docs/perfis/`, `docs/benchmarks/`)
- **Estudos de TI** → `~/wikisidian/t.i/` (repositório privado do usuário)
- **Concursos** → `~/wikisidian/concurseiro/` (repositório privado do usuário)
- ⚠️ Sempre separe documentação de sistema de notas de estudo pessoal.

## ⚛️ Princípio da Nota Atômica

Cada nota deve tratar de **um único assunto, conceito ou procedimento operacional**, de forma focada e direta.

- ❌ Não misturar múltiplos tópicos heterogêneos em uma única nota
- ✅ Uma nota = uma responsabilidade clara e objetiva

## 📌 Regras de Nomenclatura

| Elemento | Regra | Exemplo |
|---|---|---|
| **Título (H1)** | Objetivo e descritivo, com emoji representativo | `# 🐳 Docker Básico` |
| **Nome do arquivo** | `kebab-case.md`, minúsculas, sem acentos, **sem emojis** | `docker-basico.md` |
| **Conexões** | Notas nunca ficam isoladas (órfãs) — conecte com notas correlatas | Links relativos |

## 🔗 Formato de Links (Validado via Lychee)

- ❌ **Proibido**: Wikilinks estilo Obsidian `[[Nome da Nota]]`
- ✅ **Obrigatório**: Links Markdown padrão com caminhos relativos navegáveis:
  - Mesmo diretório: `[Nome da Nota](./nome-da-nota.md)`
  - Diretório pai ou irmão: `[Perfil Alienware](../perfis/alienware.md)`
  - Raiz do cofre: `[Manual AGENTS](../../../AGENTS.md)`

## 🎨 Uso de Emojis Contextuais

- Títulos H1 sempre com emoji contextual: `# 🐧 Instalação do Linux`
- Cabeçalhos de seção H2/H3: `## 📦 Pacotes`, `## ⚠️ Pontos de Atenção`
- Listas de status: `- ✅ Concluído`, `- ⏳ Em andamento`, `- ❌ Falha`

## 📚 Seção Obrigatória de Fontes

Toda nota técnica deve ser finalizada com uma seção `## 🔗 Fontes`:

```markdown
---

## 🔗 Fontes
- [Documentação Oficial](https://docs.github.com/en/get-started/writing-on-github)
- [AGENTS.md](../../../AGENTS.md)
```

## ✅ Checklist antes de salvar

1. [ ] Nome do arquivo em `kebab-case.md` (sem espaços, acentos ou emojis)
2. [ ] H1 com emoji representativo
3. [ ] Um único conceito central
4. [ ] Links markdown relativos válidos (compatíveis com verificação do Lychee)
5. [ ] Seção `## 🔗 Fontes` no encerramento

## 🔗 Fontes
- [Persona Archimedes](../../rules/AGENTS.md)