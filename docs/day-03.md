# Day 03 — CI/CD with GitHub Actions

**Date:** 2026-05-04  
**Developer:** Anshika Dixit  
**Goal:** Automate deployment so every `git push` to `main` automatically redeploys the app on EC2 — no manual SSH required.

---

## 🎯 What We Set Out to Do

After Day 2, redeploying required SSHing into EC2, running `git pull`, and `docker compose up -d --build` manually. That's 3 steps every time you change a single line of code.

**CI/CD solves this:** Define the deployment steps once in a file. GitHub runs them automatically on every push.

```
Before CI/CD:  git push → SSH into EC2 → git pull → docker compose up (manual)
After CI/CD:   git push → GitHub does everything automatically ✅
```

---

## 🧱 New Concepts Introduced on Day 3

### What is CI/CD?

**CI = Continuous Integration** — automatically test/build your code when you push  
**CD = Continuous Deployment** — automatically deploy it to the server after that

For our project (no automated tests yet), we're doing **CD only** — every push to `main` triggers an automatic deployment.

---

### What is GitHub Actions?

GitHub Actions is a **workflow automation platform built into GitHub** — free for public repos, generous free tier for private.

You define workflows as YAML files inside `.github/workflows/`. GitHub reads these automatically. When the trigger fires (e.g. a push to `main`), GitHub spins up a **fresh virtual machine** on their servers and executes the steps you defined.

**Key terms:**

| Term | What it is |
|------|-----------|
| Workflow | A YAML file defining what to run and when |
| Trigger (`on:`) | What event starts the workflow (push, PR, schedule, etc.) |
| Job | A group of steps that run together on one VM |
| Step | A single action (run a command, use a pre-built action) |
| Runner | The virtual machine GitHub provides to run your job |
| Action | A reusable step someone else wrote (like `appleboy/ssh-action`) |
| Secret | Encrypted value stored in GitHub — never visible in logs |

---

### What is `appleboy/ssh-action`?

A popular open-source GitHub Action (15k+ stars) that handles SSH connections from GitHub Actions. Instead of you writing the SSH handshake logic yourself, you just pass it:
- The host IP
- The username
- The private key
- The commands to run

It handles the rest.

---

## 📁 File Created

### `.github/workflows/deploy.yml`

```yaml
name: Deploy to EC2

on:
  push:
    branches: [main]      # only trigger on pushes to main branch

jobs:
  deploy:
    runs-on: ubuntu-latest    # GitHub provides a fresh Ubuntu VM for this job

    steps:
      - name: SSH into EC2 and deploy
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.EC2_HOST }}         # EC2 public IP
          username: ${{ secrets.EC2_USERNAME }}  # ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}        # .pem file contents
          script: |
            cd ~/FastAI-Notes
            git pull origin main
            docker compose up -d --build
```

**Line-by-line breakdown:**

| Line | What it does |
|------|-------------|
| `on: push: branches: [main]` | Only deploy when code is pushed to `main` — not feature branches |
| `runs-on: ubuntu-latest` | GitHub provides a temporary Ubuntu server to run this job |
| `uses: appleboy/ssh-action@v1.0.3` | Use this pre-built action (pinned to exact version for safety) |
| `${{ secrets.EC2_HOST }}` | Reads the encrypted secret — never visible in logs |
| `cd ~/FastAI-Notes` | Navigate to the cloned repo on EC2 |
| `git pull origin main` | Fetch the latest code from GitHub |
| `docker compose up -d --build` | Rebuild images with new code + restart containers |

**Why pin `@v1.0.3` instead of `@latest`?**  
If the action author releases a breaking change in a new version, your workflow keeps working. `@latest` can break silently overnight.

---

## 🔐 GitHub Secrets Setup (manual — do once)

Secrets are encrypted values stored in GitHub. The workflow accesses them via `${{ secrets.NAME }}`. They never appear in logs, even if the workflow fails.

### How to add secrets

1. Go to **GitHub → your repo → Settings**
2. Left sidebar: **Secrets and variables → Actions**
3. Click **"New repository secret"** for each of the 3 secrets below

| Secret Name | Value | How to get it |
|-------------|-------|--------------|
| `EC2_HOST` | `3.129.16.203` | AWS Console → EC2 → Instances → Public IPv4 address |
| `EC2_USERNAME` | `ubuntu` | Always `ubuntu` for Ubuntu AMIs on EC2 |
| `EC2_SSH_KEY` | Full contents of your `.pem` file | See below |

### How to get the `.pem` file contents

```bash
# On your Mac terminal:
cat /path/to/your-key.pem
```

