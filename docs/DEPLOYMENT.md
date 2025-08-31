# Deployment Guide - VK PC Build Comparator

## 📋 Требования

- VPS с минимум 2GB RAM (4GB рекомендуется для ML модуля)
- Ubuntu 20.04/22.04 или аналогичный Linux
- Docker и Docker Compose установлены
- Домен (опционально, для HTTPS)
- VK Application credentials

## 🚀 Быстрое развертывание

### 1. Подготовка сервера

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Проверка установки
docker --version
docker-compose --version
```

### 2. Получение VK credentials

1. Перейдите на https://vk.com/apps?act=manage
2. Создайте новое Standalone приложение
3. Перейдите в настройки приложения
4. Скопируйте ID приложения и Защищенный ключ
5. Добавьте Redirect URI: `https://your-domain.com/auth/callback`

### 3. Клонирование проекта

```bash
# Клонируем репозиторий
git clone https://github.com/yourusername/pc-compare.git
cd pc-compare

# Создаем .env файл
cp .env.example .env
```

### 4. Настройка переменных окружения

Отредактируйте `.env` файл:

```bash
nano .env
```

Обязательные параметры:
```env
# VK API
VK_CLIENT_ID=ваш_id_приложения
VK_CLIENT_SECRET=ваш_защищенный_ключ
VK_TOKEN=vk1.a.ваш_токен

# Группы для парсинга (VA-PC и конкуренты)
VK_GROUP_IDS=123456,789012,345678

# База данных (измените пароль!)
POSTGRES_PASSWORD=secure_password_here
```

### 5. Запуск через Docker Compose

```bash
# Запуск в фоновом режиме
docker-compose up -d

# Проверка логов
docker-compose logs -f

# Остановка
docker-compose down
```

### 6. Инициализация базы данных

```bash
# Создание таблиц
docker-compose exec backend python -c "from app.main import Base, engine; Base.metadata.create_all(bind=engine)"

# Первый парсинг (опционально)
docker-compose exec backend python -m app.parser.unified_parser
```

## 🔒 Настройка HTTPS (с доменом)

### Вариант 1: Nginx + Let's Encrypt

```bash
# Установка Certbot
sudo apt install certbot python3-certbot-nginx -y

# Получение сертификата
sudo certbot --nginx -d your-domain.com

# Автообновление
sudo certbot renew --dry-run
```

### Вариант 2: Cloudflare Tunnel

```bash
# Установка cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Авторизация
cloudflared tunnel login

# Создание туннеля
cloudflared tunnel create pc-compare

# Настройка маршрута
cloudflared tunnel route dns pc-compare your-domain.com

# Запуск
cloudflared tunnel run pc-compare
```

## 📊 Мониторинг

### Проверка состояния сервисов

```bash
# Статус контейнеров
docker-compose ps

# Использование ресурсов
docker stats

# Логи конкретного сервиса
docker-compose logs backend
docker-compose logs frontend
docker-compose logs db
```

### Backup базы данных

```bash
# Создание backup
docker-compose exec db pg_dump -U pc_builds_user pc_builds > backup_$(date +%Y%m%d).sql

# Восстановление из backup
docker-compose exec -T db psql -U pc_builds_user pc_builds < backup.sql
```

## 🔄 Автоматический парсинг

### Настройка cron для регулярного парсинга

```bash
# Открываем crontab
crontab -e

# Добавляем задачу (парсинг каждые 6 часов)
0 */6 * * * cd /path/to/pc-compare && docker-compose exec -T backend python -m app.parser.unified_parser >> /var/log/pc-compare-parser.log 2>&1
```

### Создание systemd сервиса (альтернатива)

Создайте файл `/etc/systemd/system/pc-compare-parser.service`:

```ini
[Unit]
Description=PC Compare Parser
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=/path/to/pc-compare
ExecStart=/usr/local/bin/docker-compose exec -T backend python -m app.parser.unified_parser

[Install]
WantedBy=multi-user.target
```

И таймер `/etc/systemd/system/pc-compare-parser.timer`:

```ini
[Unit]
Description=Run PC Compare Parser every 6 hours

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Активация:
```bash
sudo systemctl enable pc-compare-parser.timer
sudo systemctl start pc-compare-parser.timer
```

## 🐛 Устранение неполадок

### Проблема: Ошибка подключения к VK API

**Решение:**
1. Проверьте токен: `docker-compose exec backend python -c "from app.parser.unified_parser import VKMarketParser; print('OK')"`
2. Проверьте fallback URLs в `.env`
3. Используйте VPN если API заблокирован

### Проблема: Недостаточно памяти для ML модуля

**Решение:**
1. Отключите ML определение цвета: `USE_ML_COLOR_DETECTION=false`
2. Увеличьте swap:
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Проблема: База данных не инициализируется

**Решение:**
```bash
# Пересоздание контейнера БД
docker-compose down db
docker-compose up -d db
sleep 10
docker-compose exec backend python -c "from app.main import Base, engine; Base.metadata.create_all(bind=engine)"
```

## 📈 Оптимизация производительности

### 1. Настройка Redis кеширования

В `.env`:
```env
REDIS_CACHE_TTL=3600  # 1 час
```

### 2. Оптимизация PostgreSQL

```bash
# Подключение к БД
docker-compose exec db psql -U pc_builds_user pc_builds

-- Создание индексов
CREATE INDEX idx_builds_cpu_gpu ON pc_builds(cpu, gpu);
CREATE INDEX idx_builds_price_range ON pc_builds(price);
CREATE INDEX idx_builds_company ON pc_builds(company);
```

### 3. Настройка Nginx для статики

В `docker/nginx/nginx.conf`:
```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи: `docker-compose logs`
2. Создайте issue на GitHub
3. Проверьте документацию VK API

## 🔄 Обновление

```bash
# Остановка сервисов
docker-compose down

# Получение обновлений
git pull

# Пересборка контейнеров
docker-compose build

# Запуск
docker-compose up -d

# Миграция БД (если требуется)
docker-compose exec backend alembic upgrade head
```

---

**Версия документа**: 1.0.0  
**Последнее обновление**: 2025-01-08
