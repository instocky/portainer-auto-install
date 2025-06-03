#!/bin/bash

# =============================================================================
# Portainer Update Script
# Description: Обновление Portainer до последней версии
# =============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Проверка запуска Portainer
check_portainer() {
    if ! docker ps | grep -q portainer; then
        log_error "Portainer не запущен"
        exit 1
    fi
    
    CURRENT_VERSION=$(docker inspect portainer --format '{{.Config.Image}}' | cut -d: -f2)
    log_info "Текущая версия Portainer: $CURRENT_VERSION"
}

# Создание резервной копии
create_backup() {
    log_info "Создание резервной копии перед обновлением..."
    
    BACKUP_DIR="/opt/portainer-backups"
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="portainer_pre_update_${BACKUP_DATE}.tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    docker run --rm \
        -v portainer_data:/data \
        -v "$BACKUP_DIR":/backup \
        ubuntu:latest \
        tar czf "/backup/$BACKUP_FILE" -C /data .
    
    log_info "Резервная копия создана: $BACKUP_FILE"
}

# Обновление Portainer
update_portainer() {
    log_info "Обновление Portainer..."
    
    # Скачивание последнего образа
    log_info "Скачивание последней версии..."
    docker pull portainer/portainer-ce:latest
    
    # Остановка текущего контейнера
    log_info "Остановка текущего Portainer..."
    docker stop portainer
    
    # Удаление старого контейнера
    docker rm portainer
    
    # Запуск нового контейнера
    log_info "Запуск обновленного Portainer..."
    docker run -d \
        -p 8000:8000 \
        -p 9000:9000 \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    
    # Ожидание запуска
    sleep 10
    
    if docker ps | grep -q portainer; then
        NEW_VERSION=$(docker inspect portainer --format '{{.Config.Image}}' | cut -d: -f2)
        log_info "Portainer успешно обновлен до версии: $NEW_VERSION"
    else
        log_error "Ошибка обновления Portainer"
        exit 1
    fi
}

# Очистка старых образов
cleanup_old_images() {
    log_info "Очистка старых образов..."
    
    # Удаление неиспользуемых образов Portainer
    docker image prune -f --filter "label=io.portainer.image=portainer"
    
    log_info "Очистка завершена"
}

# Основная функция
main() {
    echo "======================================="
    echo "🔄 ОБНОВЛЕНИЕ PORTAINER"
    echo "======================================="
    echo ""
    
    check_root
    check_portainer
    
    read -p "Продолжить обновление Portainer? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Обновление отменено"
        exit 0
    fi
    
    create_backup
    update_portainer
    cleanup_old_images
    
    echo ""
    echo "✅ Обновление завершено успешно!"
    echo "🌐 Portainer доступен: http://$(hostname -I | awk '{print $1}'):9000"
    echo ""
}

main "$@"