Copy everything including the header and footer:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA...
...many lines...
-----END RSA PRIVATE KEY-----
```

Paste the entire thing as the value of `EC2_SSH_KEY`.

> ⚠️ Never commit your `.pem` file to Git. Never share it. GitHub Secrets is the right place for it.

---

## ✅ How to Verify It Works

### Step 1 — Push the workflow file
```bash
git add .github/workflows/deploy.yml
git commit -m "feat: add GitHub Actions CI/CD deployment"
git push
```

### Step 2 — Watch the workflow run
- Go to **GitHub → your repo → Actions tab**
- You'll see a workflow run triggered by your push
- Click it to see live logs — each step expands to show output

### Step 3 — Make a visible test change
In `main.py`, change the root message:
```python
return {"message": "Notes API is running! (auto-deployed 🚀)"}
```
Then:
```bash
git add main.py
git commit -m "test: verify CI/CD auto-deployment"
git push
```
Watch the Actions tab → after ~30 seconds → hit `http://3.129.16.203/` → should show the new message.

---

## 🔄 Full CI/CD Flow (after setup)

```
[Your Mac]
    │
    │  git push origin main
    ▼
[GitHub]
    │  detects push to main branch
    │  triggers .github/workflows/deploy.yml
    ▼
[GitHub Actions VM — ubuntu-latest]
    │  appleboy/ssh-action connects to EC2 using EC2_SSH_KEY
    ▼
[Your EC2 Instance]
    │  cd ~/FastAI-Notes
    │  git pull origin main        ← gets your new code
    │  docker compose up -d --build ← rebuilds image + restarts containers
    ▼
[API live with new code] ← usually within 30-60 seconds of your push
```

---

## 🔍 Monitoring Deployments

Every deployment is logged in GitHub:
- **GitHub → repo → Actions** — full history of every deployment
- Green ✅ = deployed successfully
- Red ❌ = something failed (click to see full error log)

---

## 🐛 Common Errors & Fixes (from real experience)

| Error | Cause | Fix |
|-------|-------|-----|
| `ssh: no key found` | `.pem` copied incorrectly | Run `cat your-key.pem` → paste everything from `-----BEGIN...` to `-----END...` |
| `%` at end of `.pem` output | zsh shell indicator — NOT part of the key | Stop copying before the `%`. It's a display artifact, not key content |
| `dial tcp ***:22: i/o timeout` | Wrong IP in `EC2_HOST` — EC2 public IP changed after stop/start | Check current IP in AWS Console → EC2 → update `EC2_HOST` secret |
| `dial tcp ***:22: i/o timeout` | Port 22 not open to all IPs in Security Group | Edit inbound rules → SSH rule → Source: `0.0.0.0/0` |
| `Permission denied (publickey)` | Wrong SSH key format in secret | Re-copy the `.pem` contents including header/footer, exclude `%` |
| `cd: FastAI-Notes: No such file or directory` | Repo not cloned on EC2 yet | SSH in manually and run `git clone ...` first |
| Workflow doesn't trigger | Wrong branch name in `branches: [main]` | Check default branch name — could be `master` |
| Old code still running after deploy | Image not rebuilt | Always use `--build` flag |

> ⚠️ **EC2 public IPs are not permanent.** Every stop + start assigns a new IP and breaks `EC2_HOST`. Fix permanently with an Elastic IP (see below).

---

## 🔒 Permanent Fix — Elastic IP (do this once)

An Elastic IP is a **static public IP** that stays attached to your instance forever — survives stop/start.

```
AWS Console → EC2 → left sidebar → Elastic IPs
→ Allocate Elastic IP address → Allocate
→ Select the new IP → Actions → Associate Elastic IP address
→ Choose your EC2 instance → Associate
```

Then update `EC2_HOST` in GitHub Secrets to the Elastic IP — never needs updating again.

---

## ✅ End of Day 3 — What Works

- Every `git push` to `main` → auto-deploys to EC2 in ~10 seconds ✅
- Full deployment history visible in GitHub Actions tab ✅
- Zero manual SSH needed for routine deployments ✅
- Secrets stored encrypted, never visible in logs ✅
- Troubleshooting: wrong IP + SSH key format issues found and fixed ✅

---

## 📌 Concepts Introduced on Day 3

| Concept | Introduced in |
|---------|--------------|
| CI/CD | Overview |
| GitHub Actions | `.github/workflows/deploy.yml` |
| Workflow triggers (`on: push`) | `deploy.yml` |
| Jobs and steps | `deploy.yml` |
| `appleboy/ssh-action` | `deploy.yml` |
| GitHub Secrets | Settings → Secrets |
| `${{ secrets.NAME }}` syntax | `deploy.yml` |
| Pinning action versions (`@v1.0.3`) | `deploy.yml` |
| Deployment logs in Actions tab | GitHub UI |
| EC2 public IPs are ephemeral | Troubleshooting |
| Elastic IP — permanent static IP | Post-setup note |
| zsh `%` — not part of file content | Troubleshooting |

