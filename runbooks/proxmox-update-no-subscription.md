# 🖥️ Runbook: Configurar Repositório Sem Assinatura e Atualizar Proxmox VE

> **Alvo:** Host Proxmox VE (`root@10.0.0.3`)  
> **Objetivo:** Ativar o repositório da comunidade (`pve-no-subscription`), desativar avisos de repositório pago e atualizar o sistema com segurança.

---

## 📋 Comando Único de Execução (Copiável / Idempotente)

```bash
ssh root@10.0.0.3 bash -s << 'EOF'
set -euo pipefail

echo "🔍 Desativando repositórios pagos enterprise..."
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list 2>/dev/null || true

echo "🌐 Habilitando repositório da comunidade (pve-no-subscription)..."
cat << 'REPO' > /etc/apt/sources.list.d/pve-no-subscription.list
# Proxmox VE No-Subscription Repository (Comunidade)
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
REPO

echo "🔄 Atualizando lista de pacotes e aplicando atualizações..."
apt-get update
apt-get dist-upgrade -y

echo "🧹 Removendo banner de aviso de assinatura na Web UI..."
if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
  sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
  systemctl restart pveproxy.service || true
fi

echo "✅ Proxmox VE atualizado com sucesso!"
pveversion
EOF
```

---

## 🔒 Validação Pós-Execução

- **Versão:** `pveversion`
- **Serviço Web:** `systemctl status pveproxy.service`
