# ─── Stage: final image ────────────────────────────────────────────────────
FROM python:3.12-slim

# Set working directory inside the container
WORKDIR /app

# Copy requirements first — Docker caches this layer separately.
# If your source code changes but requirements don't, Docker skips re-installing.
COPY requirements.txt .

# Install dependencies (no pip cache to keep image size small)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the source code into the container
COPY . .

# Create the data directory where SQLite will write notes.db
# (This directory will be mounted as a Docker volume in production)
RUN mkdir -p /app/data

# Expose the port uvicorn listens on
EXPOSE 8000

# Start the app with uvicorn
# --host 0.0.0.0 is required in Docker — without it, the app only listens
# inside the container and is unreachable from Nginx or the outside world
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
