# Documento Técnico del Pipeline CI/CD

**Proyecto:** Django REST API  
**Institución:** Universidad Estatal de Milagro (UNEMI)  
**Materia:** Gestión de Proyectos de Software  
**Repositorio:** [https://github.com/jostin49/django-rest-api](https://github.com/jostin49/django-rest-api)  
**Rama de integración:** `ci-setup`  

---

## 1. Diagrama del Flujo CI/CD

El pipeline implementado en GitHub Actions consta de dos fases secuenciales: **Integración Continua (Test)** y **Construcción y Despliegue Simulado (Docker Build & Deploy)**.

```mermaid
flowchart TD
    subgraph Trigger["Disparador (Trigger)"]
        A[Git Push / Pull Request a main o ci-setup]
    end

    subgraph CI["Fase 1: Integración Continua (Job: test)"]
        B[actions/checkout@v4] --> C[Configurar Python 3.10 con caché pip]
        C --> D[Instalar dependencias: requirements.txt]
        D --> E[Ejecutar tests: python manage.py test]
    end

    subgraph CD["Fase 2: Build & Despliegue Simulado (Job: docker-build)"]
        F{¿Tests pasaron con éxito?} -- Sí --> G[Construir imagen Docker python:3.10-slim]
        F -- No --> X[Pipeline Cancelado / Alerta]
        G --> H[Levantar contenedores con Docker Compose]
        H --> I[Esperar PostgreSQL & aplicar migraciones con entrypoint.sh]
        I --> J[Validación HTTP: curl a http://localhost:8000/]
        J --> K[Empaquetar imagen .tar y subir artefacto a GitHub]
        K --> L[Simulación de Push a Docker Hub]
        L --> M[docker compose down]
    end

    subgraph ExternalDeploy["Despliegue Externo (Simulación en Host/Servidor)"]
        N[Clonar repositorio en carpeta externa] --> O[docker compose up --build -d]
        O --> P[Acceso al servicio vía Navegador / Swagger en :8000]
    end

    A --> B
    E --> F
    M -.-> N
```

---

## 2. Explicación Detallada del Archivo `.github/workflows/ci.yml`

El archivo de configuración de GitHub Actions se ubica en `.github/workflows/ci.yml`. A continuación se detallan cada uno de sus bloques:

### A. Disparadores (`on`)
```yaml
on:
  push:
    branches: [main, ci-setup]
  pull_request:
    branches: [main]
```
- **Propósito:** Activa automáticamente el pipeline ante cualquier `git push` en las ramas `main` o `ci-setup`, o cuando se crea un `Pull Request` hacia la rama principal `main`.

---

### B. Trabajo 1: Pruebas Unitarias (`job: test`)
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
```
- **`runs-on: ubuntu-latest`**: Ejecuta el entorno en una máquina virtual Linux ligera proporcionada por GitHub.
- **`working-directory: app`**: Establece la carpeta `app/` como ruta base de ejecución para todos los comandos de este job, ya que allí residen `manage.py` y `requirements.txt`.

**Pasos del Job `test`:**
1. **`actions/checkout@v4`**: Clona el código fuente del repositorio dentro del runner.
2. **`actions/setup-python@v5`**:
   - Define **Python 3.10** como versión estándar del proyecto.
   - Activa el almacenamiento en caché de dependencias (`cache: pip`), reduciendo drásticamente el tiempo de ejecución en ejecuciones posteriores.
3. **`Instalar dependencias`**: Actualiza el gestor `pip` e instala las librerías declaradas (`Django`, `djangorestframework`, `drf_yasg`, `psycopg2-binary`).
4. **`Ejecutar tests`**: Corre `python manage.py test`. Al no tener declaradas variables `SQL_*`, Django utiliza SQLite en memoria/local, ejecutando los 28 tests unitarios de forma rápida y sin dependencias externas.

---

### C. Trabajo 2: Construcción y Validación Docker (`job: docker-build`)
```yaml
  docker-build:
    needs: test
    runs-on: ubuntu-latest
```
- **`needs: test`**: Garantía de calidad (Quality Gate). Este trabajo solo se inicia si el job `test` finalizó con estado exitoso (`success`). Si una prueba falla, el build no se realiza.

**Pasos del Job `docker-build`:**
1. **Construcción de la imagen Docker:**
   ```bash
   docker build -t django-rest-api:${{ github.sha }} -t django-rest-api:latest ./app
   ```
   Etiqueta la imagen con el identificador del commit (`SHA`) para trazabilidad y con la etiqueta `:latest`.
2. **Levantamiento con Docker Compose:**
   ```bash
   docker compose up --build -d
   ```
   Inicia en segundo plano los servicios de la aplicación web y la base de datos PostgreSQL 13.
3. **Validación de disponibilidad (Healthcheck vía `curl`):**
   Ejecuta un bucle de reintento hasta que el servidor Django responde HTTP 200 en `http://localhost:8000/`.
4. **Extracción de evidencia:**
   Imprime `docker compose ps`, realiza una consulta GET a `/api/users` y muestra los logs del contenedor para inspección visual en GitHub.
5. **Generación y Almacenamiento del Artefacto:**
   - Exporta la imagen Docker a un archivo comprimido `django-rest-api-image.tar`.
   - Utiliza `actions/upload-artifact@v4` para almacenar la imagen en GitHub Actions durante 7 días, permitiendo descargarla y desplegarla en cualquier host sin necesidad de recompilar.
6. **Simulación de Publicación (Docker Hub):**
   Muestra los comandos estándar que se ejecutarían con credenciales reales (`docker login`, `docker tag`, `docker push`).
7. **Limpieza (`docker compose down -v`):**
   Garantiza que los contenedores y volúmenes se destruyan al finalizar, incluso si ocurre un fallo (`if: always()`).

---

## 3. Simulación del Despliegue en Entorno Externo

Para validar el ciclo completo en una máquina o servidor independiente:

1. **Descarga del código:**
   ```powershell
   mkdir C:\deploy-simulado
   cd C:\deploy-simulado
   git clone -b ci-setup https://github.com/jostin49/django-rest-api.git
   cd django-rest-api
   ```
2. **Despliegue orquestado:**
   ```powershell
   docker compose up --build -d
   ```
3. **Verificación operativa:**
   - Ejecutar `docker compose ps` para constatar que el contenedor `web` está en estado `Up` y `db` en estado `healthy`.
   - Abrir en el navegador web: `http://localhost:8000/` (Swagger UI) y `http://localhost:8000/api/users`.

---

## 4. Recomendaciones Finales de Ingeniería de Software

### A. Seguridad
1. **Gestión de Secretos:**  
   Nunca almacenar contraseñas ni el `SECRET_KEY` en archivos `.env` versionados en Git. Utilizar **GitHub Actions Secrets** (`${{ secrets.DOCKERHUB_TOKEN }}`, `${{ secrets.PROD_SECRET_KEY }}`) para inyectar credenciales seguras durante el despliegue.
2. **Ejecución No-Root en Docker:**  
   Por defecto, el contenedor ejecuta como usuario `root`. Se recomienda crear un usuario sin privilegios en el `Dockerfile` (`USER appuser`) para mitigar vulnerabilidades de escape de contenedor.
3. **Variables de entorno para producción:**  
   Configurar `DEBUG=0` en entornos productivos y definir un `ALLOWED_HOSTS` estricto con los dominios oficiales de la aplicación.

### B. Optimización del Pipeline
1. **Multi-Stage Builds:**  
   Implementar compilación en múltiples etapas en el `Dockerfile` para reducir el tamaño final de la imagen, descartando paquetes temporales y dependencias de compilación.
2. **Servidor WSGI Productivo:**  
   Reemplazar `python manage.py runserver` por un servidor de producción de alto rendimiento como **Gunicorn** o **Uvicorn**, con soporte de workers concurrentes.
3. **Análisis Estático de Código (Linters):**  
   Integrar herramientas como **Ruff**, **Flake8** o **Black** en el job `test` para asegurar que el código cumpla con el estándar PEP 8 de forma automatizada antes de correr las pruebas.
4. **Registro de Contenedores Real:**  
   Configurar la subida automática a **GitHub Container Registry (GHCR)** (`ghcr.io/jostin49/django-rest-api`) o a Docker Hub vinculando las credenciales institucionales.
