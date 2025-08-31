# 🚀 Инструкция по загрузке проекта на GitHub

## Структура проекта готова! ✅

Ваш проект **pc-compare** полностью готов к загрузке на GitHub.

## Что было создано:

### 📁 Структура папок:
```
pc-compare/
├── backend/               # Backend на FastAPI
│   ├── app/
│   │   ├── main.py       # Основное API приложение
│   │   └── parser/
│   │       └── unified_parser.py  # Объединенный VK парсер
│   ├── requirements.txt  # Python зависимости
│   └── Dockerfile
├── frontend/             # Frontend на React + TypeScript
│   ├── src/
│   │   ├── components/   # React компоненты
│   │   ├── services/     # API сервисы
│   │   └── index.tsx     # Точка входа
│   ├── package.json
│   └── Dockerfile
├── docs/                 # Документация
│   └── DEPLOYMENT.md     # Руководство по развертыванию
├── docker-compose.yml    # Docker orchestration
├── .env.example         # Пример переменных окружения
├── .gitignore          # Git игнор правила
├── README.md           # Основная документация
└── quick-start.sh      # Скрипт быстрого запуска
```

## 📝 Следующие шаги:

### 1. Инициализация Git репозитория

```bash
cd /Users/serjnavigatian/Documents/GitHub/pc-compare
git init
```

### 2. Добавление всех файлов

```bash
git add .
git commit -m "Initial commit: VK PC Build Comparator"
```

### 3. Создание репозитория на GitHub

1. Зайдите на https://github.com/new
2. Название репозитория: `pc-compare`
3. Описание: `VK PC Build Comparator - Automated parsing and comparison of PC builds from VK Market`
4. Выберите: **Private** (если хотите приватный) или **Public**
5. НЕ инициализируйте с README (у нас уже есть)
6. Нажмите **Create repository**

### 4. Подключение к GitHub

```bash
git remote add origin https://github.com/YOUR_USERNAME/pc-compare.git
git branch -M main
git push -u origin main
```

### 5. Настройка секретов (для CI/CD)

Если планируете использовать GitHub Actions, добавьте секреты:

1. Перейдите в Settings → Secrets → Actions
2. Добавьте:
   - `VK_CLIENT_ID`
   - `VK_CLIENT_SECRET`
   - `VK_TOKEN`

## 🔧 Что нужно настроить перед запуском:

### 1. VK Application
- Создайте Standalone приложение: https://vk.com/apps?act=manage
- Получите CLIENT_ID и CLIENT_SECRET
- Добавьте Redirect URI

### 2. Переменные окружения
```bash
cp .env.example .env
nano .env
```

Обязательно заполните:
- `VK_CLIENT_ID`
- `VK_CLIENT_SECRET`
- `VK_TOKEN`
- `VK_GROUP_IDS` (ID групп для парсинга)

### 3. Запуск проекта
```bash
# Дать права на выполнение скрипту
chmod +x quick-start.sh

# Запустить
./quick-start.sh
```

## 📊 Основной функционал:

✅ **OAuth авторизация VK**  
✅ **Парсинг товаров из Market и Wall**  
✅ **ML определение цвета корпуса**  
✅ **Извлечение CPU/GPU/RAM**  
✅ **Сравнение по цене (±50k руб)**  
✅ **Сравнение по конфигурации**  
✅ **REST API**  
✅ **React интерфейс**  
✅ **Docker контейнеризация**  

## 🆘 Если что-то пошло не так:

1. Проверьте логи: `docker-compose logs`
2. Проверьте .env файл
3. Убедитесь что Docker запущен
4. Смотрите docs/DEPLOYMENT.md

## 📧 Контакты

Если нужна помощь с развертыванием или есть вопросы по коду, создайте Issue в репозитории.

---

**Проект готов к использованию!** 🎉

Удачи с развертыванием вашего VK PC Build Comparator!
