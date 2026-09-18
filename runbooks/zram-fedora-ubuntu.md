# ⚡ Ativar zRAM Estilo Fedora Linux no Ubuntu (zstd + swappiness 180)

Runbook para substituir o swap em disco tradicional por **zRAM compactada na memória RAM (algoritmo zstd, 100% do tamanho da RAM, swappiness 180)**, exatamente a arquitetura padrão ouro do **Fedora Linux**.

---

### 🚀 Comando Único para Ativar no Ubuntu:

```bash
sudo apt update && sudo apt install -y systemd-zram-generator && \
sudo tee /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF
sudo tee /etc/sysctl.d/99-zram-fedora.conf << 'EOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
sudo swapoff -a && \
sudo sed -i '/\/swap.img/d' /etc/fstab && \
sudo systemctl daemon-reload && \
sudo systemctl start systemd-zram-setup@zram0.service && \
sudo sysctl --system && \
echo "✅ zRAM Fedora ativada com sucesso!"
```

---

### 📊 O que este ajuste faz:
1. **Instala o `systemd-zram-generator`**: O mesmo utilitário oficial do projeto Fedora.
2. **Algoritmo `zstd`**: Alta taxa de compressão e desempenho.
3. **Tamanho = 100% da RAM**: Reserva até 100% do tamanho da RAM física compactada em tempo real (para os 12GB do ACER, gera ~12GB de Swap zRAM ultrarrápido).
4. **Tuning `swappiness = 180`**: Padrão do Fedora desde o Fedora 35 — incentiva o kernel a mover dados ociosos para a zRAM sem tocar no disco SSD.
5. **Zero Desgaste de SSD**: Desativa o `/swap.img` lento do Ubuntu.
