from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from dotenv import load_dotenv

import os

load_dotenv()


app = FastAPI(title="Cloud Lab Starter App")
app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")


def get_app_config() -> dict[str, str]:
    return {
        "app_name": os.getenv("APP_NAME", "Cloud Lab Starter App"),
        "intern_name": os.getenv("INTERN_NAME", "Replace Me"),
        "cloud_platform": os.getenv("CLOUD_PLATFORM", "Replace Me"),
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "app_version": os.getenv("APP_VERSION", "v1.0.0"),
        "app_status": os.getenv("APP_STATUS", "healthy"),
    }


@app.get("/", response_class=HTMLResponse)
async def read_home(request: Request) -> HTMLResponse:
    context = {"request": request, "config": get_app_config()}
    return templates.TemplateResponse("index.html", context)


@app.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "healthy"}
