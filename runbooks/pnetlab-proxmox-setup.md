# 🖥️ Runbook: Instalação e Configuração do PNETLab no Proxmox VE

> **Alvo:** Servidor Proxmox VE  
> **Objetivo:** Importar a imagem OVA do PNETLab v4, criar a VM com aceleração KVM (`cpu host`), realizar upgrade para a v5 estável e adicionar nós de rede (ex: MikroTik CHR).

---

## 📋 Passo 1 — Execução Automática no Shell do Proxmox VE (1 Bloco)

Envie o arquivo `PNETLAB.ova` para a pasta `/var/lib/vz/template/iso/` ou `/tmp/` no Proxmox e execute o comando abaixo no terminal do Proxmox VE:

```bash
bash -c '
set -euo pipefail

VMID=${1:-100}
STORAGE=${2:-local-lvm}
MEMORY=${MEMORY:-8192}
CORES=${CORES:-4}
BRIDGE=${BRIDGE:-vmbr0}

echo "🏛️ [PNETLab Setup] Criando VM ${VMID} no Proxmox VE..."

# 1. Localizar ou extrair o OVA
OVA_FILE=$(find /tmp /var/lib/vz/template/iso . -name "PNETLAB.ova" 2>/dev/null | head -n 1 || true)
if [[ -n "${OVA_FILE}" ]]; then
    echo "📦 Extraindo arquivo OVA (${OVA_FILE})..."
    tar -xvf "${OVA_FILE}"
else
    echo "⚠️ PNETLAB.ova não encontrado em /tmp ou /var/lib/vz/template/iso."
    echo "   Certifique-se de que o disco .vmdk ou .qcow2 está no diretório atual."
fi

DISK_FILE=$(find . -maxdepth 1 \( -name "*.vmdk" -o -name "*.qcow2" \) | head -n 1 || true)
if [[ -z "${DISK_FILE}" ]]; then
    echo "❌ Erro: Nenhum arquivo de disco (.vmdk / .qcow2) encontrado."
    exit 1
fi
DISK_FILE="${DISK_FILE#./}"

# 2. Criar VM no Proxmox
qm create "${VMID}" --name "PNETLAB-v4" --memory "${MEMORY}" --cores "${CORES}" --sockets 1 --cpu host --net0 "virtio,bridge=${BRIDGE}"
qm importdisk "${VMID}" "${DISK_FILE}" "${STORAGE}" --format qcow2
qm set "${VMID}" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${VMID}-disk-0"
qm set "${VMID}" --boot order=scsi0
qm start "${VMID}"

echo "✅ VM ${VMID} (PNETLab) criada e inicializada com sucesso!"
' _ 100 local-lvm
```

---

## 🧰 Parâmetros do Script

| Parâmetro | Padrão | Descrição |
| :--- | :--- | :--- |
| `VMID` | `100` | ID único da VM no Proxmox VE |
| `STORAGE` | `local-lvm` | Storage de destino do disco virtual |
| `MEMORY` | `8192` (8GB) | Memória RAM alocada para a VM |
| `CORES` | `4` | Número de núcleos de CPU alocados |
| `BRIDGE` | `vmbr0` | Interface de rede bridge do Proxmox |

---

## 🔑 Credenciais Padrão

- **Console / SSH:**  
  - **Usuário:** `root`  
  - **Senha:** `pnet`  

- **Interface Web (`http://<IP_DA_VM>`):**  
  - **Modo:** Offline  
  - **Usuário:** `admin`  
  - **Senha:** `pnet`  

---

## ⚡ Passo 2 — Pós-Instalação no Terminal do PNETLab

Ao logar no console da VM (`root`/`pnet`), execute:

```bash
# 1. Validar suporte à virtualização KVM (Mandatório)
kvm-ok
# Resultado esperado: "KVM acceleration can be used"

# 2. Atualizar o PNETLab para a versão 5 (Versão Estável)
pnetlab-update
```

---

## 🌐 Passo 3 — Adicionando Nós de Rede (Exemplo: MikroTik CHR v7.13.4)

Execute no terminal SSH da VM **PNETLab**:

```bash
mkdir -p /opt/unetlab/addons/qemu/mikrotik-7.13.4 && \
cd /opt/unetlab/addons/qemu/mikrotik-7.13.4 && \
wget https://download.mikrotik.com/routeros/7.13.4/chr-7.13.4.img.zip && \
unzip chr-7.13.4.img.zip && \
mv chr-7.13.4.img hda.qcow2 && \
rm chr-7.13.4.img.zip && \
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
```

---

## 🔒 Segurança & Boas Práticas

1. **Senha Root & Web:** Altere a senha padrão do `root` no primeiro acesso e a senha do `admin` na Web UI (*System > Change Password*).
2. **Virtualização Aninhada:** Garanta que a flag `--cpu host` seja mantida no Proxmox para que os nós QEMU funcionem com aceleração de hardware.
3. **Rede:** A VM do PNETLab deve estar conectada a uma bridge com acesso à internet para downloads de atualizações e imagens.
