FROM python:3.11-slim

# NOT: build-essential / python3-dev / libffi-dev'i burada, root iken kuruyoruz.
# Böylece aşağıdaki hermes install.sh, derleyici/başlık dosyalarını zaten kurulu
# bulup "sudo apt install build-essential..." adımını atlar — 'sudo' paketine
# ve şifresiz sudo (NOPASSWD) ayarına hiç ihtiyaç kalmaz (önceki build logunda
# "sudo: a password is required" hatasının sebebi buydu).
RUN apt-get update && apt-get install -y \
    git \
    curl \
    tar \
    xz-utils \
    build-essential \
    python3-dev \
    libffi-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

RUN chown -R user:user $HOME
USER user

# pipefail: curl başarısız olursa build de kırılsın (silent-success riskini azaltır)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# UYARI: Bu adım her build'de o an main branch'te ne varsa onu çekip çalıştırıyor
# (reproducible değil + tedarik zinciri riski). Mümkünse resmi, versiyonu
# pinlenmiş bir Nous Research image'ına geçmeyi değerlendir:
#   https://hermes-agent.nousresearch.com/docs/user-guide/docker/
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --skip-browser

# Bağımlılıkları kuruyoruz
COPY --chown=user:user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Proje dosyalarını kopyala
COPY --chown=user:user . .

# NOT: config.yaml'ı ~/.hermes ve ~/.config/hermes'e kopyalama işi artık burada
# YAPILMIYOR — start.sh bunu her container başlangıcında, auth (kullanıcı adı/
# parola hash'i) bilgisini config'e işledikten SONRA yapıyor. Build-time'da
# kopyalamak sadece runtime'da hemen üzerine yazılacak, işe yaramayan bir
# kopya bırakıyordu (kod tekrarı).

RUN chmod +x scripts/start.sh scripts/dns-resolve.py

# HF Spaces docker SDK varsayılan olarak 7860 portunu bekler.
# start.sh içindeki servis bu portta dinlemiyorsa Space "unhealthy" görünür.
EXPOSE 7860

CMD ["./scripts/start.sh"]
