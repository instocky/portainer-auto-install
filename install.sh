#!/bin/bash

# =============================================================================
# Portainer Auto Install Script for Ubuntu 24.04
# Author: DevOps Engineer
# Description: Автоматическая установка Portainer на Ubuntu 24.04
# =============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Версии
DOCKER_COMPOSE_VERSION="2.21.0"
PORTAINER_VERSION="latest"

# Функции для логирования
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Функция для показа прогресса
show_progress() {
    local duration=$1
    local message=$2
    echo -n "$message"
    for ((i=0; i<duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo " ✓"
}

# Проверка root прав
check_root() {
    log_step "Проверка прав доступа..."
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root или через sudo"
        log_info "Попробуйте: sudo bash install.sh"
        exit 1
    fi
    log_info "Root права подтверждены ✓"
}

# Проверка системы
check_system() {
    log_step "Проверка системы..."
    
    # Проверка Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Поддерживается только Ubuntu"
        log_info "Текущая система: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
        exit 1
    fi
    
    # Проверка версии
    VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
    if [[ "$VERSION" != "unknown" ]]; then
        log_info "Система: Ubuntu $VERSION ✓"
        if [[ $(echo "$VERSION < 20.04" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            log_warn "Рекомендуется Ubuntu 20.04 или новее"
        fi
    else
        log_warn "Не удалось определить версию Ubuntu"
    fi
    
    # Проверка архитектуры
    ARCH=$(uname -m)
    log_info "Архитектура: $ARCH ✓"
    
    # Проверка памяти
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $MEMORY_GB -lt 1 ]]; then
        log_warn "Обнаружено менее 1GB RAM. Portainer может работать медленно."
    else
        log_info "Память: ${MEMORY_GB}GB ✓"
    fi
}

# Обновление системы и установка зависимостей
update_system() {
    log_step "Обновление системы и установка зависимостей..."
    show_progress 3 "Обновление списка пакетов"
    
    apt-get update -qq
    
    # Базовые пакеты для системы
    local base_packages=(
        "apt-transport-https"    # HTTPS поддержка для apt
        "ca-certificates"        # SSL сертификаты
        "curl"                   # Скачивание файлов
        "wget"                   # Альтернатива curl
        "gnupg"                  # GPG ключи
        "lsb-release"           # Информация о дистрибутиве
        "software-properties-common"  # Управление репозиториями
        "bc"                     # Калькулятор для скрипта
        "net-tools"             # netstat и другие сетевые утилиты
        "ufw"                   # Uncomplicated Firewall
        "fail2ban"              # Защита от брутфорса (опционально)
    )
    
    log_info "Установка базовых пакетов..."
    for package in "${base_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package "; then
            log_info "Установка $package..."
            apt-get install -y -qq "$package" 2>/dev/null || {
                log_warn "Не удалось установить $package"
            }
        fi
    done
    
    # Проверка критически важных пакетов
    local critical_packages=("curl" "gpg" "lsb_release")
    for package in "${critical_packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            log_error "Критически важный пакет $package не установлен"
            exit 1
        fi
    done
    
    log_info "Все необходимые пакеты установлены ✓"
}

# Установка Docker
install_docker() {
    log_step "Установка Docker..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
        log_info "Docker уже установлен: $DOCKER_VERSION ✓"
        
        # Проверка запуска Docker
        if ! systemctl is-active --quiet docker; then
            log_info "Запуск Docker сервиса..."
            systemctl start docker
            systemctl enable docker
        fi
        return
    fi
    
    log_info "Установка Docker CE..."
    
    # Удаление старых версий
    apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавление GPG ключа
    show_progress 2 "Добавление GPG ключа Docker"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Добавление репозитория
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    show_progress 5 "Установка Docker пакетов"
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Запуск и включение автозапуска
    systemctl start docker
    systemctl enable docker
    
    # Добавление текущего пользователя в группу docker (если не root)
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "Пользователь $SUDO_USER добавлен в группу docker"
    fi
    
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    log_info "Docker $DOCKER_VERSION установлен ✓"
}

# Проверка Docker
verify_docker() {
    log_step "Проверка Docker..."
    
    if ! docker info &> /dev/null; then
        log_error "Docker не запущен или недоступен"
        log_info "Попробуйте: sudo systemctl start docker"
        exit 1
    fi
    
    # Тестовый запуск
    log_info "Тестирование Docker..."
    if docker run --rm hello-world &> /dev/null; then
        log_info "Docker работает корректно ✓"
    else
        log_warn "Проблемы с запуском контейнеров Docker"
    fi
}

# Установка Portainer
install_portainer() {
    log_step "Установка Portainer..."
    
    # Проверка существующей установки
    if docker ps -a | grep -q portainer; then
        log_warn "Portainer уже установлен"
        read -p "Переустановить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Установка отменена"
            return
        fi
        
        log_info "Удаление существующего Portainer..."
        docker stop portainer 2>/dev/null || true
        docker rm portainer 2>/dev/null || true
    fi
    
    # Создание volume для данных
    log_info "Создание volume для данных Portainer..."
    docker volume create portainer_data
    
    # Скачивание образа
    show_progress 5 "Скачивание образа Portainer"
    docker pull portainer/portainer-ce:$PORTAINER_VERSION
    
    # Запуск Portainer
    log_info "Запуск Portainer контейнера..."
    docker run -d \
        -p 8000:8000 \
        -p 9000:9000 \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:$PORTAINER_VERSION
    
    log_info "Portainer контейнер запущен ✓"
}

# Установка и настройка firewall
configure_firewall() {
    log_step "Настройка firewall..."
    
    # Проверка установки UFW
    if ! command -v ufw &> /dev/null; then
        log_info "Установка UFW firewall..."
        apt-get install -y -qq ufw
        log_info "UFW установлен ✓"
    else
        log_info "UFW уже установлен ✓"
    fi
    
    # Проверка статуса UFW
    UFW_STATUS=$(ufw status | head -n1)
    
    if echo "$UFW_STATUS" | grep -q "Status: inactive"; then
        log_warn "UFW выключен"
        read -p "Включить UFW firewall? (рекомендуется) (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log_info "Настройка базовых правил UFW..."
            
            # Базовые правила безопасности
            ufw --force reset > /dev/null 2>&1
            ufw default deny incoming
            ufw default allow outgoing
            
            # SSH доступ (обязательно для удаленного управления)
            SSH_PORT=$(ss -tlnp | grep sshd | grep -o ':\([0-9]*\)' | head -n1 | cut -d: -f2)
            if [[ -n "$SSH_PORT" ]]; then
                ufw allow "$SSH_PORT"/tcp comment "SSH"
                log_info "SSH порт $SSH_PORT разрешен ✓"
            else
                ufw allow 22/tcp comment "SSH"
                log_info "SSH порт 22 разрешен ✓"
            fi
            
            # Portainer порты
            ufw allow 9000/tcp comment "Portainer HTTP"
            ufw allow 9443/tcp comment "Portainer HTTPS"
            ufw allow 8000/tcp comment "Portainer Edge Agent"
            
            # Включение UFW
            ufw --force enable
            log_info "UFW включен с правилами для Portainer ✓"
        else
            log_info "UFW остается выключенным"
            return
        fi
    elif echo "$UFW_STATUS" | grep -q "Status: active"; then
        log_info "UFW уже активен"
        
        # Проверка существующих правил для Portainer
        if ! ufw status | grep -q "9000"; then
            log_info "Добавление правил Portainer в UFW..."
            ufw allow 9000/tcp comment "Portainer HTTP"
            ufw allow 9443/tcp comment "Portainer HTTPS"
            ufw allow 8000/tcp comment "Portainer Edge Agent"
            log_info "Правила Portainer добавлены ✓"
        else
            log_info "Правила Portainer уже существуют ✓"
        fi
    fi
    
    # Показать итоговые правила
    log_info "Текущие правила UFW:"
    ufw status numbered | grep -E "(9000|9443|8000)" | sed 's/^/   /'
}

# Проверка установки
verify_installation() {
    log_step "Проверка установки..."
    
    show_progress 10 "Ожидание запуска Portainer"
    
    # Проверка запуска контейнера
    if docker ps | grep -q portainer; then
        log_info "Portainer контейнер запущен ✓"
    else
        log_error "Portainer контейнер не запущен"
        log_info "Логи контейнера:"
        docker logs portainer
        exit 1
    fi
    
    # Проверка доступности портов
    local ports=(9000 9443 8000)
    for port in "${ports[@]}"; do
        if netstat -tln 2>/dev/null | grep -q ":$port "; then
            log_info "Порт $port открыт ✓"
        else
            log_warn "Порт $port может быть недоступен"
        fi
    done
    
    # Получение IP адресов
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "недоступен")
    
    echo ""
    echo "============================================"
    echo "🎉 УСТАНОВКА PORTAINER ЗАВЕРШЕНА УСПЕШНО!"
    echo "============================================"
    echo ""
    echo "📊 Доступ к Portainer:"
    echo "   🌐 HTTP:  http://$LOCAL_IP:9000"
    echo "   🔒 HTTPS: https://$LOCAL_IP:9443"
    if [[ "$PUBLIC_IP" != "недоступен" ]]; then
        echo "   🌍 Внешний HTTP:  http://$PUBLIC_IP:9000"
        echo "   🌍 Внешний HTTPS: https://$PUBLIC_IP:9443"
    fi
    echo ""
    echo "🔧 Первоначальная настройка:"
    echo "   1. Откройте веб-интерфейс"
    echo "   2. Создайте admin пользователя"
    echo "   3. Выберите 'Get Started' для локального Docker"
    echo ""
    echo "📋 Полезные команды:"
    echo "   Статус:    docker ps | grep portainer"
    echo "   Логи:      docker logs portainer"
    echo "   Остановка: docker stop portainer"
    echo "   Удаление:  docker rm portainer && docker volume rm portainer_data"
    echo ""
    echo "============================================"
    echo ""
}

# Базовая настройка безопасности
configure_security() {
    log_step "Настройка базовой безопасности..."
    
    # Настройка fail2ban для защиты SSH
    if command -v fail2ban-client &> /dev/null; then
        log_info "Настройка fail2ban..."
        
        # Создание базовой конфигурации jail.local
        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
EOF
        
        # Перезапуск fail2ban
        systemctl restart fail2ban
        systemctl enable fail2ban
        log_info "fail2ban настроен и запущен ✓"
    else
        log_info "fail2ban не установлен (опционально)"
    fi
    
    # Отключение ненужных сервисов (если они есть)
    local services_to_disable=("telnet" "rsh-server" "rlogin")
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl disable "$service"
            log_info "Отключен небезопасный сервис: $service"
        fi
    done
    
    log_info "Базовая безопасность настроена ✓"
}

# Функция очистки при ошибке
cleanup_on_error() {
    log_error "Произошла ошибка во время установки"
    log_info "Очистка..."
    
    # Остановка и удаление контейнера если он был создан
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    log_info "Очистка завершена"
    exit 1
}

# Главная функция установки
main() {
    echo ""
    echo "============================================"
    echo "🐳 УСТАНОВКА PORTAINER НА UBUNTU 24.04"
    echo "============================================"
    echo "Версия скрипта: 1.0"
    echo "Дата: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================"
    echo ""
    
    # Установка обработчика ошибок
    trap cleanup_on_error ERR
    set -e
    
    # Выполнение шагов установки
    check_root
    check_system
    update_system
    install_docker
    verify_docker
    install_portainer
    configure_firewall
    configure_security
    verify_installation
    
    log_info "🚀 Установка успешно завершена!"
}

# Запуск установки
main "$@"