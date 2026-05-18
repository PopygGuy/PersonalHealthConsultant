#!/usr/bin/env bash
set -euo pipefail

PORT="8000"
BIND_HOST="0.0.0.0"
SERVER_IP=""
PROJECT_ROOT="/opt/phc"
SERVICE_NAME="phc-api"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-ip)
      SERVER_IP="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-8000}"
      shift 2
      ;;
    --project-root)
      PROJECT_ROOT="${2:-/opt/phc}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP="$(hostname -I | awk '{print $1}')"
fi

BACKEND_ROOT="$PROJECT_ROOT/backend"

if [[ ! -d "$BACKEND_ROOT" ]]; then
  echo "Backend directory not found: $BACKEND_ROOT"
  echo "Clone the project to $PROJECT_ROOT first."
  exit 1
fi

cd "$BACKEND_ROOT"

echo "== PHC API: VPS setup =="
echo "Project: $PROJECT_ROOT"
echo "Backend: $BACKEND_ROOT"
echo "Server IP: $SERVER_IP"
echo "Port: $PORT"

apt update
apt install -y python3 python3-venv python3-pip git ufw

if [[ ! -x ".venv/bin/python" ]]; then
  python3 -m venv .venv
fi

./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/python -m pip install -r requirements.txt

if [[ ! -f ".env" ]]; then
  SECRET_KEY="$(./.venv/bin/python - <<'PY'
import secrets
print(secrets.token_urlsafe(48))
PY
)"
  cat > .env <<EOF
SECRET_KEY=$SECRET_KEY
DATABASE_URL=sqlite:///phc.db
CORS_ORIGINS=http://$SERVER_IP:$PORT
EOF
  echo "Created .env"
fi

./.venv/bin/python scripts/bootstrap_admin.py

ufw allow OpenSSH
ufw allow "$PORT/tcp"
ufw --force enable

if [[ ! -f "deploy/phc-api.service.example" ]]; then
  echo "Service example not found: deploy/phc-api.service.example"
  exit 1
fi

cp deploy/phc-api.service.example "/etc/systemd/system/$SERVICE_NAME.service"
sed -i "s|WorkingDirectory=/opt/phc/backend|WorkingDirectory=$BACKEND_ROOT|g" "/etc/systemd/system/$SERVICE_NAME.service"
sed -i "s|EnvironmentFile=/opt/phc/backend/.env|EnvironmentFile=$BACKEND_ROOT/.env|g" "/etc/systemd/system/$SERVICE_NAME.service"
sed -i "s|ExecStart=/opt/phc/backend/.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000|ExecStart=$BACKEND_ROOT/.venv/bin/python -m uvicorn app.main:app --host $BIND_HOST --port $PORT|g" "/etc/systemd/system/$SERVICE_NAME.service"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo ""
echo "Setup complete."
echo "API: http://$SERVER_IP:$PORT"
echo "Swagger UI: http://$SERVER_IP:$PORT/docs"
echo "Service status: systemctl status $SERVICE_NAME"
echo "Logs: journalctl -u $SERVICE_NAME -f"
