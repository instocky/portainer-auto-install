#!/bin/bash

# =============================================================================
# System Check Script for Portainer Installation
# Description: Проверка готовности системы к установке Portainer
# =============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_check() {
    echo -e "${BLUE}[?]${NC} $1"
}

# Счетчики
PASS=0
WARN=0
FAIL=0

check_result() {
    case $1 in
        "pass") ((PASS++)) ;;
        "warn") ((WARN++)) ;;
        "fail") ((FAIL++)) ;;
    esac
}

# Проверка операционной системы
check_os() {
    echo "=== Операционная система ==="
    
    if grep -q "Ubuntu" /etc/os-release; then
        VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
        log_info "Ubuntu $VERSION обнаружена"
        
        if [[ "$VERSION" == "24.04" ]]; then
            log_info "Версия Ubuntu полностью поддерживается"
            check_result "pass"
        elif [[ $(echo "$VERSION >= 20.04" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            log_warn "Ubuntu $VERSION поддерживается, но рекомендуется 24.04"
            check_result "warn"
        else
            log_error "Ubuntu $VERSION может быть несовместима"
            check_result "fail"
        fi
    else
        log_error "Поддерживается только Ubuntu"
        check_result "fail"
    fi
    echo
}

# Проверка архитектуры
check_architecture() {
    echo "=== Архитектура системы ==="
    
    ARCH=$(uname -m)
    case $ARCH in
        "x86_64"|"amd64")
            log_info "Архитектура: $ARCH (поддерживается)"
            check_result "pass"
            ;;
        "aarch64"|"arm64")
            log_warn "Архитектура: $ARCH (поддерживается, но может быть медленнее)"
            check_result "warn"
            ;;
        *)
            log_error "Архитектура: $ARCH (не поддерживается)"
            check_result "fail"
            ;;
    esac
    echo
}

# Проверка ресурсов
check_resources() {
    echo "=== Системные ресурсы ==="
    
    # Память
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    MEMORY_MB=$(free -m | awk '/^Mem:/{print $2}')
    
    if [[ $MEMORY_GB -ge 2 ]]; then
        log_info "Память: ${MEMORY_GB}GB (отлично)"
        check_result "pass"
    elif [[ $MEMORY_GB -ge 1 ]]; then
        log_warn "Память: ${MEMORY_GB}GB (минимальные требования)"
        check_result "warn"
    else
        log_error "Память: ${MEMORY_MB}MB (недостаточно, требуется минимум 1GB)"
        check_result "fail"
    fi
    
    # Диск
    DISK_AVAILABLE=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $DISK_AVAILABLE -ge 10 ]]; then
        log_info "Свободное место: ${DISK_AVAILABLE}GB (достаточно)"
        check_result "pass"
    elif [[ $DISK_AVAILABLE -ge 5 ]]; then
        log_warn "Свободное место: ${DISK_AVAILABLE}GB (минимально)"
        check_result "warn"
    else
        log_error "Свободное место: ${DISK_AVAILABLE}GB (недостаточно)"
        check_result "fail"
    fi
    
    # CPU
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -ge 2 ]]; then
        log_info "CPU ядер: $CPU_CORES (хорошо)"
        check_result "pass"
    else
        log_warn "CPU ядер: $CPU_CORES (будет работать медленно)"
        check_result "warn"
    fi
    echo
}

# Проверка сети
check_network() {
    echo "=== Сетевое подключение ==="
    
    # Интернет соединение
    if ping -c 1 8.8.8.8 &>/dev/null; then
        log_info "Интернет соединение доступно"
        check_result "pass"
    else
        log_error "Нет интернет соединения"
        check_result "fail"
    fi
    
    # DNS
    if nslookup docker.com &>/dev/null; then
        log_info "DNS разрешение работает"
        check_result "pass"
    else
        log_error "Проблемы с DNS разрешением"
        check_result "fail"
    fi
    
    # Доступность Docker репозитория
    if curl -s --max-time 5 https://download.docker.com &>/dev/null; then
        log_info "Docker репозиторий доступен"
        check_result "pass"
    else
        log_warn "Проблемы с доступом к Docker репозиторию"
        check_result "warn"
    fi
    echo
}

# Проверка прав
check_permissions() {
    echo "=== Права доступа ==="
    
    if [[ $EUID -eq 0 ]]; then
        log_info "Запущено с правами root"
        check_result "pass"
    elif groups | grep -q sudo; then
        log_warn "Пользователь в группе sudo (потребуется sudo для установки)"
        check_result "warn"
    else
        log_error "Недостаточно прав для установки"
        check_result "fail"
    fi
    echo
}

# Проверка существующих установок
check_existing() {
    echo "=== Существующие установки ==="
    
    # Docker
    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
        log_warn "Docker уже установлен: $DOCKER_VERSION"
        check_result "warn"
    else
        log_info "Docker не установлен (будет установлен)"
        check_result "pass"
    fi
    
    # Portainer
    if docker ps -a 2>/dev/null | grep -q portainer; then
        log_warn "Portainer уже установлен"
        check_result "warn"
    else
        log_info "Portainer не установлен (будет установлен)"
        check_result "pass"
    fi
    
    # UFW
    if command -v ufw &>/dev/null; then
        UFW_STATUS=$(ufw status 2>/dev/null | head -n1)
        log_info "UFW установлен: $UFW_STATUS"
        check_result "pass"
    else
        log_info "UFW не установлен (будет установлен)"
        check_result "pass"
    fi
    echo
}

# Итоговый отчет
show_summary() {
    echo "========================================="
    echo "📊 ИТОГОВЫЙ ОТЧЕТ ПРОВЕРКИ СИСТЕМЫ"
    echo "========================================="
    echo ""
    echo "✅ Успешно:     $PASS проверок"
    echo "⚠️  Предупреждения: $WARN проверок"
    echo "❌ Ошибки:      $FAIL проверок"
    echo ""
    
    if [[ $FAIL -eq 0 ]]; then
        echo -e "${GREEN}🎉 Система готова к установке Portainer!${NC}"
        echo ""
        echo "Для установки выполните:"
        echo "curl -sSL https://raw.githubusercontent.com/USERNAME/portainer-auto-install/main/install.sh | sudo bash"
    elif [[ $FAIL -le 2 && $WARN -le 3 ]]; then
        echo -e "${YELLOW}⚠️  Система может работать, но есть проблемы${NC}"
        echo "Рекомендуется устранить предупреждения перед установкой"
    else
        echo -e "${RED}❌ Система не готова к установке${NC}"
        echo "Необходимо устранить критические ошибки"
    fi
    echo ""
}

# Основная функция
main() {
    echo "========================================="
    echo "🔍 ПРОВЕРКА ГОТОВНОСТИ СИСТЕМЫ"
    echo "========================================="
    echo "Проверка совместимости для установки Portainer"
    echo ""
    
    check_os
    check_architecture
    check_resources
    check_network
    check_permissions
    check_existing
    show_summary
}

main "$@"
