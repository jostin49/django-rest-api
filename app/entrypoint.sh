#!/bin/sh
# Espera a que PostgreSQL acepte conexiones, aplica migraciones y ejecuta el comando recibido.
set -e

if [ "$SQL_ENGINE" = "django.db.backends.postgresql" ]; then
    echo "Esperando a PostgreSQL en $SQL_HOST:$SQL_PORT ..."
    python - <<'EOF'
import os, socket, sys, time

host = os.environ.get("SQL_HOST", "db")
port = int(os.environ.get("SQL_PORT", "5432"))
for _ in range(60):
    try:
        socket.create_connection((host, port), timeout=1).close()
        sys.exit(0)
    except OSError:
        time.sleep(1)
print("PostgreSQL no respondio a tiempo")
sys.exit(1)
EOF
    echo "PostgreSQL disponible"
fi

python manage.py migrate --noinput

exec "$@"
