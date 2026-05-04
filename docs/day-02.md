# Day 02 — Dockerization + AWS EC2 Deployment

**Date:** 2026-05-04  
**Developer:** Anshika Dixit  
**Goal:** Deploy the FastAPI app to the internet using Docker, Nginx, and AWS EC2 (free tier)

---

## 🎯 What We Set Out to Do

The API was working locally. Now we want it **live on the internet** so anyone can hit the URL and use it. The goal is also to **learn DevOps** — not just get it deployed, but understand every layer of the stack.

**Tech stack for deployment:**
```
Internet → Nginx (port 80) → FastAPI/uvicorn (port 8000) → SQLite (notes.db)
```

All three run inside **Docker containers** on an **AWS EC2 t2.micro** instance (free for 12 months).

---

## 🧱 New Concepts Introduced on Day 2

### What is Docker?

Docker packages your app + everything it needs (Python, libraries, code) into a **container** — a self-contained unit that runs the same way everywhere, regardless of the host machine.

**Without Docker:**
> "It works on my machine" — you install Python, create a venv, install dependencies manually on every server. If the server has a different OS or Python version, things break.

**With Docker:**
> You define the environment once in a `Dockerfile`. Docker builds an image from it. That image runs identically on your Mac, on EC2, anywhere.

**Key terms:**
| Term | What it is |
|------|-----------|
| `Dockerfile` | Recipe to build a Docker image |
| Image | A built, frozen snapshot of your app + environment |
| Container | A running instance of an image |
| Volume | Persistent storage that lives outside the container |
| docker-compose | Tool to run multiple containers together |

---

### What is Nginx?

Nginx (pronounced "engine-x") is a **web server / reverse proxy**.

**Why not just expose FastAPI directly on port 80?**
- Running uvicorn directly on port 80 requires root privileges — a security risk
- Nginx handles things FastAPI shouldn't: SSL termination, compression, rate limiting, serving static files, buffering slow clients
- In production, you never expose your app server directly

**Reverse proxy flow:**
```
Client → Nginx :80 → FastAPI/uvicorn :8000
```
Nginx sits in front and forwards requests inward. FastAPI is never directly reachable from the internet.

---

### What is AWS EC2?

EC2 = **Elastic Compute Cloud** — virtual machines (servers) in AWS's data centers.  
You rent a server, SSH into it, and run whatever you want.

**t2.micro** = the free tier instance type:
- 1 vCPU, 1GB RAM
- Free for 750 hours/month for 12 months
- Enough for a portfolio API with low traffic

---

## 📁 Files Created

### 1. `.dockerignore`

```
venv/
__pycache__/
*.db
.git/
.env
docs/
```

**Why it matters:** When Docker builds an image, it copies your project files into the image. Without `.dockerignore`, it would copy `venv/` (hundreds of MB) and `notes.db` (your local data). We don't want either — Docker installs its own dependencies, and data belongs in a volume.

**Analogy:** Like `.gitignore`, but for what gets copied into a Docker image.

---

### 2. `Dockerfile`

```dockerfile
FROM python:3.12-slim        # start from an official minimal Python image

WORKDIR /app                 # all commands run from /app inside the container

COPY requirements.txt .      # copy requirements FIRST (layer caching trick)
RUN pip install --no-cache-dir -r requirements.txt  # install deps

COPY . .                     # copy the rest of your source code

RUN mkdir -p /app/data       # create the directory where notes.db will live

EXPOSE 8000                  # document which port the app uses

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Layer caching trick — why copy requirements.txt first?**  
Docker builds images in layers. Each instruction is a layer. If a layer hasn't changed, Docker reuses the cached version. By copying `requirements.txt` and running `pip install` before copying your source code, you ensure that changing your Python files doesn't trigger a full pip reinstall — only source code changes invalidate the later layers.

**`--host 0.0.0.0` — why is this critical?**  
Without it, uvicorn only listens on `localhost` (127.0.0.1) **inside the container**. Nginx (running in a different container) can't reach it. `0.0.0.0` means "listen on all network interfaces" — making it reachable from other containers.

---

### 3. `docker-compose.yml`

```yaml
services:

  api:                           # the FastAPI container
    build: .                     # build from our Dockerfile
    expose:
      - "8000"                   # only visible to other containers, NOT the internet
    volumes:
      - notes_data:/app/data     # mount the volume here so notes.db persists
    environment:
      - DATABASE_URL=sqlite:////app/data/notes.db   # tell FastAPI where to write the DB
    restart: always

  nginx:                         # the reverse proxy container
    image: nginx:alpine
    ports:
      - "80:80"                  # THIS is exposed to the internet
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - api
    restart: always

volumes:
  notes_data:                    # Docker manages this — survives container rebuilds
