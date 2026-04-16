# How I Built and Deployed a Containerized App to Azure — From Zero to CI/CD

I recently completed a Cloud & DevOps lab where I took a simple Python web app, containerized it, deployed it to Azure, and set up a full CI/CD pipeline with zero stored passwords. Here's exactly how I did it — every decision, every mistake, and every lesson learned.

---

## What I Built

A FastAPI web application deployed to Azure Container Apps with:
- Docker containerization with security hardening
- Terraform for infrastructure as code
- GitHub Actions CI/CD pipeline with OIDC authentication
- A black and gold UI theme (because why not)

**Live URL:** [lab1-anthony.jollydune-6b467ed5.westus2.azurecontainerapps.io](https://lab1-anthony.jollydune-6b467ed5.westus2.azurecontainerapps.io)

> The URL may be down if I've destroyed the infrastructure to save costs. That's the beauty of IaC — I can bring it back with one command.

---

## The Stack

| Tool | Purpose |
|------|---------|
| Python / FastAPI | Web framework |
| Uvicorn | ASGI server |
| Docker | Containerization |
| Azure Container Registry | Image storage |
| Azure Container Apps | Container hosting |
| Terraform | Infrastructure as Code |
| GitHub Actions | CI/CD pipeline |

---

## Step 1: Understanding the App

The app is intentionally simple — two routes:

- `/` — a homepage displaying app details (name, platform, environment, version, status)
- `/health` — a JSON health check returning `{"status": "healthy"}`

All the displayed values come from environment variables. This is important because it means the same code can run in any environment — dev, staging, prod — just by changing the config.

```python
def get_app_config() -> dict[str, str]:
    return {
        "app_name": os.getenv("APP_NAME", "Cloud Lab Starter App"),
        "intern_name": os.getenv("INTERN_NAME", "Replace Me"),
        "cloud_platform": os.getenv("CLOUD_PLATFORM", "Replace Me"),
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "app_version": os.getenv("APP_VERSION", "v1.0.0"),
        "app_status": os.getenv("APP_STATUS", "healthy"),
    }
```

The second argument in each `os.getenv()` is a fallback default. If someone clones the repo and runs it without setting any variables, the app still works — it just shows "Replace Me" as a hint.

For local development, I used a `.env` file with `python-dotenv` to load the variables automatically. The `.env` file is gitignored so personal config never gets pushed to the repo.

---

## Step 2: Containerizing with Docker

Here's the Dockerfile:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN useradd --no-create-home -s /bin/false appuser
USER appuser

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
```

### Key decisions:

**Why copy `requirements.txt` before the app code?**
Docker builds in layers and caches them. If I change my code but not my dependencies, Docker skips the `pip install` step entirely and reuses the cached layer. This makes rebuilds go from minutes to seconds.

**Why create a non-root user?**
By default, containers run as root. If someone exploits the app, they'd have full control of the container. The `appuser` with `--no-create-home` and `-s /bin/false` limits the damage — no home directory, no shell access.

**Why `--proxy-headers`?**
This one caught me off guard. Azure Container Apps serves your app over HTTPS, but internally the container runs on plain HTTP. Without proxy headers, FastAPI generated `http://` URLs for static files. The browser blocked them as mixed content (HTTPS page loading HTTP resources). Adding `--proxy-headers` tells Uvicorn to trust the `X-Forwarded-Proto` header from Azure's load balancer.

**Why `--platform linux/amd64`?**
I'm on a Mac with Apple Silicon (ARM). Azure Container Apps runs on `linux/amd64`. Without specifying the platform, Docker builds for ARM and Azure rejects it. This is a common gotcha.

---

## Step 3: Pushing to Azure Container Registry

Azure Container Registry (ACR) is like Docker Hub but private and integrated with Azure. Think of it as AWS ECR.

```bash
az acr login --name cogneticsregistry
docker tag lab1-starter-app:v1.0 cogneticsregistry.azurecr.io/lab1-starter-app:v1.0
docker push cogneticsregistry.azurecr.io/lab1-starter-app:v1.0
```

The `docker tag` step is essential — it puts the registry address in the image name so Docker knows where to push it. Think of it like putting a mailing address on a package.

### Lesson learned: ABAC vs RBAC

I initially created the ACR with "RBAC Registry + ABAC Repository Permissions" mode. Pushes kept failing with authorization errors even after assigning the `AcrPush` role. The fix was recreating the registry with standard RBAC mode. ABAC is for fine-grained repository-level access control — overkill for a lab.

---

## Step 4: Infrastructure as Code with Terraform

Instead of clicking around the Azure portal, I defined everything in code.

### What Terraform creates:

| Resource | Purpose |
|----------|---------|
| **Log Analytics Workspace** | Stores container logs. Required by Azure Container Apps. |
| **Container App Environment** | The hosting platform — shared networking, load balancing, DNS. Similar to an ECS Cluster in AWS. |
| **Container App** | The running application. Pulls the image from ACR, runs it with 0.25 CPU and 0.5Gi memory, exposes port 8000 to the internet. |

### How they connect:

```
Log Analytics Workspace
        ↓ (sends logs to)
Container App Environment
        ↓ (hosts)
Container App → pulls image from ACR → serves traffic on port 8000
        ↓
Public URL (HTTPS)
```

### Environment variables — injected, not baked

This was an important design decision. The Docker image contains zero configuration. All environment variables are injected by Terraform at runtime:

```hcl
env {
  name  = "INTERN_NAME"
  value = var.intern_name
}
```

The actual values live in `terraform.tfvars` which is gitignored. A `terraform.tfvars.example` file is committed so teammates know what to fill in. This way:
- The image is reusable across environments
- Personal config stays local
- The repo is clean

### Sensitive vs non-sensitive variables

Not everything needs to be hidden. Resource names like `log_analytics_name` get a default value directly in `variables.tf` — they're not sensitive. But personal values like `intern_name` and `cloud_platform` go in `terraform.tfvars` (gitignored) because they change per person.

---

## Step 5: CI/CD with GitHub Actions and OIDC

This is the part I'm most proud of. Every push to `main` automatically builds, pushes, and deploys.

### The pipeline has three stages:

```
Source → Build → Deploy
```

1. **Source** — checks out the code and uploads it as an artifact
2. **Build** — builds the Docker image and pushes it to ACR
3. **Deploy** — updates the Container App with the new image

### Why OIDC instead of stored credentials?

The typical approach is creating a service principal with a client secret and storing it in GitHub Secrets. That works, but:
- The secret is a password that can be leaked
- It expires and needs rotation
- Anyone with repo settings access can see it

With OIDC (OpenID Connect), there are **no passwords anywhere**. Instead:
1. I created a federated credential in Azure that trusts GitHub Actions from my specific repo and branch
2. At runtime, GitHub generates a short-lived token
3. Azure validates it against the trust relationship
4. The token expires in minutes

The GitHub Secrets only contain non-sensitive IDs:

```yaml
- name: Login to Azure (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

Even if someone sees these values, they can't authenticate — they'd need to be GitHub Actions running from my specific repo on the `main` branch.

### Image tagging with commit SHA

Instead of manual version tags like `v1.4`, `v1.5`, the pipeline tags images with the git commit SHA:

```yaml
IMAGE_TAG=${{ github.sha }}
```

This means every image is traceable to an exact commit. If something breaks in production, I can look at the image tag and know exactly what code is running.

---

## Security Decisions Summary

| Decision | Why |
|----------|-----|
| Non-root container user | Limits damage if the app is compromised |
| No shell access (`/bin/false`) | Prevents interactive access inside the container |
| OIDC authentication | No passwords stored — short-lived tokens only |
| `.env` gitignored | Local config never pushed to repo |
| `terraform.tfvars` gitignored | Deployment values stay local |
| Env vars injected at runtime | Config not baked into the Docker image |
| Proxy headers enabled | Correct HTTPS URLs behind the load balancer |
| Commit SHA image tags | Every deployment traceable to exact code |

---

## What I'd Do Differently in Production

This was a lab, so I kept things simple. In production, I'd add:

- **Remote Terraform state** — store `tfstate` in Azure Blob Storage so the team shares state
- **Separate environments** — dev, staging, prod with different variable files
- **Azure Key Vault** — for actual secrets like API keys and database passwords
- **Image scanning** — tools like Trivy to check for vulnerabilities before deploying
- **Approval gates** — require manual approval before deploying to production
- **Health check probes** — configure the Container App to use `/health` for liveness checks
- **Read-only filesystem** — run the container with `--read-only` for extra security

---

## The Full Flow

```
Code on laptop
    ↓
Run locally (uvicorn + .env file)
    ↓
Containerize (Docker build)
    ↓
Push to registry (ACR)
    ↓
Deploy infrastructure (Terraform)
    ↓
CI/CD pipeline (GitHub Actions + OIDC)
    ↓
Live on the internet
```

Every step builds on the previous one. The app went from running on `localhost:8000` to a public HTTPS URL with automated deployments and zero stored passwords.

---

## Repo

[github.com/Anthonyuketui/cognetiks-interns-lab1](https://github.com/Anthonyuketui/cognetiks-interns-lab1)

---

*Built as part of the Cognetiks Cloud & DevOps Intern Lab 1.*
