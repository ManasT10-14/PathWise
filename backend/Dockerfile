# Multi-stage build for minimal Cloud Run image size.
#
# Stage 1 (builder): Install all Python dependencies into /deps so they
#   can be copied into the final image without pip or build tools.
# Stage 2 (runtime): Copy only what's needed — no pip, no build tools.

FROM python:3.12-slim AS builder

WORKDIR /app

# Install dependencies into a separate target directory
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

# ---- Runtime stage ----
FROM python:3.12-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /deps /usr/local/lib/python3.12/site-packages

# Copy application source
COPY . .

# Cloud Run injects PORT at runtime; default to 8080
ENV PORT=8080

# Single worker per instance — Cloud Run scales horizontally via new instances
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
