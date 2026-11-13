# VK PC Build Comparator 🖥️

Автоматизированная система для парсинга, анализа и сравнения компьютерных сборок из VK Market с фокусом на сборки VA-PC.

## 🚀 Особенности

- **OAuth авторизация VK** для безопасного доступа к API
- **Интеллектуальный парсинг** товаров из Market и Wall
- **ML-powered анализ** - автоматическое определение цвета корпуса по фото
- **Умное извлечение компонентов** - CPU, GPU, RAM из описаний
- **Два режима сравнения**:
  - По цене (±50,000 руб)
  - По конфигурации (CPU + GPU)
- **Современный интерфейс** на React с визуальными индикаторами

## 📸 Скриншоты

![Main Interface](docs/screenshots/main.png)
![Comparison View](docs/screenshots/comparison.png)

## 🏗 Архитектура

```
Frontend (React + TypeScript)
    ↓
Backend API (FastAPI)
    ↓
PostgreSQL Database
    ↓
VK Parser + ML Module
```

## 🛠 Технологический стек

### Backend
- Python 3.11+
- FastAPI
- SQLAlchemy
- PostgreSQL
- PyTorch + OpenCLIP (ML)
- aiohttp

### Frontend
- React 18
- TypeScript
- Tailwind CSS
- Lucide Icons

### Infrastructure
- Docker & Docker Compose
- Nginx
- SSL/TLS Support

## 📦 Установка

### Предварительные требования

- Docker & Docker Compose
- VK Application (для OAuth)
- VPS с минимум 2GB RAM (для ML модуля)

### Быстрый старт

1. **Клонируйте репозиторий**
```bash
git clone https://github.com/yourusername/pc-compare.git
cd pc-compare
```

2. **Настройте переменные окружения**
```bash
cp .env.example .env
nano .env
```

3. **Запустите через Docker Compose**
```bash
docker-compose up -d
```

4. **Инициализируйте базу данных**
```bash
docker-compose exec backend python -m app.init_db
```

5. **Откройте в браузере**
```
http://localhost:3000
```

## 🔧 Конфигурация

### VK API настройки

1. Создайте Standalone приложение в VK
2. Получите `CLIENT_ID` и `CLIENT_SECRET`
3. Добавьте Redirect URI: `https://your-domain.com/auth/callback`
4. Укажите credentials в `.env`

### Группы для парсинга

В `.env` укажите ID групп VK:
```env
VK_GROUP_IDS=123456,789012,345678
```

## 📊 API Документация

### Основные endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/api/builds/our` | Получить сборки VA-PC |
| GET | `/api/builds/{id}` | Получить конкретную сборку |
| POST | `/api/compare/price` | Сравнить по цене |
| POST | `/api/compare/specs` | Сравнить по характеристикам |
| POST | `/api/parse/start` | Запустить парсинг |

Полная документация API доступна по адресу `/docs` после запуска backend.

## 🚀 Deployment на VPS

Подробная инструкция по развертыванию на продакшн сервере находится в [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## 📝 Разработка

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Frontend
```bash
cd frontend
npm install
npm start
```

### Тесты
```bash
# Backend
pytest backend/tests/

# Frontend
npm test
```

## 📈 Roadmap

- [x] OAuth авторизация VK
- [x] Парсинг Market и Wall
- [x] ML определение цвета корпуса
- [x] Сравнение по цене и характеристикам
- [ ] Мониторинг изменения цен
- [ ] Уведомления о новых сборках
- [ ] Экспорт в Google Sheets
- [ ] Графики и аналитика
- [ ] API для внешних интеграций

## 🤝 Contributing

Мы приветствуем контрибуции! Пожалуйста, ознакомьтесь с [CONTRIBUTING.md](CONTRIBUTING.md) для деталей.

## 📄 Лицензия

MIT License - см. [LICENSE](LICENSE) для деталей.

## 👨‍💻 Автор

**Serj Navigatian**

## 🙏 Благодарности

- VK API за возможность интеграции
- OpenCLIP за ML модели
- Сообществу Open Source

---

⭐ Если проект оказался полезным, поставьте звезду на GitHub!

## Existing PostgreSQL deployments

Keep a backup of the database and the current server configuration before rotating credentials. Change the role password in PostgreSQL through a trusted administrative session, then update both `POSTGRES_PASSWORD` and the password in `DATABASE_URL` in the deployment secret store and restart the application. Verify a database-backed request. Changing only the environment does not rotate an existing role. Use a URL-safe random password, or percent-encode the password in the URI. The fresh-install scripts create independent random database and application secrets; run part 2 in the existing deployment to update only its VK configuration.
