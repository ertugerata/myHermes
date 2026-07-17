#!/bin/bash

# GitHub Backup and Restore Script for Hermes Agent
# This script handles backing up ~/.hermes and config.yaml to a GitHub repository.

REPO_URL="${GITHUB_BACKUP_REPO}"
GIT_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
BACKUP_GIT_DIR="$HOME/hermes_backup_git"

if [ -z "$REPO_URL" ]; then
    echo "❌ HATA: GITHUB_BACKUP_REPO çevre değişkeni tanımlı değil."
    echo "Lütfen GITHUB_BACKUP_REPO ve GITHUB_TOKEN değişkenlerini ayarlayın."
    exit 1
fi

do_git_backup() {
    if [ ! -d "$BACKUP_GIT_DIR" ]; then
        echo "Yedek deposu bulunamadı. Önce 'restore' komutuyla klonlayın."
        return 1
    fi

    echo "Yedek dosyaları hazırlanıyor..."
    mkdir -p "$BACKUP_GIT_DIR/.hermes"
    cp -rf "$HOME/.hermes/"* "$BACKUP_GIT_DIR/.hermes/" 2>/dev/null || true

    # Remove large binary directories to stay within GitHub file size limits
    rm -rf "$BACKUP_GIT_DIR/.hermes/bin"
    rm -rf "$BACKUP_GIT_DIR/.hermes/node"
    rm -rf "$BACKUP_GIT_DIR/.hermes/hermes-agent"
    rm -rf "$BACKUP_GIT_DIR/.hermes/venv"
    rm -rf "$BACKUP_GIT_DIR/.hermes/node_modules"

    if [ -f "$HOME/app/config.yaml" ]; then
        cp -f "$HOME/app/config.yaml" "$BACKUP_GIT_DIR/config.yaml"
    fi

    cd "$BACKUP_GIT_DIR" || return 1
    git config user.name "Hermes Backup Bot"
    git config user.email "hermes-backup-bot@users.noreply.github.com"

    cat << 'EOF' > .gitignore
# Large binary runtimes and environments
.hermes/bin/
.hermes/node/
.hermes/hermes-agent/
.hermes/venv/
.hermes/node_modules/
*.log
*.tmp
*.lock
EOF

    git rm -r --cached .hermes/bin .hermes/node .hermes/hermes-agent .hermes/venv .hermes/node_modules 2>/dev/null || true
    git add .

    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "Yeni değişiklikler algılandı. Yedek commit ediliyor..."
        git commit -m "Automated backup: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ] && CURRENT_BRANCH="main"
        
        echo "Yedek GitHub'a yükleniyor ($CURRENT_BRANCH)..."
        timeout 90 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
            push origin "$CURRENT_BRANCH" > /tmp/git_push.log 2>&1
        if [ $? -eq 0 ]; then
            echo "✔ Yedek başarıyla GitHub deposuna gönderildi."
        else
            echo "❌ HATA: Yedek GitHub'a gönderilemedi."
            [ -n "$GIT_TOKEN" ] && sed "s/$GIT_TOKEN/[MASKED_TOKEN]/g" /tmp/git_push.log || cat /tmp/git_push.log
        fi
        rm -f /tmp/git_push.log
    else
        echo "Yedeklemede yeni değişiklik yok."
    fi
    cd "$HOME/app" || return 1
}

do_git_restore() {
    echo "=== VERİ GERİ YÜKLEME AŞAMASI (GITHUB BACKUP) ==="
    AUTH_REPO_URL="$REPO_URL"
    if [ -n "$GIT_TOKEN" ]; then
        CLEAN_URL="${REPO_URL#https://}"
        AUTH_REPO_URL="https://***@${CLEAN_URL}"
    fi

    rm -rf "$BACKUP_GIT_DIR"
    echo "Yedek deposu klonlanıyor..."
    timeout 90 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
        clone --depth 1 --single-branch "$AUTH_REPO_URL" "$BACKUP_GIT_DIR" > /tmp/git_clone.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✔ Yedek deposu başarıyla klonlandı."
        if [ -d "$BACKUP_GIT_DIR/.hermes" ]; then
            mkdir -p "$HOME/.hermes"
            cp -rf "$BACKUP_GIT_DIR/.hermes/"* "$HOME/.hermes/" 2>/dev/null || true
            echo "✔ .hermes geri yüklendi."
        fi
        if [ -f "$BACKUP_GIT_DIR/config.yaml" ]; then
            cp -f "$BACKUP_GIT_DIR/config.yaml" "$HOME/app/config.yaml"
            echo "✔ config.yaml geri yüklendi."
        fi
    else
        echo "❌ HATA: Yedek deposu klonlanamadı."
        [ -n "$GIT_TOKEN" ] && sed "s/$GIT_TOKEN/[MASKED_TOKEN]/g" /tmp/git_clone.log || cat /tmp/git_clone.log
    fi
    rm -f /tmp/git_clone.log
}

case "$1" in
    backup)
        do_git_backup
        ;;
    restore)
        do_git_restore
        ;;
    *)
        echo "Kullanım: $0 {backup|restore}"
        exit 1
        ;;
esac
