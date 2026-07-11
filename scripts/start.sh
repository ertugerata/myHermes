#!/bin/bash

TARGET_PORT=${PORT:-7860}

echo "=== CONFIG DOSYASI DOĞRULANIYOR ==="
# Konteyner ayağa kalkarken dosyanın tam konumunu ekrana basalım (Log takibi için)
if [ -f "$HOME/.config/hermes/config.yaml" ]; then
    echo "✔ config.yaml doğru konumda hazır."
else
    echo "⚠️ config.yaml eksik! Acil durum kopyalaması yapılıyor..."
    mkdir -p "$HOME/.config/hermes"
    cp "$HOME/app/config.yaml" "$HOME/.config/hermes/config.yaml"
fi

echo "=== VERİ GERİ YÜKLEME AŞAMASI ==="
if [ -n "$HF_TOKEN" ] && [ -f "$HOME/app/hermes_backup.tar.gz" ]; then
    echo "Eski yedek açılıyor..."
    tar -xzf "$HOME/app/hermes_backup.tar.gz" -C $HOME/
fi

echo "=== HERMES AGENT BAŞLATILIYOR ==="
echo "Dinlenen Port: $TARGET_PORT"

# Bazı Hermes sürümleri config yolunu çevre değişkeninden okur:
export HERMES_CONFIG_PATH="$HOME/.config/hermes/config.yaml"

# Doğrudan config dosyasını parametre olarak besleyerek (varsa destekleyen sürümlerde) veya default tetikleyerek başlatıyoruz
hermes dashboard --port $TARGET_PORT --host 127.0.0.1 & 
