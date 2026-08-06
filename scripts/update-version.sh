#!/bin/bash
# VERSION.txt dosyasındaki sürümü okur ve Dockerfile içerisindeki ARG HERMES_VERSION değerini günceller.

# Hata durumunda çıkış yap
set -e

# Proje kök dizinini bul
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

VERSION_FILE="$PROJECT_ROOT/VERSION.txt"
DOCKERFILE="$PROJECT_ROOT/Dockerfile"

# Sürüm dosyasının varlığını kontrol et
if [ ! -f "$VERSION_FILE" ]; then
    echo "ERROR: $VERSION_FILE bulunamadı!" >&2
    exit 1
fi

# Sürüm numarasını oku ve boşlukları temizle
VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

if [ -z "$VERSION" ]; then
    echo "ERROR: VERSION.txt boş veya geçersiz!" >&2
    exit 1
fi

echo "Okunan Sürüm: $VERSION"

# Dockerfile dosyasının varlığını kontrol et
if [ ! -f "$DOCKERFILE" ]; then
    echo "ERROR: $DOCKERFILE bulunamadı!" >&2
    exit 1
fi

# Dockerfile içindeki ARG HERMES_VERSION satırını güncelle
# MacOS/Linux uyumluluğu için geçici dosya kullanılabilir veya perl/sed ile yapılabilir.
# Buradaki kalıp: ARG HERMES_VERSION=... -> ARG HERMES_VERSION=VERSION
if grep -q "ARG HERMES_VERSION=" "$DOCKERFILE"; then
    # OS uyumlu sed (özellikle MacOS ile uyumlu olması için yedekli veya perl kullanılabilir)
    # Burada perl kullanarak her iki platformda da sorunsuz çalıştırıyoruz
    perl -pi -e "s/(ARG HERMES_VERSION=).*/\${1}$VERSION/" "$DOCKERFILE"
    echo "SUCCESS: Dockerfile sürümü $VERSION olarak güncellendi."
else
    echo "ERROR: Dockerfile içerisinde 'ARG HERMES_VERSION=' bulunamadı!" >&2
    exit 1
fi
