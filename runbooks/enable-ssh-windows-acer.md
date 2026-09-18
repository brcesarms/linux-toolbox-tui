# 🔌 Ativar Servidor SSH no Windows (ACER / laptop-brn)

Runbook para ativar o serviço **OpenSSH Server** no Windows (`acer-brn` — `10.0.0.215`) para permitir acesso SSH e sincronização autônoma do Hermes.

---

### 🚀 Comando Único para Ativar o SSH (Executar no PowerShell como Administrador):

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType 'Automatic'; New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
```

---

### 🔐 O que este comando faz:
1. Instala o recurso **OpenSSH.Server** no Windows se ainda não estiver instalado.
2. Inicia o serviço **sshd**.
3. Configura a inicialização automática do serviço **sshd** com o sistema.
4. Libera a porta **22** no Firewall do Windows.
