# Развертывание PHC API на VPS и сборка APK

Документ описывает сценарий, при котором backend развернут на VPS с публичным IP, а пользователи устанавливают APK и входят в приложение по выданным логину и паролю.

## 1. Общая схема

```text
APK на телефоне -> http://SERVER_IP:8000 -> FastAPI на VPS -> backend/phc.db
```

Для MVP можно использовать публичный IP и HTTP. Для постоянной эксплуатации рекомендуется следующим этапом подключить домен, nginx и HTTPS.

## 2. Требования к VPS

Рекомендуемая конфигурация для учебного/демонстрационного запуска:

- Ubuntu 22.04 LTS или 24.04 LTS;
- 1 vCPU;
- 1-2 GB RAM;
- 10+ GB SSD;
- открытый TCP-порт `8000`;
- установленный `git`;
- Python 3.11+.

## 3. Установка backend на VPS

Подключиться к серверу:

```bash
ssh root@SERVER_IP
```

Установить системные зависимости:

```bash
apt update
apt install -y python3 python3-venv python3-pip git ufw
```

Клонировать проект:

```bash
cd /opt
git clone https://github.com/PopygGuy/PersonalHealthConsultant.git phc
cd /opt/phc/backend
```

Создать виртуальное окружение и установить зависимости:

```bash
python3 -m venv .venv
./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/python -m pip install -r requirements.txt
```

Создать файл `.env`:

```bash
cat > .env <<'EOF'
SECRET_KEY=CHANGE_ME_TO_LONG_RANDOM_SECRET
DATABASE_URL=sqlite:///phc.db
CORS_ORIGINS=http://SERVER_IP:8000
EOF
```

Заменить `SERVER_IP` на публичный IP сервера. Значение `SECRET_KEY` должно быть длинной случайной строкой.

Создать администратора `root/root`:

```bash
./.venv/bin/python scripts/bootstrap_admin.py
```

Проверить ручной запуск API:

```bash
./.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Проверить в браузере:

```text
http://SERVER_IP:8000/docs
```

## 4. Открытие порта

Разрешить SSH и API:

```bash
ufw allow OpenSSH
ufw allow 8000/tcp
ufw enable
ufw status
```

## 5. Автозапуск через systemd

Скопировать пример сервиса:

```bash
cp /opt/phc/backend/deploy/phc-api.service.example /etc/systemd/system/phc-api.service
```

Если проект расположен не в `/opt/phc`, отредактировать пути:

```bash
nano /etc/systemd/system/phc-api.service
```

Запустить сервис:

```bash
systemctl daemon-reload
systemctl enable phc-api
systemctl start phc-api
systemctl status phc-api
```

Просмотр логов:

```bash
journalctl -u phc-api -f
```

После этого API должен быть доступен постоянно:

```text
http://SERVER_IP:8000/docs
```

## 6. Быстрая установка скриптом

Для Ubuntu можно использовать подготовленный скрипт:

```bash
cd /opt/phc/backend
chmod +x scripts/setup_vps.sh
sudo ./scripts/setup_vps.sh --server-ip SERVER_IP
```

Скрипт:

- устанавливает системные зависимости;
- создает `.venv`;
- устанавливает Python-зависимости;
- создает `.env`, если его нет;
- создает/обновляет администратора `root/root`;
- открывает порт `8000`;
- устанавливает и запускает `systemd`-сервис.

## 7. Сборка APK под VPS

На компьютере разработчика выполнить:

```powershell
flutter pub get
flutter build apk --release --dart-define API_BASE_URL=http://SERVER_IP:8000
```

Готовый APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Этот файл можно передать пользователю. Пользователь устанавливает APK и входит по логину и паролю, которые созданы администратором.

## 7.1. Раздача APK через QR-код (для демонстрации комиссии)

В проект добавлен модуль раздачи:

- `GET /distribution/apk` — скачивание APK из `backend/public/app-release.apk`;
- `GET /distribution/qr.png` — PNG QR-код для ссылки на APK;
- `GET /distribution/landing` — готовая веб-страница с QR-кодом и кнопкой скачивания.

### Подготовка на VPS

1. Обновить backend и зависимости:

```bash
cd /opt/phc
git pull
cd backend
./.venv/bin/python -m pip install -r requirements.txt
systemctl restart phc-api
```

2. Скопировать собранный APK на VPS в ожидаемый путь:

```bash
mkdir -p /opt/phc/backend/public
cp /path/to/app-release.apk /opt/phc/backend/public/app-release.apk
```

Если APK лежит на локальном компьютере, передать его можно через `scp`:

```bash
scp build/app/outputs/flutter-apk/app-release.apk root@SERVER_IP:/opt/phc/backend/public/app-release.apk
```

3. Открыть страницу для комиссии:

```text
http://SERVER_IP:8000/distribution/landing
```

На этой странице отображается QR-код и прямая кнопка скачивания APK.

## 8. Выдача логинов и паролей

Порядок работы:

1. Администратор входит в приложение.
2. Создает преподавателей и студентов.
3. Для каждого пользователя задает логин и временный пароль.
4. Передает пользователю APK, логин и пароль.
5. Пользователь устанавливает APK и авторизуется.

Важно: учетная запись `root` предназначена для технической настройки. В текущей реализации вход под `root` разрешен только с серверного устройства. Для реальных пользователей нужно создавать отдельные учетные записи администратора, преподавателя и студента.

### Рекомендуемый порядок перед передачей APK

1. Развернуть backend на VPS.
2. Проверить `http://SERVER_IP:8000/docs`.
3. Собрать APK с `API_BASE_URL=http://SERVER_IP:8000`.
4. Установить APK на свой телефон и проверить вход тестовым пользователем.
5. В кабинете администратора создать реальные учетные записи.
6. Передать каждому пользователю:
   - APK-файл;
   - логин;
   - пароль;
   - краткую инструкцию: открыть приложение, ввести логин и пароль.

### Что делать при смене IP сервера

Если у VPS изменился публичный IP, APK, собранный со старым адресом, перестанет подключаться к API. В этом случае нужно:

1. Пересобрать APK с новым адресом:

```powershell
flutter build apk --release --dart-define API_BASE_URL=http://NEW_SERVER_IP:8000
```

2. Передать пользователям обновленный APK.

Чтобы избежать пересборки при смене IP, следующим этапом рекомендуется подключить домен и собирать APK с доменным адресом API.

## 9. Обновление backend на VPS

```bash
cd /opt/phc
git pull
cd backend
./.venv/bin/python -m pip install -r requirements.txt
systemctl restart phc-api
```

## 10. Резервное копирование базы данных

SQLite-файл хранится по пути:

```text
/opt/phc/backend/phc.db
```

Пример резервного копирования:

```bash
mkdir -p /opt/phc/backups
cp /opt/phc/backend/phc.db /opt/phc/backups/phc-$(date +%Y-%m-%d-%H-%M).db
```

## 11. Ограничения варианта без домена

- используется HTTP, а не HTTPS;
- адрес API зависит от публичного IP VPS;
- при смене IP нужно пересобрать APK с новым `API_BASE_URL`;
- для постоянной эксплуатации лучше подключить домен, nginx и SSL-сертификат.

