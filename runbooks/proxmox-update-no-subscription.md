# 🖥️ Runbook: Configurar Repositório Sem Assinatura e Atualizar Proxmox VE 9

> **Alvo:** Host Proxmox VE (`root@10.0.0.3`)  
> **Objetivo:** Ativar o repositório da comunidade (`pve-no-subscription`), desativar avisos de repositório pago e atualizar o Proxmox VE 9 (Debian Trixie) via SSH.

---

## 📋 Comando Único de Execução (Copiável / Idempotente)

```bash
ssh root@10.0.0.3 bash -s << 'EOF'
set -euo pipefail

echo "🔍 Desativando repositórios pagos enterprise (.sources)..."
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled 2>/dev/null || true
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled 2>/dev/null || true
rm -f /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-no-subscription.list

echo "🌐 Habilitando repositório da comunidade (pve-no-subscription)..."
cat << 'REPO' > /etc/apt/sources.list.d/pve-no-subscription.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
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
