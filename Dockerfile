# ---- Stage 1: install dependencies into a virtualenv ----
FROM python:3.12-slim AS builder
WORKDIR /build
COPY app/requirements.txt .
RUN python -m venv /venv \
 && /venv/bin/pip install --no-cache-dir -r requirements.txt

# ---- Stage 2: small runtime image ----
FROM python:3.12-slim
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Run as a non-root user (security best practice; OpenShift requires it)
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /venv /venv
COPY app/app.py .

USER 10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
