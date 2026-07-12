FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    git \
    curl \
    tar \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

RUN chown -R user:user $HOME
USER user

RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --skip-browser

# Bağımlılıkları kuruyoruz
COPY --chown=user:user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Proje dosyalarını kopyala
COPY --chown=user:user . .

# --- YENİ BÖLÜM: DERLEME ESNASINDA AUTH AYARI ---
# Hem kullanıcı dizinine hem de alternatif arama yollarına config'i gömüyoruz
RUN mkdir -p $HOME/.config/hermes && \
    cp config.yaml $HOME/.config/hermes/config.yaml

RUN mkdir -p $HOME/.hermes && \
    cp config.yaml $HOME/.hermes/config.yaml

RUN chmod +x scripts/start.sh scripts/dns-resolve.py

CMD ["./scripts/start.sh"]
