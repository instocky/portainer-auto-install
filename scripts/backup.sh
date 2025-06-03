#!/bin/bash

# =============================================================================
# Portainer Backup Script  
# Description: Создание резервной копии данных Portainer
# =============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Настройки
BACKUP_DIR="/opt/portainer-backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="portainer_backup_${BACKUP_DATE}.tar.gz"
KEEP_BACKUPS=7  # Количество резервных копий для хранения

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root"
        exit 1
    fi
}

# Создание директории для бэкапов
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Создана директория для бэкапов: $BACKUP_DIR"
    fi
}

# Проверка запуска Portainer
check_portainer() {
    if ! docker ps | grep -q portainer; then
        log_error "Portainer не запущен"
        exit 1
    fi
    log_info "Portainer запущен ✓"
}

# Создание бэкапа
create_backup() {
    log_info "Создание резервной копии..."
    
    # Временная остановка Portainer
    log_info "Остановка Portainer для создания консистентного бэкапа..."
    docker stop portainer
    
    # Создание архива volume
    docker run --rm \
        -v portainer_data:/data \
        -v "$BACKUP_DIR":/backup \
        ubuntu:latest \
        tar czf "/backup/$BACKUP_FILE" -C /data .
    
    # Перезапуск Portainer
    log_info "Перезапуск Portainer..."
    docker start portainer
    
    if [[ -f "$BACKUP_DIR/$BACKUP_FILE" ]]; then
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        log_info "Резервная копия создана: $BACKUP_FILE ($BACKUP_SIZE)"
    else
        log_error "Ошибка создания резервной копии"
        exit 1
    fi
}

# Очистка старых бэкапов
cleanup_old_backups() {
    log_info "Очистка старых резервных копий (сохраняем последние $KEEP_BACKUPS)..."
    
    cd "$BACKUP_DIR"
    ls -t portainer_backup_*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm
    
    REMAINING=$(ls portainer_backup_*.tar.gz 2>/dev/null | wc -l)
    log_info "Осталось резервных копий: $REMAINING"
}

# Основная функция
main() {
    echo "========================================="
    echo "🗄️  СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ PORTAINER"
    echo "========================================="
    echo ""
    
    check_root
    create_backup_dir
    check_portainer
    create_backup
    cleanup_old_backups
    
    echo ""
    echo "✅ Резервное копирование завершено успешно!"
    echo "📁 Файл: $BACKUP_DIR/$BACKUP_FILE"
    echo ""
}

main "$@"
