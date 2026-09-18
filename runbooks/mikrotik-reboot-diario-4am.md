# 📡 Reboot Diário Automático no MikroTik RouterOS (04:00 AM)

Runbook para agendar a reinicialização automática do roteador MikroTik todos os dias às **04:00 AM**.

---

## ⚡ 1-Liner Via SSH (Executar no Terminal do MikroTik)

Conecte no seu MikroTik via SSH ou Terminal do WinBox e cole o comando abaixo:

```routeros
/system scheduler add name="reboot-diario-4am" start-time=04:00:00 interval=1d on-event="/system reboot" comment="Reboot diario automatico as 04:00 AM criado via Archimedes Runbook"
```

---

## 📋 Passos Detalhados (Terminal SSH / WinBox Terminal)

### 1. Validar e Ajustar o Relógio & Timezone do MikroTik
Antes de agendar, garanta que o fuso horário do roteador esteja correto (Ariquemes/RO = UTC-4 / `America/Porto_Velho` ou GMT-4):

```routeros
/system clock set time-zone-name=America/Porto_Velho
/system clock print
```

### 2. Criar o Agendamento no Scheduler
```routeros
/system scheduler add name="reboot-diario-4am" start-time=04:00:00 interval=1d on-event="/system reboot" comment="Reboot diario automatico as 04:00 AM"
```

### 3. Verificar o Agendamento Criado
```routeros
/system scheduler print detail where name="reboot-diario-4am"
```

---

## 🖱️ Alternativa via WinBox (Interface Gráfica)

1. Acesse o **WinBox** e conecte no MikroTik.
2. No menu lateral, acesse **System** ➔ **Scheduler**.
3. Clique no botão **`+`** (Add).
4. Preencha os campos:
   * **Name:** `reboot-diario-4am`
   * **Start Time:** `04:00:00`
   * **Interval:** `1d 00:00:00` (ou `1d`)
   * **On Event:** `/system reboot`
   * **Comment:** `Reboot diario automatico as 04:00 AM`
5. Clique em **OK** ou **Apply**.

---

## 🔒 Validação de Segurança & Remoção

Caso precise remover o agendamento no futuro:

```routeros
/system scheduler remove [find name="reboot-diario-4am"]
```
