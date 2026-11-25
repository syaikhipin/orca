# ORCA (Sightline) — single-container deployment: built web app + API on one
# origin, mirroring deploy/modal_app.py's shape for Coolify.
# Stage 1: build the web app.
FROM node:22-slim AS web
WORKDIR /build/web
COPY web/package.json web/package-lock.json ./
# postinstall runs scripts/copy-wasm.mjs during npm ci; it must exist by then.
COPY web/scripts/ ./scripts/
RUN npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build

# Stage 2: the server.
FROM python:3.13-slim
# WeasyPrint (PDF reports) needs Pango/HarfBuzz; OpenCASCADE (STEP) needs libGL.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libharfbuzz-subset0 \
    fonts-dejavu-core libgl1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY server/ /app/server/
RUN cd /app/server && uv sync --locked --no-dev
COPY samples/ /app/samples/
COPY --from=web /build/web/dist /app/web/dist
WORKDIR /app/server
EXPOSE 8000
CMD ["/app/server/.venv/bin/uvicorn", "sightline.app:app", "--host", "0.0.0.0", "--port", "8000"]
