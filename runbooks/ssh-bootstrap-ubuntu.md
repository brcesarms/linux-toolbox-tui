# 🔑 Bootstrap SSH — Ubuntu recém-instalado

> **Objetivo:** autorizar a chave pública SSH do seu workstation e ativar o servidor SSH em uma máquina Ubuntu 24.04 recém-formatada, para acessá-la por nome (`ssh alienware`) em vez de IP.

---

## 📋 Passo 1 — Colar no terminal da máquina nova (1 comando)

Abra o terminal no Ubuntu recém-instalado e cole:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiS0LKTWLy0WVbY7O515TKpR9yxxDrJjXH0c3zcWELZ' >> ~/.ssh/authorized_keys && \
chmod 600 ~/.ssh/authorized_keys && \
sudo systemctl enable --now ssh && \
echo '✅ Chave SSH instalada e servidor SSH ativo!'
```

O que esse comando faz:
| Comando | Efeito |
| :--- | :--- |
| `mkdir -p ~/.ssh && chmod 700` | cria a pasta `~/.ssh` com permissão só do dono |
| `echo ... >> ~/.ssh/authorized_keys` | adiciona a chave pública do workstation |
| `chmod 600` | permissão correta do `authorized_keys` |
| `systemctl enable --now ssh` | instala/ativa o `openssh-server` e habilita no boot |

> 💡 Se aparecer `Failed to enable unit` (pacote não instalado), rode antes: `sudo apt update && sudo apt install -y openssh-server` e repita o `systemctl`.

---

## ✅ Passo 2 — Testar do workstation

```bash
ssh alienware
```

> ⚠️ Na **primeira** conexão aparecerá o aviso de host key — digite `yes` para confiar na máquina.

---

## 🧰 Bônus (opcional)

### Acesso por nome `alienware` sem depender de IP

1. No workstation, garanta que `~/.ssh/config` tenha o bloco:

```text
Host alienware
    HostName <IP_DA_MAQUINA>
    User brn
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

2. Na máquina nova, habilite mDNS para conectar por `alienware.local` (opção `R2` do linux-toolbox):

```bash
sudo ~/linux-toolbox.sh R2   # ou: sudo ./linux-toolbox.sh R2
```

### Liberar porta 22 no firewall (se UFW ativo)

```bash
sudo ufw allow 22/tcp && sudo ufw enable
```

---

## 🔒 Segurança

- A chave pública pode ser distribuída com segurança (só a **privada** `~/.ssh/id_ed25519` dá acesso — nunca compartilhe).
- Para adicionar outras máquinas, basta trocar a linha `echo '...'` pela chave pública da nova máquina (`cat ~/.ssh/id_ed25519.pub` no workstation de origem).