# Lab 1 Starter App

This repository contains a small FastAPI application for the Cloud and DevOps intern Lab 1 starter project. The app is intentionally simple so you can focus on understanding it, updating a few values, containerizing it, and deploying it with your lab instructions.

## Routes

- `/` renders the homepage with the app details.
- `/health` returns a simple JSON health response with HTTP 200.

## Environment Variables

The homepage reads these values at runtime:

| Variable | Default |
| --- | --- |
| `APP_NAME` | `Cloud Lab Starter App` |
| `INTERN_NAME` | `Replace Me` |
| `CLOUD_PLATFORM` | `Replace Me` |
| `ENVIRONMENT` | `dev` |
| `APP_VERSION` | `v1.0.0` |
| `APP_STATUS` | `healthy` |

These are the values you are expected to update for the lab, especially:

- your full name
- your cloud platform
- environment if required
- version if required

## Run Without Docker

1. Create a virtual environment:

   ```bash
   python3 -m venv .venv
   ```

2. Activate it:

   ```bash
   source .venv/bin/activate
   ```

3. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

4. Start the app:

   ```bash
   uvicorn app.main:app --reload
   ```

5. Open the app:

   - Homepage: [http://localhost:8000](http://localhost:8000)
   - Health check: [http://localhost:8000/health](http://localhost:8000/health)

### Example With Environment Variables

```bash
APP_NAME="Cloud Lab Starter App" \
INTERN_NAME="Ada Lovelace" \
CLOUD_PLATFORM="AWS" \
ENVIRONMENT="dev" \
APP_VERSION="v1.0.1" \
APP_STATUS="healthy" \
uvicorn app.main:app --reload
```

## Run With Docker

1. Build the image:

   ```bash
   docker build -t lab1-starter-app .
   ```

2. Run the container:

   ```bash
   docker run --rm -p 8000:8000 \
     -e INTERN_NAME="Ada Lovelace" \
     -e CLOUD_PLATFORM="Azure" \
     lab1-starter-app
   ```

3. Open the app:

   - Homepage: [http://localhost:8000](http://localhost:8000)
   - Health check: [http://localhost:8000/health](http://localhost:8000/health)

## Project Structure

```text
lab-1/
  app/
    main.py
    templates/
      index.html
    static/
      style.css
  requirements.txt
  Dockerfile
  .dockerignore
  .gitignore
  README.md
```

## What You Should Modify

For Lab 1, you should be able to make changes in obvious places:

- set the environment variables to your own values
- update the template only if you need a small UI change
- use the `/health` endpoint for container and deployment health checks


