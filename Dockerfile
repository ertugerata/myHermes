ARG HERMES_VERSION=v2026.7.20
FROM nousresearch/hermes-agent:${HERMES_VERSION}

USER root

# Gerekli ek derleme paketlerini kuruyoruz (gereksiz paketler ve tekrarlar temizlendi)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face Spaces için "user" kullanıcısını tanımlayalım.
RUN useradd -m -u 1000 user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:/opt/hermes/bin:/opt/hermes/.venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Çalışma dizinini ayarlıyoruz
WORKDIR $HOME/app

RUN chown -R user:user $HOME

# Bağımlılıkları resmi imajın virtual environment'ı içerisine root olarak kuruyoruz.
# İmajda varsayılan olarak pip bulunmadığından önce ensurepip ile kuruyoruz.
COPY requirements.txt .
RUN /opt/hermes/.venv/bin/python -m ensurepip && \
    /opt/hermes/.venv/bin/python -m pip install --no-cache-dir --upgrade pip && \
    /opt/hermes/.venv/bin/pip install --no-cache-dir -r requirements.txt

# Kullanıcıya geçip kalan dosyaları kopyalıyoruz
USER user
COPY --chown=user:user . .

# Konfigürasyonu hazırlayalım
RUN mkdir -p $HOME/.config/hermes && \
    cp config.yaml $HOME/.config/hermes/config.yaml

RUN mkdir -p $HOME/.hermes && \
    cp config.yaml $HOME/.hermes/config.yaml

RUN chmod +x scripts/start.sh scripts/dns-resolve.py scripts/setup-wizard.sh 2>/dev/null || true

# Resmi imajın ENTRYPOINT'ini override etmeliyiz (s6-overlay'in yetki hatalarını Hugging Face üzerinde engellemek için)
ENTRYPOINT []

CMD ["./scripts/start.sh"]
