# Portainer Auto Install

Автоматическая установка Portainer на Ubuntu 24.04 с полной настройкой Docker окружения.

## 🚀 Быстрая установка

### Автоматическая установка (рекомендуется):
```bash
curl -sSL https://raw.githubusercontent.com/instocky/portainer-auto-install/main/install.sh | sudo bash
```

### С дополнительными параметрами:
```bash
# Отключить автоматическое включение UFW firewall
SKIP_UFW=yes curl -sSL https://raw.githubusercontent.com/instocky/portainer-auto-install/main/install.sh | sudo bash
```

### Или скачать и запустить:
```bash
wget https://raw.githubusercontent.com/instocky/portainer-auto-install/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

## 📋 Что устанавливается

- **Docker CE** - последняя стабильная версия
- **Docker Compose** - как плагин Docker
- **Portainer CE** - Community Edition
- **UFW Firewall** - автоматическая установка и настройка
- **Fail2ban** - защита от брутфорса SSH (опционально)
- **Базовые пакеты** - curl, wget, gnupg, net-tools и другие
- Настройка автозапуска всех сервисов
- Базовая настройка безопасности системы

## ✅ Требования

- **ОС**: Ubuntu 20.04+ (рекомендуется 24.04)
- **RAM**: минимум 1GB (рекомендуется 2GB+)
- **Диск**: минимум 5GB свободного места
- **Права**: root или sudo доступ
- **Сеть**: доступ к интернету для скачивания пакетов

## 🔧 Что делает скрипт

1. **Проверка системы** - версия Ubuntu, архитектура, память
2. **Установка зависимостей** - curl, wget, gnupg, ufw, fail2ban и др.
3. **Обновление пакетов** - установка необходимых зависимостей
4. **Установка Docker** - официальный репозиторий Docker
5. **Настройка Docker** - автозапуск, права пользователя
6. **Установка Portainer** - последняя версия Community Edition
7. **Настройка UFW firewall** - автоустановка и конфигурация правил
8. **Базовая безопасность** - fail2ban, отключение небезопасных сервисов
9. **Проверка работы** - тестирование всех компонентов

## 🌐 Доступ после установки

После успешной установки Portainer будет доступен по адресам:

- **HTTP** (рекомендуется для начала): `http://YOUR_SERVER_IP:9000`
- **HTTPS** (требует подтверждения в браузере): `https://YOUR_SERVER_IP:9443`
- **Edge Agent**: `http://YOUR_SERVER_IP:8000`

⚠️ **Важно по HTTPS**: Portainer использует самоподписанный сертификат, поэтому браузер покажет предупреждение о безопасности. Нажмите "Дополнительно" → "Перейти на сайт" для продолжения.

### Первоначальная настройка:

1. Откройте веб-интерфейс в браузере
2. Создайте администратора (логин/пароль)
3. Выберите "Get Started" для управления локальным Docker
4. Начните управлять контейнерами!

## 🐳 Полезные команды Docker

```bash
# Статус Portainer
docker ps | grep portainer

# Логи Portainer
docker logs portainer

# Перезапуск Portainer
docker restart portainer

# Остановка Portainer
docker stop portainer

# Полное удаление
docker stop portainer
docker rm portainer
docker volume rm portainer_data
```

## 🔐 Безопасность

### Рекомендации после установки:

1. **Сменить порт по умолчанию**:
```bash
docker stop portainer
docker rm portainer
docker run -d -p 8080:9000 --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce
```

2. **Настроить SSL сертификат** для HTTPS доступа:
```bash
# Для доменного имени с Let's Encrypt
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# Обновить Portainer с правильными сертификатами
docker stop portainer
docker rm portainer
docker run -d -p 9000:9000 -p 9443:9443 --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  -v /etc/letsencrypt/live/your-domain.com:/certs \
  portainer/portainer-ce --sslcert /certs/fullchain.pem --sslkey /certs/privkey.pem
```

3. **Ограничить доступ** через firewall:
```bash
# Разрешить доступ только с определенной сети
sudo ufw allow from 192.168.1.0/24 to any port 9000
```

4. **Регулярно обновлять** Portainer и Docker

## 🛠️ Устранение проблем

### Portainer не запускается:
```bash
# Проверить логи
docker logs portainer

# Проверить Docker
sudo systemctl status docker

# Перезапустить Docker
sudo systemctl restart docker
```

### Нет доступа через браузер:
```bash
# Проверить открытые порты
sudo netstat -tln | grep 9000

# Проверить firewall
sudo ufw status

# Проверить IP адрес
hostname -I
```

### Ошибки прав доступа:
```bash
# Добавить пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиниться или выполнить:
newgrp docker
```

## 📁 Структура проекта

```
portainer-auto-install/
├── install.sh              # Основной скрипт установки
├── README.md               # Документация (этот файл)
├── docker-compose.yml      # Альтернативная установка через Compose
├── .gitignore             # Исключения для Git
├── configs/
│   ├── portainer.env      # Переменные окружения
│   └── nginx.conf         # Пример Nginx reverse proxy
└── scripts/
    ├── check-system.sh    # Проверка готовности системы
    ├── backup.sh          # Скрипт резервного копирования
    └── update.sh          # Скрипт обновления Portainer
```

## 🔧 Дополнительные скрипты

### Проверка системы перед установкой:
```bash
curl -sSL https://raw.githubusercontent.com/instocky/portainer-auto-install/main/scripts/check-system.sh | bash
```

### Создание резервной копии:
```bash
wget https://raw.githubusercontent.com/instocky/portainer-auto-install/main/scripts/backup.sh
chmod +x backup.sh
sudo ./backup.sh
```

### Обновление Portainer:
```bash
wget https://raw.githubusercontent.com/instocky/portainer-auto-install/main/scripts/update.sh
chmod +x update.sh
sudo ./update.sh
```

## 🔄 Альтернативная установка через Docker Compose

Если предпочитаете использовать Docker Compose:

```bash
# Скачать docker-compose.yml
wget https://raw.githubusercontent.com/instocky/portainer-auto-install/main/docker-compose.yml

# Запустить
docker compose up -d
```

## 📞 Поддержка

- **Документация Portainer**: https://docs.portainer.io/
- **Docker документация**: https://docs.docker.com/
- **Issues**: Создайте issue в этом репозитории

## 📄 Лицензия

MIT License - можете свободно использовать и модифицировать.

---

**Автор**: DevOps Engineer Instocky  
**Версия**: 1.0  
**Дата**: 2025-06-03
