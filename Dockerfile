ARG HERMES_VERSION=v2026.8.3
FROM nousresearch/hermes-agent:${HERMES_VERSION}

USER root

# Gerekli ek derleme paketlerini kuruyoruz ve supervisor, curl, ca-certificates ekliyoruz
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libffi-dev \
    supervisor \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ttyd kurulumu
RUN curl -sL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# Hugging Face Spaces için "user" kullanıcısını tanımlayalım.
RUN useradd -m -u 1000 user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Supervisor log/run dizinlerini oluşturup yetkilendiriyoruz
RUN mkdir -p /var/log/supervisor /var/run/supervisor && \
    chown -R user:user /var/log/supervisor /var/run/supervisor

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:/opt/hermes/bin:/opt/hermes/.venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TERM=xterm-256color \
    HERMES_HOME=/home/user/.hermes \
    HERMES_WRITE_SAFE_ROOT=/home/user/.hermes \
    HERMES_LAZY_INSTALL_TARGET=/home/user/.hermes/lazy-packages \
    CONFIG_SRC=/home/user/app/config.yaml \
    NODE_OPTIONS="--require /home/user/app/scripts/dns-fix.cjs" \
    PYTHONPATH=/home/user/app/scripts

# Çalışma dizinini ayarlıyoruz
WORKDIR $HOME/app

RUN chown -R user:user $HOME

# Bağımlılıkları resmi imajın virtual environment'ı içerisine root olarak kuruyoruz.
# İmajda varsayılan olarak pip bulunmadığından önce ensurepip ile kuruyoruz.
COPY requirements.txt .
RUN /opt/hermes/.venv/bin/python -m ensurepip && \
    /opt/hermes/.venv/bin/python -m pip install --no-cache-dir --upgrade pip && \
    /opt/hermes/.venv/bin/pip install --no-cache-dir -r requirements.txt

# supervisord.conf dosyasını kopyalıyoruz
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Kullanıcıya geçip kalan dosyaları kopyalıyoruz
USER user
COPY --chown=user:user . .

# Konfigürasyonu hazırlayalım
RUN mkdir -p $HOME/.config/hermes && \
    cp config.yaml $HOME/.config/hermes/config.yaml

RUN mkdir -p $HOME/.hermes && \
    cp config.yaml $HOME/.hermes/config.yaml

RUN chmod +x scripts/start.sh scripts/dns-resolve.py scripts/setup-wizard.sh 2>/dev/null || true

EXPOSE 7860 7681

# Giriş noktasını supervisord olarak ayarlıyoruz
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
