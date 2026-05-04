# 🚀 Deployment Guide — FastAPI + Docker + Nginx + AWS EC2

> **Reusable reference.** Follow this guide top-to-bottom to deploy any Dockerized FastAPI app to AWS EC2 from scratch.

---

## Prerequisites (do once, ever)

- [ ] AWS account created at [aws.amazon.com](https://aws.amazon.com)
- [ ] Docker Desktop installed locally (`docker --version` to verify)
- [ ] Your FastAPI project pushed to GitHub

---

## Phase 1 — Prepare Your Project (local)

These files must exist in your project root before deploying.

### 1.1 `Dockerfile`
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/data
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 1.2 `docker-compose.yml`
```yaml
services:
  api:
    build: .
    expose:
      - "8000"
    volumes:
      - notes_data:/app/data
    environment:
      - DATABASE_URL=sqlite:////app/data/notes.db
    restart: always

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - api
    restart: always

volumes:
  notes_data:
```

### 1.3 `nginx/nginx.conf`
```nginx
upstream fastapi_app {
    server api:8000;
}

server {
    listen 80;

    location / {
        proxy_pass http://fastapi_app;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 1.4 `.dockerignore`
```
venv/
__pycache__/
*.db
.git/
.env
docs/
```

### 1.5 `database.py` — use env variable for DB path
```python
import os
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./notes.db")
```

### 1.6 Test locally before deploying
```bash
docker compose up --build
# visit http://localhost/docs — must work before going to EC2
docker compose down   # stop when done testing
```

### 1.7 Push everything to GitHub
```bash
git add .
git commit -m "feat: add Docker + Nginx deployment setup"
git push
```

---

## Phase 2 — Launch EC2 Instance (AWS Console)

### 2.1 Launch the instance
1. Go to [console.aws.amazon.com](https://console.aws.amazon.com) → **EC2** → **Launch Instance**
2. Fill in:

| Field | Value |
|-------|-------|
| Name | anything (e.g. `my-api-server`) |
| AMI | **Ubuntu Server 22.04 LTS** (free tier eligible) |
| Instance type | **t2.micro** (free tier) |
| Key pair | Create new → download `.pem` file → **save it safely, you can't re-download it** |

### 2.2 Configure Security Group (firewall)
Under **"Network settings"** → **"Edit"**, add these inbound rules:

| Type | Port | Source | Why |
|------|------|--------|-----|
| SSH | 22 | My IP (or 0.0.0.0/0) | So you can SSH in |
| HTTP | 80 | 0.0.0.0/0 | So the world can reach your API |

> ⚠️ If you forget port 80, you'll get `ERR_CONNECTION_TIMED_OUT` in the browser. Fix it anytime via: EC2 → Instance → Security tab → Security Group → Edit Inbound Rules.

### 2.3 Launch and get your public IP
- Click **Launch Instance**
- Go to **EC2 → Instances** → click your instance
- Copy the **Public IPv4 address** (e.g. `3.129.16.203`)

---

## Phase 3 — Connect to EC2 via SSH (local terminal)

```bash
# Make the key file private (SSH refuses to use it otherwise)
chmod 400 /path/to/your-key.pem

# SSH into EC2
ssh -i /path/to/your-key.pem ubuntu@<PUBLIC-IP>
```

You're now inside your EC2 server. All commands below run on EC2.

---

## Phase 4 — Install Docker on EC2

```bash
# Update package list
sudo apt update

# Install Docker engine + Compose plugin
sudo apt install -y docker.io docker-compose-plugin

# Allow running docker without sudo
sudo usermod -aG docker ubuntu

# Apply group change without logging out
newgrp docker

# Verify
docker --version
docker compose version
docker run hello-world   # should print "Hello from Docker!"
```

---

## Phase 5 — Deploy the App

```bash
# Clone your repo
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>

# Build images and start containers in the background
docker compose up -d --build

# Verify both containers are running
docker compose ps
```

Expected output:
```
NAME           IMAGE         STATUS    PORTS
...-api-1      ...-api       Up        8000/tcp
...-nginx-1    nginx:alpine  Up        0.0.0.0:80->80/tcp
```

---

## Phase 6 — Verify It's Live

Open in your browser:
```
http://<PUBLIC-IP>/        → { "message": "Notes API is running!" }
http://<PUBLIC-IP>/docs    → Swagger UI
```

🎉 **Your API is live on the internet.**

---

## Redeployment — Pushing Updates Later

When you make code changes locally:

```bash
# Local machine
git add .
git commit -m "your changes"
git push

# SSH into EC2
ssh -i your-key.pem ubuntu@<PUBLIC-IP>
cd <your-repo>

# Pull latest code and rebuild
git pull
docker compose up -d --build
```

---

## Useful Commands (cheat sheet)

```bash
# View live logs from all containers
docker compose logs -f

# View logs from a specific container
docker compose logs -f api
docker compose logs -f nginx

# Check container status
docker compose ps

# Restart a specific service
docker compose restart api

# Stop all containers
docker compose down

# Stop + delete volumes (⚠️ deletes your database!)
docker compose down -v

# Open a shell inside the running container
docker compose exec api bash

# Check what's inside the data volume
docker compose exec api ls /app/data/
```

---

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `ERR_CONNECTION_TIMED_OUT` | Port 80 not open in Security Group | AWS Console → EC2 → Security Group → Add HTTP rule (port 80) |
| `Permission denied` on `.pem` | Key file permissions too open | `chmod 400 your-key.pem` |
| Container exits immediately | App crash on startup | `docker compose logs api` to see the error |
| `newgrp docker` needed | Group change not applied | Run `newgrp docker` or log out and back in after `usermod` |
| Data lost after `docker compose down` | No volume defined | Ensure `volumes: notes_data:/app/data` is in compose file |

---

## Architecture Recap

```
Browser
   │  HTTP :80
   ▼
[Nginx container]          ← only container exposed to internet
   │  forwards to :8000
   ▼
[FastAPI container]        ← internal only, never directly reachable
   │  reads/writes
   ▼
[Docker Volume: notes_data]  ← SQLite data persists here on EC2 disk
```
