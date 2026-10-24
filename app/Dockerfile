# imagen base oficial
FROM python:3.10-slim

# directorio de trabajo
WORKDIR /usr/src/app

# variables de entorno
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# instalar dependencias (se copia primero requirements.txt para aprovechar la caché de capas)
RUN pip install --no-cache-dir --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# copiar el proyecto
COPY . .

EXPOSE 8000

# el entrypoint espera a la base de datos, aplica migraciones y ejecuta el CMD
ENTRYPOINT ["sh", "/usr/src/app/entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
