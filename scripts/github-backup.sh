#!/bin/bash

# GitHub Backup and Restore Script for Hermes Agent
# This script handles backing up ~/.hermes and config.yaml to a GitHub repository.

REPO_URL="${GITHUB_BACKUP_REPO:-$BACKUP_REPO}"
GIT_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
BACKUP_GIT_DIR="$HOME/hermes_backup_git"

write_user_log() {
    local STATUS="$1"
    local MSG="$2"
    local TIMESTAMP=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
    echo "[$TIMESTAMP] [$STATUS] $MSG"
    mkdir -p "$HOME/app"
    echo "[$TIMESTAMP] [$STATUS] $MSG" >> "$HOME/app/backup.log"
}

# Safe tar.gz backup extraction helper to protect the app/ directory from being overwritten
safe_extract_tar_backup() {
    local TAR_FILE="$1"
    if [ -f "$TAR_FILE" ]; then
        write_user_log "INFO" "Yedek dosyası güvenli şekilde açılıyor: $TAR_FILE"
        local TMP_DIR="/tmp/hermes_restore_tar"
        rm -rf "$TMP_DIR"
        mkdir -p "$TMP_DIR"

        # Extract the tarball to the temp directory
        tar -xzf "$TAR_FILE" -C "$TMP_DIR" 2>/dev/null || true

        # Restore .hermes if it exists in the extracted files
        if [ -d "$TMP_DIR/.hermes" ]; then
            write_user_log "INFO" "Yedek .hermes verileri geri yükleniyor..."
            mkdir -p "$HOME/.hermes"
            cp -rf "$TMP_DIR/.hermes/"* "$HOME/.hermes/" 2>/dev/null || true
        fi

        # Restore config.yaml if it exists in the extracted files
        if [ -f "$TMP_DIR/config.yaml" ]; then
            write_user_log "INFO" "Yedek config.yaml geri yükleniyor..."
            cp -f "$TMP_DIR/config.yaml" "$HOME/app/config.yaml"
        elif [ -f "$TMP_DIR/app/config.yaml" ]; then
            write_user_log "INFO" "Yedek config.yaml geri yükleniyor (app dizininden)..."
            cp -f "$TMP_DIR/app/config.yaml" "$HOME/app/config.yaml"
        fi

        # Clean up temp directory
        rm -rf "$TMP_DIR"
        write_user_log "SUCCESS" "Yedek başarıyla açıldı, app dizini korundu."
    fi
}

do_git_backup() {
    if [ -z "$REPO_URL" ]; then
        write_user_log "WARNING" "Yedekleme işlemi atlandı: GITHUB_BACKUP_REPO tanımlı değil."
        return 0
    fi

    if [ ! -d "$BACKUP_GIT_DIR" ]; then
        write_user_log "WARNING" "Yedek deposu dizini ($BACKUP_GIT_DIR) bulunamadı. Önce geri yükleme (restore) yapılarak klonlanmalı veya ilk kurulum yapılmalı."
        # If REPO_URL is defined, let's try to clone/initialize it first to make it extremely resilient!
        do_git_restore
        if [ ! -d "$BACKUP_GIT_DIR" ]; then
            write_user_log "ERROR" "Yedek deposu otomatik olarak klonlanamadı. Yedekleme iptal ediliyor."
            return 1
        fi
    fi

    write_user_log "INFO" "Yedek dosyaları hazırlanıyor..."
    mkdir -p "$BACKUP_GIT_DIR/.hermes"

    # Copy everything in ~/.hermes except lock files/sockets
    cp -rf "$HOME/.hermes/"* "$BACKUP_GIT_DIR/.hermes/" 2>/dev/null || true

    # Remove large binary directories to stay within GitHub file size limits
    rm -rf "$BACKUP_GIT_DIR/.hermes/bin"
    rm -rf "$BACKUP_GIT_DIR/.hermes/node"
    rm -rf "$BACKUP_GIT_DIR/.hermes/hermes-agent"
    rm -rf "$BACKUP_GIT_DIR/.hermes/venv"
    rm -rf "$BACKUP_GIT_DIR/.hermes/node_modules"

    # Sync config.yaml if it exists
    if [ -f "$HOME/app/config.yaml" ]; then
        cp -f "$HOME/app/config.yaml" "$BACKUP_GIT_DIR/config.yaml"
    fi

    # Sync user backup.log to the repository so the history persists
    if [ -f "$HOME/app/backup.log" ]; then
        cp -f "$HOME/app/backup.log" "$BACKUP_GIT_DIR/backup.log"
    fi

    cd "$BACKUP_GIT_DIR" || return 1
    git config user.name "Hermes Backup Bot"
    git config user.email "hermes-backup-bot@users.noreply.github.com"

    # Ensure .gitignore exists inside the repo to ignore large binaries
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

    # Untrack any accidentally tracked large files/directories
    git rm -r --cached .hermes/bin .hermes/node .hermes/hermes-agent .hermes/venv .hermes/node_modules 2>/dev/null || true
    git add .

    # Check if there are changes to commit
    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        write_user_log "INFO" "Yeni değişiklikler algılandı. Yedek commit ediliyor..."
        git commit -m "Automated backup: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
            CURRENT_BRANCH="main"
            git checkout -b main 2>/dev/null || true
        fi
        
        write_user_log "INFO" "Yedek GitHub'a yükleniyor ($CURRENT_BRANCH)..."
        timeout 90 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
            push origin "$CURRENT_BRANCH" > /tmp/git_push.log 2>&1
        PUSH_STATUS=$?
        if [ $PUSH_STATUS -eq 0 ]; then
            write_user_log "SUCCESS" "Yedek başarıyla GitHub deposuna gönderildi."
        elif [ $PUSH_STATUS -eq 124 ]; then
            write_user_log "ERROR" "Yedek gönderimi zaman aşımına uğradı (90sn), atlanıyor."
        else
            write_user_log "ERROR" "Yedek GitHub'a gönderilemedi."
            if [ -n "$GIT_TOKEN" ]; then
                # Mask token in error log printed to stdout
                sed "s/$GIT_TOKEN/[MASKED_TOKEN]/g" /tmp/git_push.log
            else
                cat /tmp/git_push.log
            fi
        fi
        rm -f /tmp/git_push.log
    else
        write_user_log "SUCCESS" "Yedeklemede yeni değişiklik yok."
    fi
    cd "$HOME/app" || return 1
}

