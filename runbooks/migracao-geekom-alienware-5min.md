# ⚡ Runbook: Migração GEEKOM → Alienware em 5 Minutos (1-Click)

> **Objetivo:** Mover todo o ecossistema Archimedes V2 (cofre, RAG, LanceDB, projetos, notas, instintos e agentes) da VM GEEKOM (`10.0.0.10`) para o **Alienware** (`10.0.0.208`) em **menos de 5 minutos** usando o script orquestrador automatizado.

---

## 📋 Comando Único de Migração (1-Click)

No terminal do GEEKOM (ou workstation de origem), execute:

```bash
cd ~/archimedes && ./scripts/migrar-alienware.sh alienware
```

Ou execute via `curl` direto do GitHub:

```bash
curl -sL https://raw.githubusercontent.com/brcesarms/linux-toolbox-tui/main/runbooks/migracao-geekom-alienware-5min.md | bash
```

---

## 🚀 Como o Script Reduz a Migração de 1 Dia para < 5 Minutos

| Etapa Anterior (Manual / Lenta) | Nova Abordagem (Automática em < 5min) | Tempo Estimado |
| :--- | :--- | :--- |
| Instalar e compilar pacotes manualmente no destino | Playbook headless via SSH garantindo `python3.12-venv` e `linger` | **20 segundos** |
| `rsync` sem parâmetros de cifra rápida em LAN | `rsync -aHAX --numeric-ids -e "ssh -T -c aes128-gcm@openssh.com -o Compression=no"` | **180 segundos** |
| Re-indexar todo o RAG do zero | Transferência direta do índice LanceDB em `~/.cache/opencode_rag` | **30 segundos** |
| Editar `config.yaml`, `mcp` e `systemd` na mão | `sed` automático ajustando `http://127.0.0.1:8765/mcp` no destino | **5 segundos** |
| Healthcheck manual de serviços | Script executa validação E2E do RAG e systemd ao final | **5 segundos** |

---

## 🔒 Garantias de Segurança

- Cópia **unidirecional** e não destrutiva (a VM GEEKOM permanece 100% intacta).
- Exclusão automática de `node_modules`, `.venv` antigos e pastas pesadas temporárias.
- Chaves SSH e segredos `.env` protegidos durante a transferência.
