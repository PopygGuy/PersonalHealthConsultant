# PHC: Централизованная система мониторинга физподготовки и оценок

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-REST-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![SQLite](https://img.shields.io/badge/DB-SQLite-003B57?logo=sqlite&logoColor=white)](https://sqlite.org/)

Клиент-серверная система для образовательной среды:

- студенты видят оценки и свою физическую активность;
- преподаватели выставляют оценки по нормативам;
- администраторы управляют пользователями, факультетами, группами и справочниками.

---

## Архитектура

`Flutter (Android) -> REST API (FastAPI) -> SQLite (backend/phc.db)`

- клиент не имеет прямого доступа к БД;
- вся валидация и бизнес-логика выполняется на сервере;
- мобильное приложение подключается к API по адресу, заданному при сборке (`--dart-define API_BASE_URL=...`).

## Роли и безопасность

- **student**: просмотр собственных данных.
- **teacher**: работа с нормативами и оценками.
- **admin**: управление пользователями и структурой.

Дополнительное правило безопасности:

- логин `root` разрешен **только с устройства, где запущен backend** (localhost сервера).

---

## Быстрый старт (локальная разработка)

### Backend

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe scripts\bootstrap_admin.py
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Проверка: откройте `http://127.0.0.1:8000` и убедитесь, что видите `{"message":"Welcome to PHC API"}`.

### Flutter (debug)

```powershell
cd ..
flutter pub get
flutter run --dart-define API_BASE_URL=http://127.0.0.1:8000
```

---

## Развертывание backend на отдельном ПК (LAN)

Этот сценарий нужен, когда сервер работает на выделенном компьютере в локальной сети, а пользователи заходят с телефонов/планшетов.

### 1) Запуск серверного ПК

На серверном ПК:

```powershell
cd backend
powershell -ExecutionPolicy Bypass -File .\scripts\setup_server_pc.ps1
```

Скрипт автоматически:

- создает `backend/.venv` (если нет);
- устанавливает Python-зависимости;
- создает `.env` из `.env.example` (если отсутствует);
- создает/обновляет `root`;
- открывает порт в Windows Firewall;
- показывает LAN-адреса (`http://192.168.x.x:8000`);
- запускает API (`0.0.0.0:8000`).

### 2) Проверка доступности в сети

С телефона в той же Wi-Fi сети откройте:

`http://<LAN_IP_СЕРВЕРА>:8000`

Если в браузере телефона открывается приветствие API, сеть настроена корректно.

### 3) Сборка APK для пользователей

Собирайте APK с адресом серверного API:

```powershell
flutter build apk --release --dart-define API_BASE_URL=http://192.168.0.103:8000
```

Для тестов в debug:

```powershell
flutter run --dart-define API_BASE_URL=http://192.168.0.103:8000
```

Важно:

- при смене IP сервера нужно пересобрать APK с новым `API_BASE_URL`;
- пользователь вводит только логин/пароль (адрес сервера в UI не вводится).

---

## Доступ из интернета (через роутер)

Если нужно подключение не только в LAN, но и извне:

1. Зафиксируйте локальный IP серверного ПК в роутере (DHCP Reservation), например `192.168.0.103`.
2. Настройте проброс порта (Port Forwarding / Virtual Server):
   - **External Port**: `8000`
   - **Internal IP**: `192.168.0.103`
   - **Internal Port**: `8000`
   - **Protocol**: `TCP`
3. Убедитесь, что правило Windows Firewall на сервере открыто для `8000/TCP`.
4. Проверьте внешний доступ по `http://<ВАШ_PUBLIC_IP>:8000`.

### TP-Link: что обычно заполнять

В разделе `Advanced -> NAT Forwarding -> Virtual Servers`:

- Service Name: `PHC API`
- External Port: `8000`
- Internal IP: `192.168.0.103` (IP вашего серверного ПК)
- Internal Port: `8000`
- Protocol: `TCP`
- Status: `Enabled`

### Важное ограничение провайдера (CG-NAT)

Если порт не открывается снаружи, при том что локально все работает, возможен CG-NAT у провайдера.
В этом случае варианты:

- заказать у провайдера "белый" статический IP;
- использовать VPN-туннель/обратный прокси;
- разместить backend на VPS/облаке.

---

## Минимальный production-чеклист

Перед выдачей приложения пользователям:

- сменить пароль `root` на сложный;
- задать сильный `SECRET_KEY` в `backend/.env`;
- сделать резервную копию `backend/phc.db`;
- зафиксировать IP серверного ПК в роутере;
- проверить логин student/teacher в реальном устройстве;
- убедиться, что `root` не логинится удаленно (это ожидаемое поведение).

---

## Частые проблемы и быстрые решения

- **`405 Method Not Allowed` на логине**  
  Проверить, что клиент отправляет `POST /token` на корректный адрес API.

- **Нет логов при попытке входа с телефона**  
  Обычно APK собран с неверным `API_BASE_URL`, либо нет интернет-разрешений/cleartext в Android (в проекте уже настроено).

- **`UNIQUE constraint failed` при создании сущностей**  
  Это защита от дублей. Клиент и сервер возвращают понятное предупреждение, а не `500`.

- **`root` не входит с телефона**  
  Это корректно: `root` разрешен только на серверном устройстве.

---

## Полезные скрипты backend

- `backend/scripts/setup_server_pc.ps1` - автоподготовка и запуск API на выделенном ПК.
- `backend/scripts/bootstrap_admin.py` - создать/обновить администратора.
- `backend/scripts/dedupe_faculties.py` - устранение дублей факультетов.
- `backend/scripts/seed_initial_catalog.py` - заполнение базовых справочников.
- `backend/scripts/archive/centralize_db.py` - архивный одноразовый скрипт миграции legacy-данных.

## Материалы проекта

- `docs/dissertation_project_description.md`
- `docs/dissertation_abstract_one_page.md`