do_git_restore() {
    write_user_log "INFO" "=== VERİ GERİ YÜKLEME AŞAMASI (GITHUB BACKUP) ==="
    if [ -z "$REPO_URL" ]; then
        write_user_log "WARNING" "GITHUB_BACKUP_REPO tanımlı değil. GitHub yedekleme geri yüklemesi atlanıyor."
        if [ -n "$HF_TOKEN" ] && [ -f "$HOME/app/hermes_backup.tar.gz" ]; then
            safe_extract_tar_backup "$HOME/app/hermes_backup.tar.gz"
        fi
        return 0
    fi

    AUTH_REPO_URL="$REPO_URL"
    MASKED_REPO_URL="$REPO_URL"
    if [ -n "$GIT_TOKEN" ]; then
        if [[ "$REPO_URL" =~ ^https:// ]]; then
            CLEAN_URL="${REPO_URL#https://}"
            AUTH_REPO_URL="https://${GIT_TOKEN}@${CLEAN_URL}"
            MASKED_REPO_URL="https://[MASKED_TOKEN]@${CLEAN_URL}"
        else
            AUTH_REPO_URL="https://${GIT_TOKEN}@${REPO_URL}"
            MASKED_REPO_URL="https://[MASKED_TOKEN]@${REPO_URL}"
        fi
    fi

    rm -rf "$BACKUP_GIT_DIR"
    write_user_log "INFO" "Yedek deposu klonlanıyor: $MASKED_REPO_URL"
    CLONE_START_TS=$(date +%s)
    timeout 90 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
        clone --depth 1 --single-branch "$AUTH_REPO_URL" "$BACKUP_GIT_DIR" > /tmp/git_clone.log 2>&1
    CLONE_STATUS=$?
    CLONE_ELAPSED=$(( $(date +%s) - CLONE_START_TS ))

    if [ $CLONE_STATUS -eq 0 ]; then
        write_user_log "SUCCESS" "Yedek deposu başarıyla klonlandı. (${CLONE_ELAPSED}sn sürdü)"

        # Configure git identity inside the cloned repo
        cd "$BACKUP_GIT_DIR" || return 1
        git config user.name "Hermes Backup Bot"
        git config user.email "hermes-backup-bot@users.noreply.github.com"
        cd "$HOME/app" || return 1

        # Restore backup.log if it exists in the repo
        if [ -f "$BACKUP_GIT_DIR/backup.log" ]; then
            cp -f "$BACKUP_GIT_DIR/backup.log" "$HOME/app/backup.log"
            write_user_log "SUCCESS" "Geçmiş yedekleme logları başarıyla geri yüklendi."
        fi

        # Restore .hermes if it exists
        if [ -d "$BACKUP_GIT_DIR/.hermes" ]; then
            write_user_log "INFO" "Yedek veriler geri yükleniyor (.hermes)..."
            mkdir -p "$HOME/.hermes"
            cp -rf "$BACKUP_GIT_DIR/.hermes/"* "$HOME/.hermes/" 2>/dev/null || true
            write_user_log "SUCCESS" ".hermes geri yüklendi."
        fi

        # Restore config.yaml if it exists
        if [ -f "$BACKUP_GIT_DIR/config.yaml" ]; then
            write_user_log "INFO" "Yedek config.yaml geri yükleniyor..."
            cp -f "$BACKUP_GIT_DIR/config.yaml" "$HOME/app/config.yaml"
            write_user_log "SUCCESS" "config.yaml geri yüklendi."
        fi

        # Backward compatibility with tar.gz backup
        if [ -f "$BACKUP_GIT_DIR/hermes_backup.tar.gz" ]; then
            safe_extract_tar_backup "$BACKUP_GIT_DIR/hermes_backup.tar.gz"
        fi
    elif [ $CLONE_STATUS -eq 124 ]; then
        write_user_log "ERROR" "Yedek deposu klonlama zaman aşımına uğradı (90sn, ${CLONE_ELAPSED}sn sonra iptal edildi)."
        write_user_log "WARNING" "Depo çok büyük olabilir veya ağ bağlantısı kısıtlı. Yedek geri yükleme atlanıyor."
    else
        write_user_log "ERROR" "Yedek deposu klonlanamadı. (${CLONE_ELAPSED}sn sonra, kod: $CLONE_STATUS)"
        if [ -n "$GIT_TOKEN" ]; then
            sed "s/$GIT_TOKEN/[MASKED_TOKEN]/g" /tmp/git_clone.log
        else
            cat /tmp/git_clone.log
        fi
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
