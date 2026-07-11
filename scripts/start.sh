#!/bin/bash

TARGET_PORT=${PORT:-7860}

echo "=== CONFIG DOSYASI DOĞRULANIYOR ==="
# Konteyner ayağa kalkarken dosyanın tam konumunu ekrana basalım (Log takibi için)
mkdir -p "$HOME/.config/hermes"
cp "$HOME/app/config.yaml" "$HOME/.config/hermes/config.yaml"

# Hermes default path matches HERMES_HOME (~/.hermes). Let's copy it there.
mkdir -p "$HOME/.hermes"
cp "$HOME/app/config.yaml" "$HOME/.hermes/config.yaml"
echo "✔ config.yaml doğru konumlarda (hem ~/.hermes/ hem de ~/.config/hermes/) hazır."

echo "=== VERİ GERİ YÜKLEME AŞAMASI ==="
if [ -n "$HF_TOKEN" ] && [ -f "$HOME/app/hermes_backup.tar.gz" ]; then
    echo "Eski yedek açılıyor..."
    tar -xzf "$HOME/app/hermes_backup.tar.gz" -C "$HOME/"
fi

echo "=== HERMES AGENT BAŞLATILIYOR ==="
echo "Dinlenen Port: $TARGET_PORT"

# Bazı Hermes sürümleri config yolunu çevre değişkeninden okur:
export HERMES_CONFIG_PATH="$HOME/.hermes/config.yaml"

# Hugging Face Spaces üzerinde çalışabilmesi için:
# 1. Host 0.0.0.0 olmalı (dışarıdan erişim için).
# 2. Arka planda değil (&), ön planda çalışmalı (konteynerin kapanmaması için).
# 3. 'exec' kullanarak sinyal yönetimini kolaylaştırıyoruz.
exec hermes dashboard --port "$TARGET_PORT" --host 0.0.0.0
