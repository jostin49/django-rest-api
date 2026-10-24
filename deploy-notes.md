# Notas de despliegue (simulado)

Este documento describe cómo se simula el despliegue continuo de `django-rest-api`: el pipeline de GitHub Actions construye la imagen y el proyecto se despliega después en una carpeta externa con Docker Compose.

Repositorio: https://github.com/jostin49/django-rest-api

## 1. Pipeline automatizado (GitHub Actions)

Archivo: `.github/workflows/ci.yml`. Se ejecuta en cada push a `main` o `ci-setup`, y en pull requests hacia `main`.

| Job | Qué hace |
|---|---|
| `test` | Instala dependencias y ejecuta `python manage.py test` (28 tests). |
| `docker-build` | Se ejecuta solo si `test` pasa. Construye la imagen, levanta el sistema con `docker compose up`, valida con `curl` que Django responde, muestra `docker compose ps` y los logs, guarda la imagen como artefacto y simula el push a Docker Hub. |

### Evidencia del contenedor corriendo desde el flujo
1. Abrir la pestaña **Actions** del repositorio.
2. Abrir la última ejecución del workflow **CI**.
3. En el job `docker-build`, abrir los pasos:
   - **Validar que el contenedor responde**: muestra `Django responde correctamente en http://localhost:8000/`.
   - **Evidencia - contenedores en ejecución**: muestra `docker compose ps`, la respuesta de la API y los logs de Django.

### Artefacto
- Al final de la ejecución, en la sección **Artifacts**, queda `django-rest-api-image` (archivo `.tar` con la imagen Docker).
- Para usarlo en otra máquina:
  ```bash
  docker load -i django-rest-api-image.tar
  ```

### Publicación en Docker Hub (simulada)
El paso "Simular publicación en Docker Hub" solo imprime los comandos. Para hacerlo real habría que guardar `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` como *secrets* del repositorio y reemplazar el paso por `docker/login-action` y `docker/build-push-action`.

## 2. Despliegue simulado en una carpeta externa

Se simula un servidor limpio usando una carpeta fuera del repositorio de trabajo.

### Requisitos
- Docker Desktop en ejecución.
- Git instalado.

### Pasos (PowerShell)
1. Crear la carpeta de despliegue, fuera del proyecto:
   ```powershell
   mkdir C:\deploy-simulado
   cd C:\deploy-simulado
   ```
2. Descargar el proyecto:
   ```powershell
   git clone -b ci-setup https://github.com/jostin49/django-rest-api.git
   cd django-rest-api
   ```
3. Levantar el sistema con Docker Compose:
   ```powershell
   docker compose up --build -d
   ```
4. Comprobar los contenedores:
   ```powershell
   docker compose ps
   ```
   `db` debe estar `healthy` y `web` en `running`.
5. Revisar los logs de arranque (migraciones y servidor):
   ```powershell
   docker compose logs web
   ```

### Validación desde el navegador
- Abrir http://localhost:8000/ : debe mostrarse la documentación Swagger "Django REST API".
- Abrir http://localhost:8000/api/users : debe devolver la lista de usuarios (vacía la primera vez).

### Apagar el entorno
```powershell
docker compose down
```
Para borrar también los datos de PostgreSQL: `docker compose down -v`.

## 3. Resultado esperado
- El pipeline pasa en verde (`test` y `docker-build`).
- Existe el artefacto `django-rest-api-image` en la ejecución.
- El sistema corre desde una carpeta externa y responde en `localhost:8000`.