```

**Key design decision — why is only Nginx on port 80?**  
The `api` service uses `expose` (internal only). Only `nginx` uses `ports` (public). This means FastAPI is **never directly accessible from the internet** — all traffic must go through Nginx. This is the standard production pattern.

**`DATABASE_URL` environment variable:**  
In Docker, `notes.db` needs to be inside the named volume (`/app/data/`) so it survives if the container is rebuilt. We pass this path via an environment variable so the same Python code works both locally (`./notes.db`) and in Docker (`/app/data/notes.db`).

---

### 4. `nginx/nginx.conf`

```nginx
upstream fastapi_app {
    server api:8000;
    # 'api' is the Docker Compose service name
    # Docker's internal DNS resolves 'api' to the FastAPI container's IP
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

**What is an `upstream` block?**  
It defines a backend server group. Here it's just one server (`api:8000`). In real production you'd list multiple servers for load balancing.

**What are the `proxy_set_header` lines?**  
When Nginx forwards a request, FastAPI would see Nginx's internal IP as the client IP — not the real user's IP. These headers pass the real client information through to FastAPI. Important for logging, rate limiting, and security.

**How does `server api:8000` work?**  
Docker Compose creates an internal DNS for all services. The name `api` resolves to the FastAPI container's internal IP automatically — you never need to hardcode IPs.

---

### 5. `database.py` — Updated

```python
import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./notes.db")
# os.getenv("DATABASE_URL", default) reads the environment variable
# If DATABASE_URL is set (Docker sets it) → use that value
# If not set (local dev) → use the default: ./notes.db
```

This one change makes the code work in both environments with **zero duplication**.

---

## ☁️ AWS EC2 Setup — Step by Step

### Step 1: Create AWS Account
- Go to [aws.amazon.com](https://aws.amazon.com) → Create account
- Requires credit card (no charge if you stay within free tier limits)
- Free tier includes t2.micro for 12 months

### Step 2: Launch an EC2 Instance
1. Go to EC2 → Launch Instance
2. **Name:** `fastai-notes-server`
3. **AMI:** Ubuntu Server 22.04 LTS (free tier eligible)
4. **Instance type:** t2.micro
5. **Key pair:** Create new → download the `.pem` file → save it safely
6. **Security Group:** Allow:
   - SSH (port 22) — from your IP only (for security)
   - HTTP (port 80) — from anywhere (0.0.0.0/0)

### Step 3: Connect via SSH
```bash
# Make the key file private (required, otherwise SSH refuses it)
chmod 400 your-key.pem

# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@<YOUR-EC2-PUBLIC-IP>
```

### Step 4: Install Docker on EC2
```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin

# Allow running docker without sudo
sudo usermod -aG docker ubuntu

# Log out and back in for group change to take effect
exit
ssh -i your-key.pem ubuntu@<YOUR-EC2-PUBLIC-IP>

# Verify docker works
docker --version
docker compose version
```

### Step 5: Deploy the App
```bash
# Clone your repo
git clone https://github.com/AnshikaDixit/FastAI-Notes.git
cd FastAI-Notes

# Build images and start containers in the background
docker compose up -d --build

# Check containers are running
docker compose ps

# View logs
docker compose logs -f
```

### Step 6: Verify
Open your browser:
```
http://<YOUR-EC2-PUBLIC-IP>/          → { "message": "Notes API is running!" }
http://<YOUR-EC2-PUBLIC-IP>/docs      → Swagger UI (live on the internet!)
```

---

## 🔄 Architecture Overview (Full Stack)

```
┌─────────────────────────────────────────────────────┐
│                   AWS EC2 t2.micro                  │
│                                                     │
│  ┌─────────────────┐    ┌───────────────────────┐  │
│  │  nginx:alpine   │    │  python:3.12-slim     │  │
│  │                 │    │                       │  │
│  │  port :80 ──────┼───►│  uvicorn :8000        │  │
│  │  (public)       │    │  FastAPI app          │  │
│  │                 │    │       │               │  │
│  └─────────────────┘    │       ▼               │  │
│                         │  /app/data/notes.db   │  │
│                         └──────────┬────────────┘  │
│                                    │               │
│                    ┌───────────────▼────────────┐  │
│                    │   Docker Volume: notes_data │  │
│                    │   (persists on EC2 host)    │  │
│                    └────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
        ▲
        │ port 80 (HTTP)
        │
   Internet / Browser
```

---

## 🔄 Useful Docker Commands (cheat sheet)

```bash
# Start everything (detached mode = background)
docker compose up -d

# Start + rebuild images (run after code changes)
docker compose up -d --build

# Stop everything
docker compose down

# View running containers
docker compose ps

# View live logs from all containers
docker compose logs -f

# View logs from a specific container
docker compose logs -f api
docker compose logs -f nginx

# Restart a specific service
docker compose restart api

# Open a shell inside the running container
docker compose exec api bash

# See the notes.db inside the running container
docker compose exec api ls /app/data/
```

---

## ✅ End of Day 2 — What Works

```
http://<EC2-PUBLIC-IP>/docs   ← Swagger UI accessible from the internet ✅
```

- FastAPI runs inside a Docker container ✅
- Nginx reverse proxies port 80 → port 8000 ✅
- SQLite data persists in a Docker volume across restarts ✅
- Same codebase runs locally and in Docker via env vars ✅

---

## 📌 Concepts Introduced on Day 2

| Concept | Introduced in |
|---------|--------------|
| Docker, containers, images | `Dockerfile` |
| Layer caching in Dockerfile | `Dockerfile` |
| `--host 0.0.0.0` requirement | `Dockerfile` |
| `.dockerignore` | `.dockerignore` |
| Docker Compose multi-service setup | `docker-compose.yml` |
| Named volumes for data persistence | `docker-compose.yml` |
| `expose` vs `ports` in Compose | `docker-compose.yml` |
| Environment variables (`os.getenv`) | `database.py` |
| Nginx as reverse proxy | `nginx/nginx.conf` |
| Docker internal DNS (`api:8000`) | `nginx/nginx.conf` |
| Proxy headers (X-Real-IP, etc.) | `nginx/nginx.conf` |
| AWS EC2 Free Tier | EC2 setup |
| Security Groups | EC2 setup |
| SSH with `.pem` key | EC2 setup |
| `chmod 400` on key files | EC2 setup |
